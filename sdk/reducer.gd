extends RefCounted
# Port of dnd/player/reduction.py. Inputs are decoded public after-values.
const Audience = preload("res://sdk/audience.gd")
const Transitions = preload("res://sdk/transitions.gd")
const STATE_PRESENTATION_KINDS = ["temporary_hit_points", "spatial", "turn", "sensory", "item_charge", "faction"]

static func success(value: Variant) -> Dictionary:
    return Audience.success(value)

static func failure(message: String) -> Dictionary:
    return Audience.failure(message)

static func content_key(descriptor: Dictionary) -> String:
    var ref: Dictionary = descriptor.ref
    return "%s:%s:%s@%d" % [ref.pack_id, ref.definition_kind, ref.content_id, ref.content_version]

static func resolution_key(reference: Dictionary) -> String:
    return reference.kind + "," + reference.lineage_uuid + ("," + reference.application_id if reference.kind == "application" else "")

static func copy_target(target: Dictionary) -> Dictionary:
    # Received dictionaries are mutable in Godot; detach before every transaction.
    return target.duplicate(true)

static func _retained_target(target: Dictionary) -> Dictionary:
    # Journal-only transaction: previous published states/captures are read-only.
    # Every container edited by the fold is private; installed record leaves are
    # immutable or copied at insertion. Public reducer calls still deep-detach.
    var result: Dictionary = target.duplicate()
    for key in ["actors", "tiles", "objects", "spatial_commit_cursors"]:
        result[key] = target[key].duplicate()
    for identity in result.actors:
        result.actors[identity] = Transitions.snapshot_actor(result.actors[identity])
    result.senses = Transitions.snapshot_senses(target.senses)
    result.combat_log_appends = target.combat_log_appends.duplicate()
    return result

static func _ordered_rows(rows: Array, cursors: Dictionary, identity_field: String) -> Array:
    # Python's sort is stable; Godot's is not. Equal cursors retain wire order.
    var order: Array = range(rows.size())
    order.sort_custom(func(a, b):
        var first: int = cursors[rows[a][identity_field]]
        var second: int = cursors[rows[b][identity_field]]
        return a < b if first == second else first < second)
    var result: Array = []
    for index in order: result.append(rows[index])
    return result

static func apply_world_update(target: Dictionary, update: Dictionary) -> Dictionary:
    for row in update.tiles: target.tiles[Audience.point_key(row.position)] = row.duplicate(true)
    # Each row is an after-value at this event, including explicit clears. Never
    # mutate a tile held by an earlier event or use a future discovery as its base.
    for row in update.get("tile_changes",[]):
        var key = Audience.point_key(row.position)
        if not target.tiles.has(key): return failure("Tile field update requires an already known tile")
        var tile: Dictionary = target.tiles[key].duplicate()
        tile.merge(row.changes.duplicate(true),true)
        target.tiles[key] = tile
    for identity in update.objects_removed: target.objects.erase(identity)
    for row in update.objects: target.objects[row.item.item_uuid] = row.duplicate(true)
    target.connectors = update.connectors.duplicate(true)
    return success(target)

static func _observe(target: Dictionary, observation: Dictionary) -> void:
    var identity: String = observation.actor.uuid
    if target.actors.has(identity) and not target.actors[identity].present: return
    target.actors[identity] = observation.actor.duplicate(true)
    if observation.contact != null and target.senses != null:
        target.senses.entities[identity] = observation.contact.duplicate(true)

static func stage_actors(target: Dictionary, observations: Array) -> Dictionary:
    var result = copy_target(target)
    for observation in observations:
        if not result.actors.has(observation.actor.uuid): _observe(result, observation)
    return success(result)

static func observe_actors(target: Dictionary, observations: Array) -> Dictionary:
    var result = copy_target(target)
    for observation in observations: _observe(result, observation)
    return success(result)

static func _lineage_audience(target: Dictionary, lineage: Dictionary) -> Dictionary:
    var supplied = Audience.resolve(lineage.observer_uuid, lineage.audience)
    if not supplied.ok: return supplied
    var current = Audience.resolve(target.observer_uuid, target.audience)
    if not current.ok: return current
    if target.generation != lineage.generation or target.observer_uuid != lineage.observer_uuid or current.value != supplied.value:
        return failure("player lineage belongs to a different observer or generation")
    return success(current.value)

static func stage_lineage(target: Dictionary, lineage: Dictionary) -> Dictionary:
    var checked = _lineage_audience(target, lineage)
    if not checked.ok: return checked
    var staged = stage_actors(target, lineage.observations)
    var result: Dictionary = staged.value
    var connectors = {}
    for row in result.connectors: connectors[row.connector_uuid] = row
    for update in lineage.world_updates:
        for tile in update.tiles:
            var key = Audience.point_key(tile.position)
            if not result.tiles.has(key): result.tiles[key] = tile.duplicate(true)
        for object in update.objects:
            if not result.objects.has(object.item.item_uuid): result.objects[object.item.item_uuid] = object.duplicate(true)
        for connector in update.connectors:
            if not connectors.has(connector.connector_uuid): connectors[connector.connector_uuid] = connector.duplicate(true)
    result.connectors = connectors.values()
    return success(result)

static func apply_player_fact(target: Dictionary, fact: Dictionary, source_cursor: Variant = null) -> Dictionary:
    return _apply_player_fact_owned(target, fact, source_cursor, false)

static func _apply_player_fact_owned(target: Dictionary, fact: Dictionary, source_cursor: Variant, composed_senses: bool, cells: Dictionary = {}) -> Dictionary:
    var identity: Variant
    var actor: Variant
    match fact.kind:
        "faction":
            if target.actors.has(fact.entity_uuid): target.actors[fact.entity_uuid].faction = fact.faction_after
        "spatial":
            identity = fact.entity_uuid
            actor = target.actors.get(identity)
            if fact.terminal_departure and actor != null:
                actor.present = false; actor.last_visual_position = null; actor.occupancy_layer = null
                if target.senses != null: target.senses.entities.erase(identity)
                return success(target)
            if actor != null and fact.change_type == "entity_entered": actor.spatial_disposition = "present"
            if actor != null and fact.occupancy_layer != null: actor.occupancy_layer = fact.occupancy_layer
            var audience = Audience.resolve(target.observer_uuid, target.audience)
            if not audience.ok: return audience
            if identity in audience.value.controlled and fact.change_type == "entity_entered":
                if target.senses != null and identity == target.observer_uuid: target.senses.position = fact.position.duplicate()
                if actor != null: actor.last_visual_position = fact.position.duplicate()
        "item_charge":
            identity = fact.source_entity_uuid
            if not target.actors.has(identity): return failure("Missing actor: " + identity)
            actor = target.actors[identity]
            var audience = Audience.resolve(target.observer_uuid, target.audience)
            if not audience.ok: return audience
            if actor.controlled_items == null or identity not in audience.value.controlled:
                return failure("item charges require the controlled actor's inventory")
            var items: Array = []
            for item in actor.controlled_items:
                if fact.item_destroyed and item.item_uuid == fact.item_uuid: continue
                if item.item_uuid == fact.item_uuid:
                    item.charges = fact.charges_after; item.stack_count = fact.stack_count_after
                items.append(item)
            actor.controlled_items = items
            var layers: Array = []
            for layer in actor.visual_loadout.layers:
                if not (fact.item_destroyed and layer.item_uuid == fact.item_uuid): layers.append(layer)
            actor.visual_loadout.layers = layers
        "sensory":
            var audience = Audience.resolve(target.observer_uuid, target.audience)
            if not audience.ok: return audience
            var observed = Audience._observe_retained(target.perception, audience.value, fact, int(target.reducer_cursor if source_cursor == null else source_cursor), cells)
            if not observed.ok: return observed
            target.perception = observed.value
            target.senses = Audience._view_after(target.perception, target.observer_uuid, target.senses, fact, cells) if composed_senses else Audience._view_retained(target.perception, target.observer_uuid)
            if fact.observer_position_changed and target.actors.has(fact.observer_uuid):
                target.actors[fact.observer_uuid].last_visual_position = fact.observer_position.duplicate()
            for member in fact.entity_contacts_changed:
                var contact: Dictionary = fact.entity_contacts_changed[member]
                if contact.visual and target.actors.has(member) and target.actors[member].present:
                    target.actors[member].last_visual_position = contact.position.duplicate()
        "attack":
            if target.actors.has(fact.source_entity_uuid):
                var stance = "none" if fact.attack_source_kind != "equipped" else ("ranged" if fact.weapon_slot in ["RANGED_MAIN", "RANGED_OFF"] else "melee")
                target.actors[fact.source_entity_uuid].visual_loadout.active_weapon_set = stance
        "damage", "heal":
            if fact.kind == "damage" and fact.stage != "applied": return success(target)
            if fact.kind == "heal" and fact.was_blocked: return success(target)
            identity = fact.target_entity_uuid
            if not target.actors.has(identity): return failure("Missing actor: " + identity)
            if fact.resulting_normal_hp == null or fact.resulting_temporary_hp == null:
                return failure("applied damage requires exact committed HP" if fact.kind == "damage" else "healing requires exact committed HP")
            actor = target.actors[identity]
            actor.normal_hp = fact.resulting_normal_hp; actor.temporary_hp = fact.resulting_temporary_hp
            if fact.resulting_temporary_hp <= 0: actor.temporary_hp_grant = null
        "temporary_hit_points":
            identity = fact.entity_uuid
            if not target.actors.has(identity): return failure("Missing actor: " + identity)
            target.actors[identity].temporary_hp = fact.resulting_temporary_hp
            target.actors[identity].temporary_hp_grant = fact.grant.duplicate(true) if fact.grant != null else null
        "life":
            identity = fact.entity_uuid
            if not target.actors.has(identity): return failure("Missing actor: " + identity)
            actor = target.actors[identity]
            actor.life_state = fact.new_state; actor.normal_hp = fact.normal_hit_points
            actor.remains_disposition = fact.remains_disposition
        "equipment":
            actor = target.actors.get(fact.source_entity_uuid)
            if actor != null:
                actor.visual_loadout = fact.visual_loadout.duplicate(true)
                actor.armor_class = fact.armor_class
                actor.controlled_items = fact.controlled_items.duplicate(true) if fact.controlled_items != null else null
        "condition":
            identity = fact.target_entity_uuid
            if not target.actors.has(identity): return failure("Missing actor: " + identity)
            actor = target.actors[identity]
            var condition: Dictionary = fact.condition
            var members = {}
            for row in actor.conditions: members[row.condition_uuid] = row
            if fact.event_type == "condition_removal": members.erase(condition.condition_uuid)
            elif condition.category != "internal": members[condition.condition_uuid] = condition.duplicate(true)
            actor.conditions = members.values()
            var stats: Variant = condition.resulting_stats
            if stats != null:
                actor.spatial_disposition = stats.spatial_disposition
                actor.normal_hp = stats.normal_hp
                actor.maximum_hp = stats.maximum_hp
                actor.armor_class = stats.armor_class
                if stats.resolved_size != null: actor.resolved_size = stats.resolved_size
            else:
                if condition.resulting_max_hp != null: actor.maximum_hp = condition.resulting_max_hp
                if condition.resulting_ac != null: actor.armor_class = condition.resulting_ac
        "turn":
            if fact.round_number != null: target.round_number = fact.round_number
            if fact.event_type in ["turn_start", "turn_end", "encounter_end"]:
                target.current_actor_uuid = fact.entity_uuid if fact.event_type == "turn_start" else null
    return success(target)

static func apply_committed_player_fact(target: Dictionary, fact: Dictionary, source_cursor: int, version_cursors: Dictionary) -> Dictionary:
    return _apply_committed_player_fact_owned(target, fact, source_cursor, version_cursors, false)

static func _apply_committed_player_fact_owned(target: Dictionary, fact: Dictionary, source_cursor: int, version_cursors: Dictionary, composed_senses: bool, cells: Dictionary = {}) -> Dictionary:
    if fact.kind == "spatial" and fact.entity_uuid != null and fact.change_type in ["entity_entered", "entity_left"]:
        if fact.commit_event_uuid == null or not version_cursors.has(fact.commit_event_uuid):
            return failure("Spatial change at cursor %d lacks its recorded commit version" % source_cursor)
        var committed_at: int = version_cursors[fact.commit_event_uuid]
        var previous: int = target.spatial_commit_cursors.get(fact.entity_uuid, -1)
        if committed_at < previous and previous < source_cursor: return success(target)
        target.spatial_commit_cursors[fact.entity_uuid] = committed_at
    return _apply_player_fact_owned(target, fact, source_cursor, composed_senses, cells)

static func reduce_nodes(target: Dictionary, nodes: Array, versions: Array, observations: Array, updates: Array) -> Dictionary:
    return _reduce_nodes_owned(copy_target(target), nodes, versions, observations, updates)

# Only a private transaction enters this fold. Intermediate failures discard
# its mutable containers without touching a previously published state.
static func _reduce_nodes_owned(result: Dictionary, nodes: Array, versions: Array, observations: Array, updates: Array, recorded: Variant = null, profile: Variant = null, cells: Dictionary = {}) -> Dictionary:
    # Arbitrary public inputs first compose exhaustively. Only a context bound
    # to this exact committed state can carry that proof across operations.
    var composed_senses: bool = cells.get("composed",false)
    var indexes = {}
    for row in versions: indexes[row.event_uuid] = row.source_index
    for observation in observations:
        if not indexes.has(observation.event_uuid): return failure("Observation has no recorded version")
    var pending = _ordered_rows(observations, indexes, "event_uuid")
    var next = 0
    var world_updates = {}
    for row in updates: world_updates[row.event_uuid] = row
    for node in nodes:
        if not indexes.has(node.uuid): return failure("Node has no recorded version")
        var admitted: Array = []
        while next < pending.size() and indexes[pending[next].event_uuid] <= indexes[node.uuid]:
            _observe(result, pending[next])
            if recorded != null: admitted.append(pending[next])
            next += 1
        var started: int = Time.get_ticks_usec() if profile != null else 0
        var inputs: Dictionary = Transitions.actor_inputs(result,node) if recorded != null else {}
        if profile != null: _profile_elapsed(profile, "actor_inputs", started)
        started = Time.get_ticks_usec() if profile != null else 0
        var update: Variant = world_updates.get(node.uuid)
        if update != null:
            var updated = apply_world_update(result, update)
            if not updated.ok: return updated
        if profile != null: _profile_elapsed(profile, "world", started)
        started = Time.get_ticks_usec() if profile != null else 0
        if not node.canceled and node.fact != null:
            var folded = _apply_committed_player_fact_owned(result, node.fact, int(indexes[node.uuid]), indexes, composed_senses, cells)
            if not folded.ok: return folded
            if node.fact.kind == "sensory":
                composed_senses = true
                cells.composed = true
        if profile != null:
            _profile_elapsed(profile, "facts", started)
            if not node.canceled and node.fact != null: _profile_elapsed(profile, "fact_" + str(node.fact.kind), started)
        started = Time.get_ticks_usec() if profile != null else 0
        if recorded != null:
            recorded.events.append({"event_uuid":node.uuid, "source_index":indexes[node.uuid],
                "actor_inputs":inputs, "delta":Transitions.capture_delta(result,node,admitted,update)})
        if profile != null: _profile_elapsed(profile, "captures", started)
    while next < pending.size():
        var observation: Dictionary = pending[next]
        _observe(result, observation)
        if recorded != null:
            recorded.trailing.actors[observation.actor.uuid] = Transitions.snapshot_actor(result.actors[observation.actor.uuid])
            if observation.contact != null: recorded.trailing.set.senses = Transitions.snapshot_senses(result.senses)
        next += 1
    return success(result)

static func reduce_initialization(initialization: Dictionary, content_additions: Array = []) -> Dictionary:
    var audience = Audience.resolve(initialization.observer_uuid, initialization.audience)
    if not audience.ok: return audience
    var target = {"generation": initialization.generation, "observer_uuid": initialization.observer_uuid,
        "world": initialization.world.duplicate(true), "tiles": {}, "objects": {}, "connectors": [],
        "senses": null, "reducer_cursor": 0, "spatial_commit_cursors": {}, "actors": {},
        "current_actor_uuid": null, "round_number": 0, "hud_snapshot": null, "audience": audience.value,
        "perception": {"members": {}, "contact_cursors": {}, "effect_cursors": {}, "effect_absences": {}},
        "content": [], "combat_log_appends": []}
    var folded = _reduce_nodes_owned(target, initialization.nodes, initialization.version_rows, initialization.observations, initialization.world_updates)
    if not folded.ok: return folded
    target = folded.value
    target.reducer_cursor = initialization.end_cursor
    var hud: Variant = initialization.hud_snapshot
    if hud != null and (hud.generation != target.generation or hud.observer_uuid != target.observer_uuid or hud.revision > initialization.end_cursor):
        return failure("HUD facts belong to a different or future boundary")
    target.hud_snapshot = hud.duplicate(true) if hud != null else null
    target.content = content_additions.duplicate(true)
    target.content.sort_custom(func(a, b): return content_key(a) < content_key(b))
    return success(target)

static func reduce_lineage(target: Dictionary, lineage: Dictionary) -> Dictionary:
    return _reduce_lineage_owned(copy_target(target), lineage)

static func _reduce_lineage_owned(target: Dictionary, lineage: Dictionary, recorded: Variant = null, profile: Variant = null, cells: Dictionary = {}) -> Dictionary:
    var audience = _lineage_audience(target, lineage)
    if not audience.ok: return audience
    if lineage.end_cursor <= target.reducer_cursor:
        return failure("player lineage precedes this reduction position")
    var folded = _reduce_nodes_owned(target, lineage.events, lineage.version_rows, lineage.observations, lineage.world_updates, recorded, profile, cells)
    if not folded.ok: return folded
    var result: Dictionary = folded.value
    result.reducer_cursor = lineage.end_cursor
    var hud: Variant = lineage.hud_snapshot
    if hud != null:
        if hud.generation != result.generation or hud.observer_uuid != result.observer_uuid or hud.revision > lineage.end_cursor or (result.hud_snapshot != null and hud.revision < result.hud_snapshot.revision):
            return failure("HUD facts belong to a different observer or generation")
        result.hud_snapshot = hud.duplicate(true)
    if recorded != null:
        recorded.trailing.set.reducer_cursor = result.reducer_cursor
        if hud != null: recorded.trailing.set.hud_snapshot = hud.duplicate(true)
    return success(result)

static func reduce_operation(target: Dictionary, update: Dictionary) -> Dictionary:
    return _reduce_operation(target, update, false)

# Internal bounded handoff: callers retain these owned, read-only event records
# only after successful reduction (and journal commit when consuming live bytes).
static func _reduce_operation_recorded(target: Dictionary, update: Dictionary, profile: Variant = null) -> Dictionary:
    return _reduce_operation(target, update, true, profile)

# Only Journal uses retained canonical inputs. Callers that may mutate arbitrary
# public results use the detached entrypoints above.
static func _reduce_operation_retained(target: Dictionary, update: Dictionary, record_events: bool = false, profile: Variant = null, sensory_context: Dictionary = {}) -> Dictionary:
    return _reduce_operation(target, update, record_events, profile, true, sensory_context)

static func _reduce_operation(target: Dictionary, update: Dictionary, record_events: bool, profile: Variant = null, retained: bool = false, sensory_context: Dictionary = {}) -> Dictionary:
    var records = {"lineages":[]} if record_events else {}
    var audience = Audience.resolve(target.observer_uuid, target.audience)
    if not audience.ok: return audience
    if update.audience != audience.value:
        return failure("An operation cannot change its authorized audience")
    var started: int = Time.get_ticks_usec() if profile != null else 0
    var result = _retained_target(target) if retained else copy_target(target)
    var cells = {}
    if retained and is_same(sensory_context.get("state"),target) and is_same(sensory_context.get("perception"),target.perception) and is_same(sensory_context.get("senses"),target.senses):
        cells = Audience._fork_cells(sensory_context.get("cells",{}))
        # _retained_target copied the mutable senses shell, retaining its cell
        # arrays. Rebind only after the committed source ownership proof above.
        if cells.has("view") and is_same(cells.view.source,target.senses):
            cells.view.source = result.senses
    if profile != null: _profile_elapsed(profile, "copy", started)
    if not update.content_additions.is_empty():
        var content = {}
        for row in result.content: content[content_key(row)] = row
        for descriptor in update.content_additions:
            var key = content_key(descriptor)
            if content.has(key) and content[key] != descriptor:
                return failure("An admitted content identity changed its definition")
            content[key] = descriptor.duplicate(true)
        var identities: Array = content.keys()
        identities.sort(); result.content = []
        for key in identities: result.content.append(content[key])
    for lineage in update.lineages:
        if lineage.start_cursor != result.reducer_cursor:
            return failure("Operation occurrence sequence has a gap")
        var recorded: Variant = {"lineage_uuid":lineage.lineage_uuid, "start_cursor":lineage.start_cursor,
            "end_cursor":lineage.end_cursor, "events":[], "trailing":Transitions.empty_delta()} if record_events else null
        var folded = _reduce_lineage_owned(result, lineage, recorded, profile, cells if retained else {})
        if not folded.ok: return folded
        result = folded.value
        if record_events: records.lineages.append(recorded)
    started = Time.get_ticks_usec() if profile != null else 0
    var hud: Variant = update.hud
    if hud != null:
        if hud.generation != result.generation or hud.observer_uuid != result.observer_uuid or hud.revision > result.reducer_cursor or (result.hud_snapshot != null and hud.revision < result.hud_snapshot.revision):
            return failure("HUD belongs to a different or future operation")
        result.hud_snapshot = hud.duplicate(true)
    var first: int = result.combat_log_appends.size()
    for i in range(update.combat_log_appends.size()):
        var row: Dictionary = update.combat_log_appends[i]
        if row.generation != result.generation or row.observer_uuid != result.observer_uuid or row.operation_end_cursor > result.reducer_cursor or row.encounter_log_index != first + i:
            return failure("Standalone log append is out of order or belongs to another audience")
    result.combat_log_appends.append_array(update.combat_log_appends.duplicate(true))
    var accepted = success(result)
    if record_events: accepted.transitions = records
    if retained:
        # A first sensory event or observer reset takes the exhaustive view path.
        # Retain its final indexes now so the next accepted operation starts warm.
        if cells.get("composed",false) and result.senses != null:
            if not cells.has("view") or not is_same(cells.view.source,result.senses):
                cells.view = Audience._indexed_senses(result.senses)
        accepted.sensory_context = {"state":result, "perception":result.perception,
            "senses":result.senses, "cells":cells}
    if profile != null: _profile_elapsed(profile, "finalize", started)
    return accepted

static func state_before_event(before: Dictionary, lineage: Dictionary, event: Dictionary) -> Dictionary:
    var first: Variant = null
    for row in lineage.version_rows:
        if row.lineage_uuid == event.lineage_uuid:
            if first == null or row.source_index < first: first = row.source_index
    if first == null: return failure("Event lineage has no recorded versions")
    var completed = {}
    for row in lineage.version_rows:
        if row.source_index < first: completed[row.event_uuid] = true
    var events: Array = []
    for row in lineage.events:
        if completed.has(row.uuid): events.append(row)
    if events.is_empty(): return success(copy_target(before))
    var part: Dictionary = lineage.duplicate(true)
    part.events = events; part.end_cursor = first
    part.observations = lineage.observations.filter(func(row): return completed.has(row.event_uuid))
    part.world_updates = lineage.world_updates.filter(func(row): return completed.has(row.event_uuid))
    return reduce_lineage(before, part)

static func lineage_branch(lineage: Dictionary, root: Dictionary) -> Dictionary:
    var by_lineage = {}; var intervals = {}
    for node in lineage.events: by_lineage[node.lineage_uuid] = node
    for row in lineage.version_rows:
        var prior: Array = intervals.get(row.lineage_uuid, [row.source_index, row.source_index])
        intervals[row.lineage_uuid] = [mini(prior[0], row.source_index), maxi(prior[1], row.source_index)]
    if not intervals.has(root.lineage_uuid): return failure("Root lineage has no recorded versions")
    var bounds: Array = intervals[root.lineage_uuid]
    var pending: Array = [root.lineage_uuid]
    for node in lineage.events:
        if not intervals.has(node.lineage_uuid): return failure("Node lineage has no recorded versions")
        var interval: Array = intervals[node.lineage_uuid]
        if node.parent_lineage == null and bounds[0] <= interval[0] and interval[1] <= bounds[1]: pending.append(node.lineage_uuid)
    var selected = {}
    while not pending.is_empty():
        var identity: String = pending.pop_back()
        if selected.has(identity): continue
        if not by_lineage.has(identity): return failure("Child lineage has no disclosed node")
        selected[identity] = true
        pending.append_array(by_lineage[identity].children_lineages)
    var result: Dictionary = lineage.duplicate(true)
    result.root = root.duplicate(true)
    result.events = lineage.events.filter(func(node): return selected.has(node.lineage_uuid))
    result.version_rows = lineage.version_rows.filter(func(row): return selected.has(row.lineage_uuid))
    var identities = {}
    for row in result.version_rows: identities[row.event_uuid] = true
    result.start_cursor = result.version_rows[0].source_index
    result.end_cursor = result.version_rows[-1].source_index + 1
    result.observations = lineage.observations.filter(func(row): return identities.has(row.event_uuid))
    result.world_updates = lineage.world_updates.filter(func(row): return identities.has(row.event_uuid))
    result.hud_snapshot = null
    return success(result)

static func index_player_lineage(lineage: Dictionary) -> Dictionary:
    var result = {"by_lineage": {}, "by_uuid": {}, "source_order": {}, "owned": {}, "results": {}, "damage_requests": {}}
    for row in lineage.version_rows: result.source_order[row.event_uuid] = row.source_index
    for node in lineage.events:
        result.by_lineage[node.lineage_uuid] = node.duplicate(true)
        result.by_uuid[node.uuid] = node.duplicate(true)
    for node in lineage.events:
        var ancestors: Array = []
        var current: Dictionary = node
        while current.lineage_uuid not in ancestors:
            ancestors.append(current.lineage_uuid)
            var request: Variant = current.lineage_uuid if current.fact != null and current.fact.kind == "damage" and current.fact.stage == "taken" else result.damage_requests.get(current.lineage_uuid)
            if request != null:
                for identity in ancestors: result.damage_requests[identity] = request
                break
            if current.parent_lineage == null or not result.by_lineage.has(current.parent_lineage): break
            current = result.by_lineage[current.parent_lineage]
    for node in lineage.events:
        if not result.source_order.has(node.uuid): return failure("Node has no recorded version")
    var ordered = _ordered_rows(lineage.events.duplicate(true), result.source_order, "uuid")
    for node in ordered:
        if node.resolution_ref == null: continue
        var key = resolution_key(node.resolution_ref)
        if not result.owned.has(key): result.owned[key] = []
        result.owned[key].append(node)
        if not node.canceled and node.fact != null and (node.fact.kind == "object_damage" or (node.fact.kind == "damage" and node.fact.stage == "applied")):
            if not result.results.has(key): result.results[key] = []
            result.results[key].append(node)
    return success(result)

static func _profile_elapsed(profile: Dictionary, phase: String, started: int) -> void:
    profile[phase] = float(profile.get(phase, 0.0)) + (Time.get_ticks_usec() - started) / 1000.0
