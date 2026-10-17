extends RefCounted
# Public sensory after-values only. No native visibility or light calculation.

const OPTIONAL_EFFECT_FIELDS = ["anchor_position", "anchor_elevation_steps", "anchor_entity_uuid", "anchor_item_uuid", "sustainer_item_uuid", "concentration_slot_uuid", "area_geometry"]
const EFFECT_COLLECTIONS = ["positions", "visible_volume_positions", "upper_volume_surfaces", "suppressions", "construction_sections"]

static func success(value: Variant) -> Dictionary:
    return {"ok": true, "value": value}

static func failure(message: String) -> Dictionary:
    return {"ok": false, "error": {"kind": "reducer", "message": message}}

static func point_key(point: Array) -> String:
    return "%d,%d" % [point[0], point[1]]

static func parse_cell_key(key: String) -> Dictionary:
    var cell: Array = _wire_cell(key, {})
    return success(cell[0]) if not cell.is_empty() else failure("Sensory cell key requires two integer coordinates")

# One parse per wire cell key and event: [point key, [x, y]], or [] unless the
# key is two (edge-trimmed) integers. Light and hazard maps usually share every
# key and the composed view reuses the same parse. A canonical spelling is
# already its own point key; any other accepted spelling is reformatted.
static func _wire_cell(key: String, parsed: Dictionary) -> Array:
    var cell: Variant = parsed.get(key)
    if cell != null: return cell
    var fields: PackedStringArray = key.split(",")
    var result: Array = []
    if fields.size() == 2 and (fields[0].is_valid_int() or fields[0].strip_edges().is_valid_int()) \
            and (fields[1].is_valid_int() or fields[1].strip_edges().is_valid_int()):
        var x: int = int(fields[0])
        var y: int = int(fields[1])
        var canonical: bool = fields[0].length() <= 10 and fields[1].length() <= 10 and str(x) == fields[0] and str(y) == fields[1]
        result = [key if canonical else point_key([x, y]), [x, y]]
    parsed[key] = result
    return result

# The current producer spells every cell key canonically: "x,y" with no sign,
# padding or leading zero. One native scan proves that for a whole map (each
# such key is its own point key). Small maps keep the per-key parse.
const NONCANONICAL_CELL = "(*LF)(?m)^(?!(?:0|-?[1-9][0-9]{0,8}),(?:0|-?[1-9][0-9]{0,8})$)"

static func _canonical_cells(cells: Dictionary) -> bool:
    if cells.size() < 16: return false
    var keys: Array = cells.keys()
    for key in keys:
        if typeof(key) != TYPE_STRING: return false
    # A trailing canonical line keeps the last key an internal, checked line.
    var text: String = "\n".join(PackedStringArray(keys)) + "\n0,0"
    return text.count("\n") == keys.size() and RegEx.create_from_string(NONCANONICAL_CELL).search(text) == null

# Two exact integers: point_key and its integer parse round-trip this point.
static func _integer_cell(point: Variant) -> bool:
    return point is Array and point.size() == 2 and typeof(point[0]) == TYPE_INT and typeof(point[1]) == TYPE_INT \
        and absi(point[0]) < 1000000000000000 and absi(point[1]) < 1000000000000000

static func compare(a: Variant, b: Variant) -> int:
    if a is Array and b is Array:
        for i in range(mini(a.size(), b.size())):
            var order = compare(a[i], b[i])
            if order != 0: return order
        return -1 if a.size() < b.size() else (1 if a.size() > b.size() else 0)
    if a == b: return 0
    return -1 if a < b else 1

static func points_union(first: Array, second: Array) -> Array:
    # Admitted points contain two integers. Sort numeric axes natively instead
    # of calling the recursive Variant comparator for every pair of points.
    # Keep full wire precision and the last input point at each coordinate.
    var columns = {}
    for collection in [first, second]:
        for point in collection:
            if not columns.has(point[0]): columns[point[0]] = {}
            columns[point[0]][point[1]] = point
    var xs: Array = columns.keys()
    xs.sort()
    var result: Array = []
    for x in xs:
        var column: Dictionary = columns[x]
        var ys: Array = column.keys()
        ys.sort()
        for y in ys: result.append(column[y])
    return result

static func modes_signature(modes: Array) -> String:
    # Python's randomized hash is an implementation cache, not wire identity.
    var signature: Array = []
    for mode in modes: signature.append([mode.sense_type, int(mode.range_feet)])
    signature.sort_custom(func(a, b): return compare(a, b) < 0)
    return JSON.stringify(signature)

static func resolve(observer: String, supplied: Variant) -> Dictionary:
    if supplied == null:
        return success({"controlled": [observer], "observers": [observer], "revision": 0})
    var observers = {}
    var controlled = {}
    for identity in supplied.observers: observers[identity] = true
    for identity in supplied.controlled: controlled[identity] = true
    if supplied.observers.is_empty() or observers.size() != supplied.observers.size() or controlled.size() != supplied.controlled.size() or supplied.revision < 0:
        return failure("Audience requires unique observers/controlled actors and a nonnegative revision")
    if observer not in supplied.observers:
        return failure("The stream observer must belong to its audience")
    return success(supplied.duplicate(true))

static func reduce_senses(expected_observer: String, previous: Variant, event: Dictionary) -> Dictionary:
    var result = _reduce_senses_retained(expected_observer, previous, event)
    if result.ok: result.value = result.value.duplicate(true)
    result.erase("wire_cells")
    return result

# Internal folds retain immutable prior leaves. Public value-in/value-out helpers
# above/below detach their result; the reducer already owns its transaction copy.
static func _reduce_senses_retained(expected_observer: String, previous: Variant, event: Dictionary, cells: Dictionary = {}) -> Dictionary:
    if event.observer_uuid != expected_observer:
        return failure("sensory update belongs to a different observer")
    if event.initial:
        if event.passive_perception == null or event.visual_access == null:
            return failure("initial sensory update requires capability after-values")
        previous = {"position": event.observer_position.duplicate(), "visible": [], "seen": [],
            "entities": {}, "objects": {}, "effective_light_levels": {}, "paths_dirty": false,
            "passive_perception": event.passive_perception, "sense_modes_hash": "[]",
            "sense_modes": [], "visual_access": event.visual_access, "hazardous_cells": {}, "spatial_effects": {}}
    if previous == null:
        return failure("sensory delta requires a previously recorded initial state")
    # Reject invalid after-values before changing the fold-local coordinate
    # lookups. A caller retry must not inherit part of a rejected observation.
    var lights = {}
    var hazards = {}
    var wire_cells = {}
    # A canonically keyed map already is its own point-keyed map (only read
    # and merged below); others are parsed and validated key by key.
    if _canonical_cells(event.effective_light_levels_changed):
        for light in event.effective_light_levels_changed.values():
            if light < 0 or light > 4 or float(light) != floor(float(light)):
                return failure("Unknown recorded light level")
        lights = event.effective_light_levels_changed
    else:
        for key in event.effective_light_levels_changed:
            var cell: Array = _wire_cell(key, wire_cells)
            if cell.is_empty(): return failure("Sensory cell key requires two integer coordinates")
            var light = event.effective_light_levels_changed[key]
            if light < 0 or light > 4 or float(light) != floor(float(light)):
                return failure("Unknown recorded light level")
            lights[cell[0]] = light
    if _canonical_cells(event.hazardous_cells_changed): hazards = event.hazardous_cells_changed
    else:
        for key in event.hazardous_cells_changed:
            var cell: Array = _wire_cell(key, wire_cells)
            if cell.is_empty(): return failure("Sensory cell key requires two integer coordinates")
            hazards[cell[0]] = event.hazardous_cells_changed[key]
    var indexed = _member_cells(previous, expected_observer, cells)
    var result: Dictionary = previous.duplicate()
    # Retained member leaves are immutable. Detach a collection only when this
    # event edits it; public reduce_senses/observe still deep-detach their result.
    for fields in [["entities","entity_contacts_changed","entity_contacts_removed"],
            ["objects","object_contacts_changed","object_contacts_removed"],
            ["spatial_effects","spatial_effects_changed","spatial_effects_removed"]]:
        if not event[fields[1]].is_empty() or not event[fields[2]].is_empty():
            result[fields[0]] = previous[fields[0]].duplicate()
    if not lights.is_empty() or not event.visible_cells_removed.is_empty():
        result.effective_light_levels = previous.effective_light_levels.duplicate()
    if not hazards.is_empty() or not event.visible_cells_removed.is_empty():
        result.hazardous_cells = previous.hazardous_cells.duplicate()
    # Presence distinguishes current authoritative emptiness from an archived
    # protocol that never supplied optical source observations.
    if previous.has("light_sources") or event.has("light_sources_changed") or event.has("light_sources_removed"):
        result.light_sources = previous.get("light_sources", {})
        result.light_source_removals = previous.get("light_source_removals", {})
        if not event.get("light_sources_changed", {}).is_empty() or not event.get("light_sources_removed", {}).is_empty():
            result.light_sources = result.light_sources.duplicate()
            result.light_source_removals = result.light_source_removals.duplicate()
        for identity in event.get("light_sources_removed", {}):
            result.light_sources.erase(identity)
            result.light_source_removals[identity] = event.light_sources_removed[identity]
        for identity in event.get("light_sources_changed", {}):
            result.light_sources[identity] = event.light_sources_changed[identity].duplicate(true)
            result.light_source_removals.erase(identity)
    for point in event.visible_cells_removed:
        var key = point_key(point)
        result.effective_light_levels.erase(key)
        result.hazardous_cells.erase(key)
    result.visible = _update_cells(indexed.visible, event.visible_cells_added, event.visible_cells_removed)
    result.seen = _update_cells(indexed.seen, event.seen_cells_added, [])
    for identity in event.entity_contacts_removed: result.entities.erase(identity)
    if not event.entity_contacts_changed.is_empty():result.entities.merge(event.entity_contacts_changed.duplicate(true), true)
    for identity in event.object_contacts_removed: result.objects.erase(identity)
    if not event.object_contacts_changed.is_empty():result.objects.merge(event.object_contacts_changed.duplicate(true), true)
    for identity in event.spatial_effects_removed: result.spatial_effects.erase(identity)
    if not event.spatial_effects_changed.is_empty():result.spatial_effects.merge(event.spatial_effects_changed.duplicate(true), true)
    if not lights.is_empty():result.effective_light_levels.merge(lights,true)
    if not hazards.is_empty():result.hazardous_cells.merge(hazards,true)
    if event.sense_modes_changed and event.sense_modes != null:
        result.sense_modes = event.sense_modes.duplicate(true)
        result.sense_modes_hash = modes_signature(result.sense_modes)
    if event.observer_position_changed: result.position = event.observer_position.duplicate()
    if event.passive_perception_changed and event.passive_perception != null:
        result.passive_perception = event.passive_perception
    if event.visual_access_changed and event.visual_access != null:
        result.visual_access = event.visual_access
    result.paths_dirty = previous.paths_dirty or event.paths_dirty
    indexed.source = result
    var reduced: Dictionary = success(result)
    reduced.wire_cells = wire_cells
    return reduced

static func observe(previous: Dictionary, audience: Dictionary, event: Dictionary, cursor: int) -> Dictionary:
    var result = _observe_retained(previous, audience, event, cursor)
    if result.ok: result.value = result.value.duplicate(true)
    result.erase("wire_cells")
    return result

static func _observe_retained(previous: Dictionary, audience: Dictionary, event: Dictionary, cursor: int, cells: Dictionary = {}) -> Dictionary:
    if event.observer_uuid not in audience.observers:
        return failure("Sensory observation does not belong to this audience")
    var reduced = _reduce_senses_retained(event.observer_uuid, previous.members.get(event.observer_uuid), event, cells)
    if not reduced.ok: return reduced
    var result: Dictionary = previous.duplicate()
    for field in ["members", "contact_cursors", "effect_cursors", "effect_absences"]:
        result[field] = previous[field].duplicate()
    result.members[event.observer_uuid] = reduced.value
    var current: Dictionary = reduced.value
    var visible_cells: Dictionary = _member_cells(current,event.observer_uuid,cells).visible
    var before: Variant = previous.members.get(event.observer_uuid)
    for identity in event.entity_contacts_changed:
        result.contact_cursors[event.observer_uuid + "," + identity] = cursor
    for identity in event.object_contacts_changed:
        result.contact_cursors[event.observer_uuid + "," + identity] = cursor
    for identity in event.spatial_effects_changed:
        var observed: Dictionary = event.spatial_effects_changed[identity]
        var witnessed = not observed.visible_volume_positions.is_empty() or not observed.upper_volume_surfaces.is_empty()
        for point in observed.positions:
            if _has_cell(visible_cells,point): witnessed = true; break
        if witnessed: result.effect_cursors[event.observer_uuid + "," + identity] = cursor
    var known = {}
    var snapshots: Array = previous.members.values()
    snapshots.append(current)
    for senses in snapshots:
        for identity in senses.spatial_effects:
            known[identity] = points_union(known.get(identity, []), senses.spatial_effects[identity].positions)
    for identity in known:
        var observed: Variant = current.spatial_effects.get(identity)
        var present: Array = observed.positions if observed != null else []
        for point in known[identity]:
            if not _has_cell(visible_cells,point): continue
            var key: String = identity + "," + point_key(point)
            if result.effect_absences.get(key, -1) > cursor: continue
            if point in present:
                result.effect_absences.erase(key)
            else:
                var prior: Variant = before.spatial_effects.get(identity) if before != null else null
                var apparent = false
                for senses in previous.members.values():
                    if senses.spatial_effects.has(identity) and senses.spatial_effects[identity].apparent_presence:
                        apparent = true; break
                if apparent or (prior != null and point in prior.positions):
                    result.effect_absences[key] = cursor
    var observed_result: Dictionary = success(result)
    observed_result.wire_cells = reduced.wire_cells
    return observed_result

static func contacts(perception: Dictionary, objects: bool) -> Dictionary:
    return _contacts_retained(perception, objects).duplicate(true)

static func _contacts_retained(perception: Dictionary, objects: bool) -> Dictionary:
    var selected = {}
    var ranks = {}
    for observer in perception.members:
        var values: Dictionary = perception.members[observer].objects if objects else perception.members[observer].entities
        for identity in values:
            var contact: Dictionary = values[identity]
            var rank = [1 if contact.visual else 0, perception.contact_cursors.get(observer + "," + identity, -1)]
            if not ranks.has(identity) or compare(rank, ranks[identity].rank) > 0 or (rank == ranks[identity].rank and observer < ranks[identity].observer):
                ranks[identity] = {"rank": rank, "observer": observer}
                selected[identity] = contact
    return selected

# Only sensory updates change object contacts in a composed view. Re-evaluate
# changed identities across observers, retaining the original full-walk key order.
# Entity contacts remain exhaustive because spatial/observation facts edit them.
static func _object_contacts_after(perception: Dictionary, previous: Dictionary, event: Dictionary) -> Dictionary:
    var changed: Dictionary = event.object_contacts_changed.duplicate()
    for identity in event.object_contacts_removed: changed[identity] = true
    # Entity and object observations share the observer/identity cursor table.
    # An overlapping identity can therefore change an object's winner too.
    for identity in event.entity_contacts_changed:
        if previous.has(identity): changed[identity] = true
    if changed.is_empty(): return previous
    var selected: Dictionary = previous.duplicate()
    for identity in changed:
        var winner: Variant = null
        var best_visual = -1
        var best_cursor = -1
        var best_observer = ""
        for observer in perception.members:
            var contact: Variant = perception.members[observer].objects.get(identity)
            if contact == null: continue
            var visual = 1 if contact.visual else 0
            var cursor: int = perception.contact_cursors.get(observer + "," + identity, -1)
            if winner == null or visual > best_visual or (visual == best_visual and (cursor > best_cursor or (cursor == best_cursor and observer < best_observer))):
                winner = contact; best_visual = visual; best_cursor = cursor; best_observer = observer
        if winner == null: selected.erase(identity)
        else: selected[identity] = winner
    var result = {}
    for observer in perception.members:
        for identity in perception.members[observer].objects:
            if not result.has(identity): result[identity] = selected[identity]
    return result

static func join_effect(first: Dictionary, second: Dictionary) -> Variant:
    if first.owner_revision == null or first.owner_revision != second.owner_revision: return null
    var left: Dictionary = first.duplicate(true)
    var right: Dictionary = second.duplicate(true)
    for key in EFFECT_COLLECTIONS + OPTIONAL_EFFECT_FIELDS: left.erase(key); right.erase(key)
    if left != right: return null
    var result: Dictionary = first.duplicate(true)
    for key in OPTIONAL_EFFECT_FIELDS:
        if first[key] != null and second[key] != null and first[key] != second[key]: return null
        result[key] = first[key] if first[key] != null else second[key]
    var protections = {}
    for row in first.suppressions: protections[row.provider_uuid] = row.duplicate(true)
    for row in second.suppressions:
        var prior: Variant = protections.get(row.provider_uuid)
        if prior != null:
            left = prior.duplicate(true); right = row.duplicate(true)
            left.erase("positions"); right.erase("positions")
            if left != right: return null
        var combined: Dictionary = row.duplicate(true)
        combined.positions = points_union(row.positions, prior.positions if prior != null else [])
        protections[row.provider_uuid] = combined
    var ids: Array = protections.keys()
    ids.sort()
    result.suppressions = []
    for identity in ids: result.suppressions.append(protections[identity])
    var upper = {}
    for row in first.upper_volume_surfaces + second.upper_volume_surfaces:
        upper[JSON.stringify([row.position, row.lower_height_planes])] = row
    result.upper_volume_surfaces = upper.values()
    result.upper_volume_surfaces.sort_custom(func(a, b): return compare([a.position, a.lower_height_planes], [b.position, b.lower_height_planes]) < 0)
    result.construction_sections = first.construction_sections.duplicate(true)
    for section in second.construction_sections:
        if section not in result.construction_sections: result.construction_sections.append(section.duplicate(true))
    result.positions = points_union(first.positions, second.positions)
    result.visible_volume_positions = points_union(first.visible_volume_positions, second.visible_volume_positions)
    return result

static func effects(perception: Dictionary) -> Dictionary:
    var selected = {}
    var ranks = {}
    for observer in perception.members:
        for identity in perception.members[observer].spatial_effects:
            var observed: Dictionary = perception.members[observer].spatial_effects[identity]
            var rank = [observed.owner_revision if observed.owner_revision != null else -1, perception.effect_cursors.get(observer + "," + identity, -1)]
            if not ranks.has(identity) or compare(rank, ranks[identity].rank) > 0 or (rank == ranks[identity].rank and observer < ranks[identity].observer):
                ranks[identity] = {"rank": rank, "observer": observer}
                selected[identity] = observed
    var observers: Array = perception.members.keys()
    observers.sort()
    var result = {}
    for identity in selected:
        var merged: Dictionary = selected[identity].duplicate(true)
        for observer in observers:
            var row: Variant = perception.members[observer].spatial_effects.get(identity)
            if row != null:
                var joined: Variant = join_effect(merged, row)
                if joined != null: merged = joined
        var positions: Array = []
        for point in merged.positions:
            if not perception.effect_absences.has(identity + "," + point_key(point)): positions.append(point)
        if not positions.is_empty() or not merged.visible_volume_positions.is_empty() or not merged.upper_volume_surfaces.is_empty():
            merged.positions = points_union([], positions)
            result[identity] = merged
    return result

static func tile_observers(perception: Dictionary) -> Dictionary:
    var owners: Dictionary = _tile_owners(perception)
    var selected = {}
    for key in owners: selected[key] = owners[key][0]
    return selected

# The owning observer of each visible cell key, with one admitted point there.
static func _tile_owners(perception: Dictionary) -> Dictionary:
    var selected = {}
    var observers: Array = perception.members.keys()
    observers.sort()
    for observer in observers:
        var senses: Dictionary = perception.members[observer]
        for point in senses.visible:
            var key = point_key(point)
            var previous: Variant = selected.get(key)
            if previous == null: selected[key] = [observer, point]
            elif senses.effective_light_levels.get(key, 1) > perception.members[previous[0]].effective_light_levels.get(key, 1):
                previous[0] = observer
    return selected

static func view(perception: Dictionary, observer: String) -> Variant:
    var result: Variant = _view_retained(perception, observer)
    return result.duplicate(true) if result != null else null

static func _light_sources_retained(perception: Dictionary) -> Dictionary:
    var revisions = {}
    var supplied = false
    for member in perception.members.values():
        supplied = supplied or member.has("light_sources") or member.has("light_source_removals")
        for identity in member.get("light_source_removals", {}):
            revisions[identity] = maxi(revisions.get(identity, -1), member.light_source_removals[identity])
        for identity in member.get("light_sources", {}):
            revisions[identity] = maxi(revisions.get(identity, -1), member.light_sources[identity].revision)
    if not supplied: return {}
    var sources = {}
    var observers: Array = perception.members.keys()
    observers.sort()
    for observer in observers:
        for identity in perception.members[observer].get("light_sources", {}):
            var source: Dictionary = perception.members[observer].light_sources[identity]
            if source.revision != revisions[identity]: continue
            if not sources.has(identity):
                sources[identity] = source
            else:
                var merged: Dictionary = sources[identity].duplicate()
                # Live descriptors carry no cell map. Only archived nonempty
                # footprints need the historical equal-revision union.
                if not source.get("affected_tiles", {}).is_empty():
                    merged.affected_tiles = merged.get("affected_tiles", {}).duplicate()
                    merged.affected_tiles.merge(source.affected_tiles, true)
                for field in ["anchor_entity_uuid", "anchor_item_uuid"]:
                    if merged.get(field) == null: merged[field] = source.get(field)
                sources[identity] = merged
    var removals = {}
    for identity in revisions:
        if not sources.has(identity): removals[identity] = revisions[identity]
    return {"light_sources":sources, "light_source_removals":removals}

static func _view_retained(perception: Dictionary, observer: String) -> Variant:
    if perception.members.is_empty(): return null
    var anchor: Dictionary = perception.members.get(observer, perception.members.values()[0])
    var owners: Dictionary = _tile_owners(perception)
    var result: Dictionary = anchor.duplicate()
    result.visible = []; result.seen = []; result.effective_light_levels = {}; result.hazardous_cells = {}
    result.paths_dirty = false
    for key in owners:
        var owner: Array = owners[key]
        # An admitted integer point already is the cell its key names; only
        # another spelling round-trips through the key's integers.
        var point: Array = owner[1]
        if _integer_cell(point): result.visible.append(point)
        else:
            var components = key.split(",")
            result.visible.append([int(components[0]), int(components[1])])
        var member: Dictionary = perception.members[owner[0]]
        if member.effective_light_levels.has(key): result.effective_light_levels[key] = member.effective_light_levels[key]
        if member.hazardous_cells.has(key): result.hazardous_cells[key] = member.hazardous_cells[key]
    result.visible = points_union([], result.visible)
    for member in perception.members.values():
        result.seen = points_union(result.seen, member.seen)
        result.paths_dirty = result.paths_dirty or member.paths_dirty
    result.entities = _contacts_retained(perception, false)
    result.objects = _contacts_retained(perception, true)
    result.spatial_effects = effects(perception)
    result.merge(_light_sources_retained(perception), true)
    return result

# Only an owned event fold that already composed a sensory view may reuse these
# cell collections. Initial observer resets still recompute the full union.
# Contacts/effects stay exhaustive; observations/spatial facts may alter them.
static func _view_after(perception: Dictionary, observer: String, previous: Variant, event: Dictionary, cells: Dictionary = {}, retained:bool=false, wire_cells:Dictionary={}) -> Variant:
    if previous == null or event.initial or perception.members.is_empty():
        return _view_retained(perception, observer)
    var anchor: Dictionary = perception.members.get(observer, perception.members.values()[0])
    var result: Dictionary = anchor.duplicate()
    result.effective_light_levels = previous.effective_light_levels
    result.hazardous_cells = previous.hazardous_cells
    # The member fold already owns sorted, deduplicated cell collections.
    # A retained one-member view has no union/winner work to repeat. Its raw
    # light maps still pass through the visible-key projection below.
    var direct:bool=retained and perception.members.size()==1
    var composed:Dictionary={}
    if not direct:
        composed=cells.get("view",{})
        if composed.is_empty() or not is_same(composed.source,previous):
            composed = _indexed_senses(previous)
            cells.view = composed
    var affected = {}
    for point in event.visible_cells_added + event.visible_cells_removed:
        affected[point_key(point)] = point
    # The member fold already validated these wire keys. A key that already
    # holds an integer point (usually a cell disclosed above) names that cell.
    for field in ["effective_light_levels_changed", "hazardous_cells_changed"]:
        for key in event[field]:
            if _integer_cell(affected.get(key)): continue
            var cell: Array = _wire_cell(key, wire_cells)
            affected[cell[0]] = cell[1]
    if not affected.is_empty():
        result.effective_light_levels = result.effective_light_levels.duplicate()
        result.hazardous_cells = result.hazardous_cells.duplicate()
    var observers: Array = perception.members.keys()
    observers.sort()
    # Sorted observer members and their visible columns, looked up once.
    var members: Array = []
    var columns: Array = []
    for identity in observers:
        members.append(perception.members[identity])
        columns.append(_member_cells(perception.members[identity],identity,cells).visible.columns)
    var added: Array = []
    var removed: Array = []
    for key in affected:
        var point: Array = affected[key]
        var owner: Variant = null
        var brightness: Variant = null
        for index in members.size():
            var column: Variant = columns[index].get(point[0])
            if column == null or not column.has(point[1]): continue
            var level: Variant = members[index].effective_light_levels.get(key, 1)
            if owner == null or level > brightness:
                owner = index
                brightness = level
        result.effective_light_levels.erase(key)
        result.hazardous_cells.erase(key)
        if owner == null:
            if not direct and _has_cell(composed.visible,point): removed.append(point)
        else:
            if not direct and not _has_cell(composed.visible,point): added.append(point)
            var member: Dictionary = members[owner]
            if member.effective_light_levels.has(key): result.effective_light_levels[key] = member.effective_light_levels[key]
            if member.hazardous_cells.has(key): result.hazardous_cells[key] = member.hazardous_cells[key]
    if direct:
        result.visible=anchor.visible;result.seen=anchor.seen
        # This is the transaction's forked context. A future multi-member
        # projection builds its own composed index from its actual prior view.
        cells.erase("view")
    else:
        result.visible = _update_cells(composed.visible, added, removed)
        result.seen = _update_cells(composed.seen, event.seen_cells_added, [])
    result.paths_dirty = false
    for member in perception.members.values(): result.paths_dirty = result.paths_dirty or member.paths_dirty
    result.entities=anchor.entities if direct else _contacts_retained(perception,false)
    result.objects=anchor.objects if direct else _object_contacts_after(perception,previous.objects,event)
    # These independent operands only change through their disclosed after-
    # values (or a member reset). Contact-only events do not merge every optical
    # source again, and effects need recomposition only when their witness set
    # or their actual disclosed values can have changed.
    var effects_changed:bool=not event.spatial_effects_changed.is_empty() or not event.spatial_effects_removed.is_empty() \
        or not event.visible_cells_added.is_empty() or not event.visible_cells_removed.is_empty()
    result.spatial_effects=effects(perception) if effects_changed else previous.spatial_effects
    var optical_changed:bool=not event.get("light_sources_changed",{}).is_empty() or not event.get("light_sources_removed",{}).is_empty()
    if not optical_changed and previous.has("light_sources"):
        result.light_sources=previous.light_sources
        result.light_source_removals=previous.get("light_source_removals",{})
    else:result.merge(_light_sources_retained(perception),true)
    if not direct:composed.source=result
    return result

# Journal's last committed indexes are immutable. A candidate owns index shells
# and outer maps; only x-columns actually changed by its events are copied.
static func _fork_cells(previous: Dictionary) -> Dictionary:
    var result = {"members":{}, "composed":previous.get("composed",false)}
    for observer in previous.get("members",{}):
        result.members[observer] = _fork_indexed_senses(previous.members[observer])
    if previous.has("view"): result.view = _fork_indexed_senses(previous.view)
    return result

static func _fork_indexed_senses(previous: Dictionary) -> Dictionary:
    return {"source":previous.source, "visible":_fork_cell_index(previous.visible),
        "seen":_fork_cell_index(previous.seen)}

static func _fork_cell_index(previous: Dictionary) -> Dictionary:
    return {"columns":previous.columns.duplicate(), "ordered":previous.ordered, "private_columns":{}}

static func _own_column(indexed: Dictionary, x: int) -> void:
    if not indexed.has("private_columns") or indexed.private_columns.has(x): return
    if indexed.columns.has(x): indexed.columns[x] = indexed.columns[x].duplicate()
    indexed.private_columns[x] = true

static func _member_cells(senses: Dictionary, observer: String, cells: Dictionary) -> Dictionary:
    if not cells.has("members"): cells.members = {}
    var indexed: Dictionary = cells.members.get(observer,{})
    if indexed.is_empty() or not is_same(indexed.source,senses):
        indexed = _indexed_senses(senses)
        cells.members[observer] = indexed
    return indexed

static func _indexed_senses(senses: Dictionary) -> Dictionary:
    return {"source":senses,"visible":_cell_index(senses.visible),"seen":_cell_index(senses.seen)}

static func _cell_index(points: Array) -> Dictionary:
    var columns = {}
    for point in points:
        if not columns.has(point[0]): columns[point[0]] = {}
        columns[point[0]][point[1]] = point
    return {"columns":columns,"ordered":_ordered_cells(columns)}

static func _has_cell(indexed: Dictionary, point: Array) -> bool:
    return indexed.columns.has(point[0]) and indexed.columns[point[0]].has(point[1])

static func _cell_lower_bound(points: Array, point: Array) -> int:
    var first = 0
    var last = points.size()
    while first < last:
        var middle: int = (first + last) >> 1
        var candidate: Array = points[middle]
        if candidate[0] < point[0] or (candidate[0] == point[0] and candidate[1] < point[1]):
            first = middle + 1
        else:
            last = middle
    return first

static func _update_cells(indexed: Dictionary, added: Array, removed: Array) -> Array:
    var changed = false
    var columns: Dictionary = indexed.columns
    var ordered: Array = indexed.ordered
    var incremental: bool = (added.size() + removed.size()) * 8 < ordered.size()
    for point in removed:
        if not _has_cell(indexed,point): continue
        if incremental:
            if not changed: ordered = ordered.duplicate()
            ordered.remove_at(_cell_lower_bound(ordered,point))
        changed = true
        _own_column(indexed,point[0])
        columns[point[0]].erase(point[1])
        if columns[point[0]].is_empty(): columns.erase(point[0])
    # Bulk discoveries (a door, a first step) add hundreds of cells: the
    # membership test and column ownership are inlined below.
    var private: Variant = indexed.get("private_columns")
    for point in added:
        var x: Variant = point[0]
        var column: Variant = columns.get(x)
        if column != null and column.has(point[1]): continue
        if incremental and not changed: ordered = ordered.duplicate()
        changed = true
        if private != null and not private.has(x):
            if column != null:
                column = column.duplicate()
                columns[x] = column
            private[x] = true
        if column == null:
            column = {}
            columns[x] = column
        var owned: Array = point.duplicate()
        column[point[1]] = owned
        if incremental: ordered.insert(_cell_lower_bound(ordered,owned),owned)
    # Published arrays stay immutable. Small deltas use native array moves and
    # exact integer comparisons instead of rebuilding/sorting every known cell.
    if changed: indexed.ordered = ordered if incremental else _ordered_cells(columns)
    return indexed.ordered

static func _ordered_cells(columns: Dictionary) -> Array:
    var xs: Array = columns.keys()
    xs.sort()
    var result: Array = []
    for x in xs:
        var column: Dictionary = columns[x]
        var ys: Array = column.keys()
        ys.sort()
        for y in ys: result.append(column[y])
    return result
