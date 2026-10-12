extends RefCounted
## Passive presentation of admitted occurrences. The SDK reducer owns truth.
const Tracks = preload("res://presentation/tracks.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Authoring = preload("res://presentation/authoring.gd")
const EventTrace = preload("res://presentation/event_trace.gd")

static func empty_delta() -> Dictionary:
    return {"set":{},"actors":{},"tiles":{},"objects":{},"objects_removed":[],"spatial_commit_cursors":{}}

static func apply_delta(target: Dictionary, delta: Dictionary) -> void:
    for key in delta.get("set", {}): target[key] = delta.set[key]
    # Each operation publishes only its new log rows. Replaying another
    # timeline must not mutate the retained delta or repeat previous history.
    if delta.has("log_appends"):
        target.combat_log_appends.append_array(delta.log_appends)
    for key in delta.get("objects_removed", []): target.objects.erase(key)
    for field in ["actors", "tiles", "objects", "spatial_commit_cursors"]:
        for key in delta.get(field, {}): target[field][key] = delta[field][key]

static func _actor(state: Dictionary, group: Dictionary, identity: Variant, node: Dictionary, graph: Dictionary) -> Dictionary:
    var observed: Dictionary = graph.actor_inputs.get(node.uuid,{})
    if observed.has(identity): return observed[identity]
    if state.actors.has(identity): return state.actors[identity]
    return group.staged_actors.get(identity, {})

static func _track(group: Dictionary, node: Dictionary, actor: Dictionary, clip_name: String,
        start: float, speed: float, priority: int, cache: Dictionary) -> Dictionary:
    var clip = Authoring.clip(actor, clip_name, cache)
    if clip.is_empty():
        group.skipped.append({"occurrence":node.lineage_uuid,"kind":node.fact.kind,"reason":"missing_authored_clip","clip":clip_name})
        return {}
    var row = Tracks.body(actor.uuid,Authoring.rig_id(actor,cache),clip_name,clip,speed,priority)
    row.merge({"trace_track_id":"%s:%s:%s" % [group.operation_sequence,node.uuid,group.actor_tracks.size()],
        "occurrence":node.lineage_uuid,"source_event_uuid":node.uuid,"source_lineage":node.lineage_uuid,"start_ms":start},true)
    group.actor_tracks.append(row)
    return row

static func _held_contact(track: Dictionary, identity: String, graph: Dictionary) -> void:
    if track.is_empty(): return
    var contact: Dictionary = graph.contacts.get(identity,{})
    track.merge(contact,true)
    var point: Variant = graph.positions.get(identity)
    track.from_position = point
    track.to_position = point

static func _children(node: Dictionary, graph: Dictionary) -> Array:
    var rows: Array = []
    for identity in node.children_lineages:
        if graph.nodes.has(identity): rows.append(graph.nodes[identity])
    rows.sort_custom(func(a,b): return graph.first[a.lineage_uuid] < graph.first[b.lineage_uuid])
    return rows

static func _schedule(node: Dictionary, start: float, state: Dictionary, group: Dictionary,
        graph: Dictionary, cache: Dictionary, jump: Dictionary = {}) -> float:
    if graph.visited.has(node.lineage_uuid): return start
    graph.visited[node.lineage_uuid] = true
    graph.starts[node.uuid] = start
    var fact: Variant = node.fact
    var children = _children(node,graph)
    var finish = start
    var kind: String = fact.kind if fact != null else "undisclosed"
    if kind == "movement":
        if node.canceled: group.skipped.append({"occurrence":node.lineage_uuid,"kind":kind,"reason":"canceled_body"})
        var context = {"occurrence":node.lineage_uuid}
        if fact.trajectory == "direct_arc" and not fact.path.is_empty():
            var motion = Authoring.load_data("catalog/movement_context.json",cache)
            context = Tracks.jump_context(fact.path,motion,node.lineage_uuid)
        for child in children: finish = _schedule(child,finish,state,group,graph,cache,context)
    elif kind == "step":
        graph.positions[fact.source_entity_uuid] = fact.from_position
        var held_contact: Dictionary = graph.contacts.get(fact.source_entity_uuid,{})
        held_contact.from_elevation_feet = fact.from_elevation_feet
        held_contact.to_elevation_feet = fact.from_elevation_feet
        graph.contacts[fact.source_entity_uuid] = held_contact
        # Effect-phase reactions finish before the authoritative entry.
        for child in children:
            if child.fact != null and child.fact.kind == "attack": finish = _schedule(child,finish,state,group,graph,cache)
        if finish > start:
            var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
            var previous: Dictionary = graph.last_motion.get(fact.source_entity_uuid,{})
            var held = _track(group,node,actor,previous.get("clip","Idle"),start,1.0,5,cache)
            if not held.is_empty():
                _held_contact(held,fact.source_entity_uuid,graph)
                held.duration_ms = finish-start
                held.source_start_seconds = previous.get("source_end_seconds",0.0)
                held.source_end_seconds = held.source_start_seconds
                held.occurrence = previous.get("occurrence",held.occurrence)
        var end_motion = finish
        if not node.canceled and fact.committed and fact.trajectory in ["path","direct_arc"]:
            var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
            var motion = Authoring.load_data("catalog/movement_context.json",cache)
            var body = Authoring.body("movement",actor,fact,cache)
            var speed_scale = 1.0
            if fact.resolved_speed_feet != null and fact.resolved_speed_feet > 0:
                speed_scale = fact.resolved_speed_feet / Authoring.movement_reference_speed(cache)
            var rate: float = body.actor.playbackSpeed * speed_scale
            var track = _track(group,node,actor,body.actor.clip,finish,rate,10,cache)
            if not track.is_empty():
                if fact.trajectory=="direct_arc" and not jump.has("path"):
                    group.skipped.append({"occurrence":node.lineage_uuid,"kind":kind,"reason":"undisclosed_jump_arc_uses_disclosed_edge_only"})
                Tracks.movement(track,fact,motion,body,Authoring.clip(actor,body.actor.clip,cache),jump,rate,speed_scale,graph.last_motion.get(fact.source_entity_uuid,{}))
                end_motion = finish + track.duration_ms
                graph.last_motion[fact.source_entity_uuid] = track
                graph.contacts[fact.source_entity_uuid] = {"from_elevation_feet":fact.to_elevation_feet,
                    "to_elevation_feet":fact.to_elevation_feet,"trajectory":track.trajectory,
                    "arc_height_px":track.arc_height_px,"motion_fraction_from":track.motion_fraction_to,
                    "motion_fraction_to":track.motion_fraction_to}
        if not node.canceled and fact.committed:
            graph.positions[fact.source_entity_uuid] = fact.to_position
            if fact.trajectory not in ["path","direct_arc"]:
                group.skipped.append({"occurrence":node.lineage_uuid,"kind":kind,"reason":"motion_trajectory_out_of_pass","trajectory":fact.trajectory})
        for child in children:
            if not graph.visited.has(child.lineage_uuid): end_motion = maxf(end_motion,_schedule(child,end_motion,state,group,graph,cache))
        finish = end_motion
    elif kind == "attack" and not node.canceled:
        var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
        var recipe = Authoring.attack(fact,actor,cache)
        graph.recipes[node.uuid] = recipe
        var contact = start
        if not recipe.is_empty() and recipe.actor.enabled:
            var speed = recipe.actor.playbackSpeed * Authoring.playback_rate(actor,cache)
            var track = _track(group,node,actor,recipe.actor.clip,start,speed,20,cache)
            if not track.is_empty():
                _held_contact(track,fact.source_entity_uuid,graph)
                track.target_uuid = fact.target_entity_uuid
                var target = _actor(state,group,fact.target_entity_uuid,node,graph)
                track.target_position = fact.target_position if fact.target_position != null else graph.positions.get(fact.target_entity_uuid,target.get("last_visual_position"))
                track.from_position = graph.positions.get(fact.source_entity_uuid,actor.get("last_visual_position"))
                track.to_position = track.from_position
                var clip = Authoring.clip(actor,recipe.actor.clip,cache)
                for anchor in recipe.anchors:
                    if anchor.name in ["contact","release"]: contact = start + anchor.frame / clip.fps * 1000.0 / speed
                var visual = {"actors":{actor.uuid:actor.duplicate(true)}}
                Reducer.apply_player_fact(visual,fact)
                track.visual_loadout = visual.actors[actor.uuid].visual_loadout
                track.hidden_slots = recipe.actor.get("hiddenSlots",[])
                track.contact_ms = contact
                finish = start + track.duration_ms
        else: group.skipped.append({"occurrence":node.lineage_uuid,"kind":kind,"reason":"missing_authored_attack_recipe"})
        for child in children: finish = maxf(finish,_schedule(child,contact,state,group,graph,cache))
    elif kind == "damage" and fact.stage == "applied" and not node.canceled:
        var actor = _actor(state,group,fact.target_entity_uuid,node,graph)
        var body = Authoring.body("damage",actor,fact,cache)
        if fact.applied_damage > 0:
            var track = _track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,30,cache)
            if not track.is_empty():
                _held_contact(track,fact.target_entity_uuid,graph)
                Tracks.body_keys(track,body,Authoring.clip(actor,body.actor.clip,cache))
                finish = start + track.duration_ms
        for child in children: finish = maxf(finish,_schedule(child,start,state,group,graph,cache))
    elif kind == "life" and not node.canceled:
        var actor = _actor(state,group,fact.entity_uuid,node,graph)
        var body = Authoring.body("death" if fact.new_state == "dead" else "life",actor,fact,cache)
        if not body.is_empty() and body.actor.enabled:
            var track = _track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,40,cache)
            if not track.is_empty():
                _held_contact(track,fact.entity_uuid,graph)
                Tracks.body_keys(track,body,Authoring.clip(actor,body.actor.clip,cache))
                track.holding_pose = fact.new_state != "alive"
                finish = start + track.duration_ms
        for child in children: finish = maxf(finish,_schedule(child,start,state,group,graph,cache))
    else:
        for child in children: finish = maxf(finish,_schedule(child,start,state,group,graph,cache,jump))
        group.skipped.append({"occurrence":node.lineage_uuid,"kind":kind,"reason":"canceled_body" if node.canceled else "no_body_visual_in_this_pass"})
    # HP/life after-values are exposed at their effect contact, not recovery end.
    graph.times[node.uuid] = start if kind in ["damage","life"] else finish
    graph.ends[node.uuid] = finish
    return finish

static func _capture_delta(target: Dictionary, node: Dictionary, observations: Array, update: Variant) -> Dictionary:
    var delta = empty_delta()
    var actors = {}
    for observation in observations: actors[observation.actor.uuid] = true
    var fact: Variant = node.fact
    if fact != null and not node.canceled:
        for field in ["entity_uuid","source_entity_uuid","target_entity_uuid","observer_uuid"]:
            if fact.get(field) != null: actors[fact[field]] = true
        if fact.kind == "sensory":
            for identity in fact.entity_contacts_changed: actors[identity] = true
            delta.set.perception = target.perception.duplicate(true)
        if fact.kind in ["sensory","spatial"]: delta.set.senses = target.senses.duplicate(true) if target.senses != null else null
        if fact.kind == "turn":
            delta.set.current_actor_uuid = target.current_actor_uuid
            delta.set.round_number = target.round_number
        if fact.kind == "spatial" and fact.entity_uuid != null and target.spatial_commit_cursors.has(fact.entity_uuid):
            delta.spatial_commit_cursors[fact.entity_uuid] = target.spatial_commit_cursors[fact.entity_uuid]
    for identity in actors:
        if target.actors.has(identity): delta.actors[identity] = target.actors[identity].duplicate(true)
    for observation in observations:
        if observation.contact != null:
            delta.set.senses = target.senses.duplicate(true) if target.senses != null else null
    if update != null:
        for tile in update.tiles: delta.tiles[Reducer.Audience.point_key(tile.position)] = tile.duplicate(true)
        for object in update.objects: delta.objects[object.item.item_uuid] = object.duplicate(true)
        delta.objects_removed = update.objects_removed.duplicate()
        delta.set.connectors = target.connectors.duplicate(true)
    return delta

static func compile(before: Dictionary, packet: Dictionary, cache: Dictionary) -> Dictionary:
    var validated = Reducer.reduce_operation(before,packet)
    if not validated.ok: return validated
    return compile_admitted(before,packet,cache,validated.value)

static func compile_admitted(before: Dictionary, packet: Dictionary, cache: Dictionary, final_state: Dictionary) -> Dictionary:
    # The session has already transactionally reduced this exact packet in the
    # journal. Standalone callers use compile(), which retains admission.
    var target = Reducer.copy_target(before)
    var groups: Array = []
    for lineage in packet.lineages:
        var group = {"id":lineage.lineage_uuid,"start_cursor":lineage.start_cursor,"end_cursor":lineage.end_cursor,
            "operation_sequence":packet.get("cursor",{}).get("sequence",-1),"operation_end":false,
            "duration_ms":0.0,"actor_tracks":[],"commits":[],"staged_actors":{},"staged_at_ms":{},"staged_tiles":{},"staged_tile_at_ms":{},"skipped":[]}
        for observation in lineage.observations:
            if not target.actors.has(observation.actor.uuid) and not group.staged_actors.has(observation.actor.uuid):
                group.staged_actors[observation.actor.uuid] = observation.actor.duplicate(true)
        for update in lineage.world_updates:
            for tile in update.tiles:
                var key = Reducer.Audience.point_key(tile.position)
                if not target.tiles.has(key) and not group.staged_tiles.has(key): group.staged_tiles[key] = tile.duplicate(true)
        var graph = {"nodes":{},"first":{},"times":{},"starts":{},"ends":{},"recipes":{},"visited":{},"positions":{},"actor_inputs":{},"contacts":{},"last_motion":{}}
        for actor in target.actors.values() + group.staged_actors.values():
            graph.positions[actor.uuid] = actor.last_visual_position
            if actor.last_visual_position != null:
                var tile: Dictionary = target.tiles.get(Reducer.Audience.point_key(actor.last_visual_position),group.staged_tiles.get(Reducer.Audience.point_key(actor.last_visual_position),{}))
                graph.contacts[actor.uuid] = {"from_elevation_feet":tile.get("elevation_steps",0)*5.0,
                    "to_elevation_feet":tile.get("elevation_steps",0)*5.0}
        var cursors = {}
        for row in lineage.version_rows:
            cursors[row.event_uuid] = row.source_index
            graph.first[row.lineage_uuid] = mini(graph.first.get(row.lineage_uuid,row.source_index),row.source_index)
        for node in lineage.events: graph.nodes[node.lineage_uuid] = node
        var pending = Reducer._ordered_rows(lineage.observations,cursors,"event_uuid")
        var updates = {}
        for update in lineage.world_updates: updates[update.event_uuid] = update
        var next = 0
        for node in lineage.events:
            var admitted: Array = []
            while next < pending.size() and cursors[pending[next].event_uuid] <= cursors[node.uuid]:
                Reducer._observe(target,pending[next]); admitted.append(pending[next]); next += 1
            var actor_inputs = {}
            if node.fact != null:
                for field in ["entity_uuid","source_entity_uuid","target_entity_uuid","observer_uuid"]:
                    var identity: Variant = node.fact.get(field)
                    if identity != null and target.actors.has(identity): actor_inputs[identity] = target.actors[identity].duplicate(true)
            graph.actor_inputs[node.uuid] = actor_inputs
            var update: Variant = updates.get(node.uuid)
            if update != null: Reducer.apply_world_update(target,update)
            if not node.canceled and node.fact != null:
                var folded = Reducer.apply_committed_player_fact(target,node.fact,cursors[node.uuid],cursors)
                if not folded.ok: return folded
            group.commits.append({"at_ms":0.0,"source_index":cursors[node.uuid],"event_uuid":node.uuid,
                "delta":_capture_delta(target,node,admitted,update)})
        var trailing = empty_delta()
        while next < pending.size():
            var observation: Dictionary = pending[next]
            Reducer._observe(target,observation)
            trailing.actors[observation.actor.uuid] = target.actors[observation.actor.uuid].duplicate(true)
            if observation.contact != null: trailing.set.senses = target.senses.duplicate(true) if target.senses != null else null
            next += 1
        target.reducer_cursor = lineage.end_cursor
        trailing.set.reducer_cursor = lineage.end_cursor
        if lineage.hud_snapshot != null:
            target.hud_snapshot = lineage.hud_snapshot
            trailing.set.hud_snapshot = lineage.hud_snapshot.duplicate(true)
        if lineage.root != null: group.duration_ms = _schedule(lineage.root,0.0,target,group,graph,cache)
        for node in lineage.events:
            if not graph.visited.has(node.lineage_uuid):
                group.duration_ms = maxf(group.duration_ms,_schedule(node,0.0,target,group,graph,cache))
        var at = 0.0
        for commit in group.commits:
            at = maxf(at,graph.times.get(commit.event_uuid,at))
            commit.at_ms = at
        group.duration_ms = maxf(group.duration_ms,at)
        for identity in group.staged_actors:
            var admitted_at = group.duration_ms
            for commit in group.commits:
                if commit.delta.actors.has(identity): admitted_at = minf(admitted_at,commit.at_ms)
            for track in group.actor_tracks:
                if track.actor_uuid == identity or track.get("target_uuid") == identity: admitted_at = minf(admitted_at,track.start_ms)
            group.staged_at_ms[identity] = admitted_at
        for key in group.staged_tiles:
            var visible_at = group.duration_ms
            for commit in group.commits:
                if commit.delta.tiles.has(key): visible_at = minf(visible_at,commit.at_ms)
            for identity in group.staged_actors:
                var point: Variant = group.staged_actors[identity].last_visual_position
                if point != null and Reducer.Audience.point_key(point) == key: visible_at = minf(visible_at,group.staged_at_ms[identity])
            for track in group.actor_tracks:
                for field in ["from_position","to_position","target_position"]:
                    if track.get(field) != null and Reducer.Audience.point_key(track[field]) == key: visible_at = minf(visible_at,track.start_ms)
            group.staged_tile_at_ms[key] = visible_at
        group.commits.append({"at_ms":group.duration_ms,"source_index":lineage.end_cursor,"delta":trailing})
        group.events = EventTrace.compile_rows(lineage,group,graph,cache)
        groups.append(group)
    if groups.is_empty():
        groups.append({"id":"operation:%s" % packet.get("cursor",{}).get("sequence",-1),"start_cursor":before.reducer_cursor,
            "end_cursor":before.reducer_cursor,"operation_sequence":packet.get("cursor",{}).get("sequence",-1),
            "operation_end":true,"duration_ms":0.0,"actor_tracks":[],"commits":[],"staged_actors":{},"staged_at_ms":{},"staged_tiles":{},"staged_tile_at_ms":{},"skipped":[]})
    # Native operation identity survives every lineage, including the empty
    # operation marker. Command numbers are scoped to the full cursor identity.
    for group in groups:
        group.cursor = packet.get("cursor",{}).duplicate(true)
        group.command_number = packet.get("command_number")
    var last: Dictionary = groups[-1]
    last.operation_end = true
    var ending = empty_delta()
    for field in ["hud_snapshot","reducer_cursor"]:
        var value: Variant = final_state[field]
        ending.set[field] = value.duplicate(true) if value is Array or value is Dictionary else value
    if not packet.content_additions.is_empty(): ending.set.content = final_state.content.duplicate(true)
    if not packet.combat_log_appends.is_empty(): ending.log_appends = packet.combat_log_appends.duplicate(true)
    last.commits.append({"at_ms":last.duration_ms,"source_index":final_state.reducer_cursor,"delta":ending,
        "trace_logs":EventTrace.operation_logs(packet)})
    var skipped: Array = []
    for group in groups: skipped.append_array(group.skipped)
    return Reducer.success({"groups":groups,"final_state":final_state,"skipped":skipped})
