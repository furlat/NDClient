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
    var fields = key.split(",")
    if fields.size() != 2:
        return failure("Sensory cell key requires two integer coordinates")
    for value in fields:
        if not value.strip_edges().is_valid_int():
            return failure("Sensory cell key requires two integer coordinates")
    return success(point_key([int(fields[0]), int(fields[1])]))

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
    return result

# Internal folds retain immutable prior leaves. Public value-in/value-out helpers
# above/below detach their result; the reducer already owns its transaction copy.
static func _reduce_senses_retained(expected_observer: String, previous: Variant, event: Dictionary) -> Dictionary:
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
    var result: Dictionary = previous.duplicate()
    for field in ["entities", "objects", "spatial_effects", "effective_light_levels", "hazardous_cells"]:
        result[field] = previous[field].duplicate()
    var visible = {}
    for point in result.visible: visible[point_key(point)] = point
    for point in event.visible_cells_removed:
        var key = point_key(point)
        visible.erase(key)
        result.effective_light_levels.erase(key)
        result.hazardous_cells.erase(key)
    for point in event.visible_cells_added: visible[point_key(point)] = point.duplicate()
    result.visible = points_union([], visible.values())
    result.seen = points_union(result.seen, event.seen_cells_added.duplicate(true))
    for identity in event.entity_contacts_removed: result.entities.erase(identity)
    result.entities.merge(event.entity_contacts_changed.duplicate(true), true)
    for identity in event.object_contacts_removed: result.objects.erase(identity)
    result.objects.merge(event.object_contacts_changed.duplicate(true), true)
    for identity in event.spatial_effects_removed: result.spatial_effects.erase(identity)
    result.spatial_effects.merge(event.spatial_effects_changed.duplicate(true), true)
    for key in event.effective_light_levels_changed:
        var parsed = parse_cell_key(key)
        if not parsed.ok: return parsed
        var light = event.effective_light_levels_changed[key]
        if light < 0 or light > 4 or float(light) != floor(float(light)):
            return failure("Unknown recorded light level")
        result.effective_light_levels[parsed.value] = light
    for key in event.hazardous_cells_changed:
        var parsed = parse_cell_key(key)
        if not parsed.ok: return parsed
        result.hazardous_cells[parsed.value] = event.hazardous_cells_changed[key]
    if event.sense_modes_changed and event.sense_modes != null:
        result.sense_modes = event.sense_modes.duplicate(true)
        result.sense_modes_hash = modes_signature(result.sense_modes)
    if event.observer_position_changed: result.position = event.observer_position.duplicate()
    if event.passive_perception_changed and event.passive_perception != null:
        result.passive_perception = event.passive_perception
    if event.visual_access_changed and event.visual_access != null:
        result.visual_access = event.visual_access
    result.paths_dirty = previous.paths_dirty or event.paths_dirty
    return success(result)

static func observe(previous: Dictionary, audience: Dictionary, event: Dictionary, cursor: int) -> Dictionary:
    var result = _observe_retained(previous, audience, event, cursor)
    if result.ok: result.value = result.value.duplicate(true)
    return result

static func _observe_retained(previous: Dictionary, audience: Dictionary, event: Dictionary, cursor: int) -> Dictionary:
    if event.observer_uuid not in audience.observers:
        return failure("Sensory observation does not belong to this audience")
    var reduced = _reduce_senses_retained(event.observer_uuid, previous.members.get(event.observer_uuid), event)
    if not reduced.ok: return reduced
    var result: Dictionary = previous.duplicate()
    for field in ["members", "contact_cursors", "effect_cursors", "effect_absences"]:
        result[field] = previous[field].duplicate()
    result.members[event.observer_uuid] = reduced.value
    var current: Dictionary = reduced.value
    var before: Variant = previous.members.get(event.observer_uuid)
    for identity in event.entity_contacts_changed:
        result.contact_cursors[event.observer_uuid + "," + identity] = cursor
    for identity in event.object_contacts_changed:
        result.contact_cursors[event.observer_uuid + "," + identity] = cursor
    for identity in event.spatial_effects_changed:
        var observed: Dictionary = event.spatial_effects_changed[identity]
        var witnessed = not observed.visible_volume_positions.is_empty() or not observed.upper_volume_surfaces.is_empty()
        for point in observed.positions:
            if point in current.visible: witnessed = true; break
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
            if point not in current.visible: continue
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
    return success(result)

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
    var selected = {}
    var observers: Array = perception.members.keys()
    observers.sort()
    for observer in observers:
        var senses: Dictionary = perception.members[observer]
        for point in senses.visible:
            var key = point_key(point)
            var previous: Variant = selected.get(key)
            if previous == null or senses.effective_light_levels.get(key, 1) > perception.members[previous].effective_light_levels.get(key, 1):
                selected[key] = observer
    return selected

static func view(perception: Dictionary, observer: String) -> Variant:
    var result: Variant = _view_retained(perception, observer)
    return result.duplicate(true) if result != null else null

static func _view_retained(perception: Dictionary, observer: String) -> Variant:
    if perception.members.is_empty(): return null
    var anchor: Dictionary = perception.members.get(observer, perception.members.values()[0])
    var owners = tile_observers(perception)
    var result: Dictionary = anchor.duplicate()
    result.visible = []; result.seen = []; result.effective_light_levels = {}; result.hazardous_cells = {}
    result.paths_dirty = false
    for key in owners:
        var components = key.split(",")
        result.visible.append([int(components[0]), int(components[1])])
        var member: Dictionary = perception.members[owners[key]]
        if member.effective_light_levels.has(key): result.effective_light_levels[key] = member.effective_light_levels[key]
        if member.hazardous_cells.has(key): result.hazardous_cells[key] = member.hazardous_cells[key]
    result.visible = points_union([], result.visible)
    for member in perception.members.values():
        result.seen = points_union(result.seen, member.seen)
        result.paths_dirty = result.paths_dirty or member.paths_dirty
    result.entities = _contacts_retained(perception, false)
    result.objects = _contacts_retained(perception, true)
    result.spatial_effects = effects(perception)
    return result

# Only an owned event fold that already composed a sensory view may reuse these
# cell collections. Initial observer resets still recompute the full union.
# Contacts/effects stay exhaustive; observations/spatial facts may alter them.
static func _view_after(perception: Dictionary, observer: String, previous: Variant, event: Dictionary) -> Variant:
    if previous == null or event.initial or perception.members.is_empty():
        return _view_retained(perception, observer)
    var anchor: Dictionary = perception.members.get(observer, perception.members.values()[0])
    var result: Dictionary = anchor.duplicate()
    result.effective_light_levels = previous.effective_light_levels.duplicate()
    result.hazardous_cells = previous.hazardous_cells.duplicate()
    var affected = {}
    for point in event.visible_cells_added + event.visible_cells_removed:
        affected[point_key(point)] = point
    for field in ["effective_light_levels_changed", "hazardous_cells_changed"]:
        for key in event[field]:
            var parts: PackedStringArray = key.split(",")
            var point = [int(parts[0]), int(parts[1])]
            affected[point_key(point)] = point
    var observers: Array = perception.members.keys()
    observers.sort()
    var added: Array = []
    var removed: Array = []
    for key in affected:
        var point: Array = affected[key]
        var owner: Variant = null
        var brightness: Variant = null
        for identity in observers:
            var member: Dictionary = perception.members[identity]
            if point not in member.visible: continue
            var level: Variant = member.effective_light_levels.get(key, 1)
            if owner == null or level > brightness:
                owner = identity
                brightness = level
        result.effective_light_levels.erase(key)
        result.hazardous_cells.erase(key)
        if owner == null:
            if point in previous.visible: removed.append(point)
        else:
            if point not in previous.visible: added.append(point)
            var member: Dictionary = perception.members[owner]
            if member.effective_light_levels.has(key): result.effective_light_levels[key] = member.effective_light_levels[key]
            if member.hazardous_cells.has(key): result.hazardous_cells[key] = member.hazardous_cells[key]
    result.visible = _patch_points(previous.visible, added, removed)
    result.seen = _patch_points(previous.seen, event.seen_cells_added, [])
    result.paths_dirty = false
    for member in perception.members.values(): result.paths_dirty = result.paths_dirty or member.paths_dirty
    result.entities = _contacts_retained(perception, false)
    result.objects = _contacts_retained(perception, true)
    result.spatial_effects = effects(perception)
    return result

static func _patch_points(previous: Array, added: Array, removed: Array) -> Array:
    if added.is_empty() and removed.is_empty(): return previous
    var incoming = points_union([], added.duplicate(true))
    var result: Array = []
    var next = 0
    for point in previous:
        while next < incoming.size() and _point_less(incoming[next], point):
            result.append(incoming[next]); next += 1
        if next < incoming.size() and incoming[next] == point: next += 1
        if point not in removed: result.append(point)
    while next < incoming.size():
        result.append(incoming[next]); next += 1
    return result

static func _point_less(a: Array, b: Array) -> bool:
    return a[0] < b[0] if a[0] != b[0] else a[1] < b[1]
