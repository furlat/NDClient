extends RefCounted
## Passive presentation of admitted occurrences. The SDK reducer owns truth.
const Tracks = preload("res://presentation/tracks.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Transitions = preload("res://sdk/transitions.gd")
const Authoring = preload("res://presentation/authoring.gd")
const EventTrace = preload("res://presentation/event_trace.gd")
const Components = preload("res://presentation/components.gd")
const DamageTiming = preload("res://presentation/damage_timing.gd")

static func empty_delta() -> Dictionary:
    return Transitions.empty_delta()

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
    row.activity={"attack":"attack","spell":"cast","action":"act","shove":"act","condition":"act","damage":"hit","life":"hit","forced_movement":"forced_move"}.get(node.fact.kind,"idle")
    if node.fact.kind=="step":row.activity="jump" if node.fact.trajectory in ["direct_arc","connector_transfer"] else "move"
    # The source outfit belongs to this occurrence, not its operation endpoints.
    row.presentation_actor = {}
    for field in ["uuid","creature_content_ref","appearance","visual_loadout","last_visual_position","life_state","present","spatial_disposition","remains_disposition"]:
        if actor.has(field): row.presentation_actor[field] = actor[field]
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
    if fact!=null and fact.kind=="damage":
        graph.impact_contacts[node.uuid]=graph.contacts.get(fact.target_entity_uuid,{}).duplicate()
    var children = _children(node,graph)
    var finish = start
    var equipment_commit = start
    var kind: String = fact.kind if fact != null else "undisclosed"
    if kind == "movement":
        if node.canceled: group.skipped.append({"occurrence":node.lineage_uuid,"kind":kind,"reason":"canceled_body"})
        var context = {"occurrence":node.lineage_uuid}
        if fact.trajectory == "direct_arc" and not fact.path.is_empty():
            var motion = Authoring.load_data("catalog/movement_context.json",cache)
            context = Tracks.jump_context(fact.path,motion,node.lineage_uuid)
        for child in children: finish = _schedule(child,finish,state,group,graph,cache,context)
    elif kind == "step":
        if fact.trajectory=="connector_transfer":
            fact=fact.duplicate()
            for connector in state.get("connectors",[]):
                if fact.from_position in connector.endpoints and fact.to_position in connector.endpoints:
                    fact.connector_presentation_key=connector.presentation_key
                    break
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
        if not node.canceled and fact.committed and fact.trajectory in ["path","direct_arc","connector_transfer"]:
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
                if fact.trajectory=="path":
                    track.movement_metrics={"base_step_ms":motion.walkStepDurationMs,
                        "base_tiles_per_second":1000.0/motion.walkStepDurationMs,
                        "speed_multiplier":speed_scale,"tiles_per_second":1000.0/motion.walkStepDurationMs*speed_scale,
                        "resolved_speed_feet":fact.resolved_speed_feet,"reference_speed_feet":Authoring.movement_reference_speed(cache),
                        "duration_source":"catalog/movement_context.json:/walkStepDurationMs",
                        "speed_source":"StepFact.resolved_speed_feet"}
                if body.has("condition_pose"): track.condition_pose=body.condition_pose
                end_motion = finish + track.duration_ms
                graph.last_motion[fact.source_entity_uuid] = track
                graph.contacts[fact.source_entity_uuid] = {"from_elevation_feet":fact.to_elevation_feet,
                    "to_elevation_feet":fact.to_elevation_feet,"trajectory":track.trajectory,
                    "arc_height_px":track.arc_height_px,"motion_fraction_from":track.motion_fraction_to,
                    "motion_fraction_to":track.motion_fraction_to}
        if not node.canceled and fact.committed:
            graph.positions[fact.source_entity_uuid] = fact.to_position
            if fact.trajectory not in ["path","direct_arc","connector_transfer"]:
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
                track.presentation_actor.visual_loadout=track.visual_loadout
                track.hidden_slots = recipe.actor.get("hiddenSlots",[])
                track.effect_layers=Components.attack_layers(recipe,fact,actor,cache)
                var trail=Components.weapon_trail(recipe,fact,visual.actors[actor.uuid],cache)
                if not trail.is_empty():
                    track.weapon_trail=trail
                    if fact.damage_types.all(func(type):return type in ["Bludgeoning","Piercing","Slashing"]):
                        track.effect_layers=track.effect_layers.filter(func(layer):return layer.slot!="slash")
                track.contact_ms = contact
                finish = start + track.duration_ms
                if recipe.get("projectile")!=null and track.from_position!=null and track.target_position!=null:
                    track.target_elevation_feet=graph.contacts.get(fact.target_entity_uuid,{}).get("from_elevation_feet",0)
                    contact+=Components.bolt(group,node,recipe.projectile,contact,track,target,cache)
                    finish=maxf(finish,contact)
                track.impact_ms=contact
        else: group.skipped.append({"occurrence":node.lineage_uuid,"kind":kind,"reason":"missing_authored_attack_recipe"})
        for child in children: finish = maxf(finish,_schedule(child,contact,state,group,graph,cache))
    elif kind in ["action","shove"] and not node.canceled:
        var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
        var recipe = Authoring.action(fact,cache,actor)
        graph.recipes[node.uuid] = recipe
        var contact = start
        if recipe.get("actor",{}).get("enabled",false):
            var rate = recipe.actor.playbackSpeed*Authoring.playback_rate(actor,cache)
            var track = _track(group,node,actor,recipe.actor.clip,start,rate,20,cache)
            if not track.is_empty():
                _held_contact(track,fact.source_entity_uuid,graph)
                Tracks.body_keys(track,recipe,Authoring.clip(actor,recipe.actor.clip,cache))
                track.source=Authoring.recipe_source(recipe,"actor/clip",cache)
                track.target_uuid=fact.get("target_entity_uuid")
                track.target_position=graph.positions.get(track.target_uuid)
                for anchor in recipe.get("anchors",[]):
                    if anchor.name in ["contact","effect","release"]: contact=start+float(anchor.frame)/Authoring.clip(actor,recipe.actor.clip,cache).fps*1000/rate
                track.contact_ms=contact
                finish=start+track.duration_ms
        for child in children:
            # Aggregate weapon actions preserve actual child order. Other effects
            # begin at the authored action contact and can overlap its recovery.
            var child_start = finish if not recipe.get("actor",{}).get("enabled",false) and child.get("fact")!=null and child.fact.kind=="attack" else contact
            finish=maxf(finish,_schedule(child,child_start,state,group,graph,cache))
    elif kind == "equipment" and not node.canceled:
        var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
        var body = Authoring.body("equipment",actor,fact,cache)
        graph.recipes[node.uuid] = body
        if body.get("actor",{}).get("enabled",false):
            var clip = Authoring.clip(actor,body.actor.clip,cache)
            var track = _track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,20,cache)
            if not track.is_empty():
                _held_contact(track,fact.source_entity_uuid,graph)
                Tracks.body_keys(track,body,clip)
                track.activity="act"
                track.source=body.source
                finish=start+track.duration_ms
                for anchor in body.get("anchors",[]):
                    if anchor.name=="commit":
                        var frame=float(clip.frames)-1-float(anchor.frame) if body.get("reversed",false) else float(anchor.frame)
                        equipment_commit=start+minf(track.duration_ms,frame*1000.0/clip.fps/body.actor.playbackSpeed)
                track.commit_ms=equipment_commit
        for child in children:finish=maxf(finish,_schedule(child,equipment_commit,state,group,graph,cache))
    elif kind == "forced_movement" and not node.canceled:
        var actor = _actor(state,group,fact.target_entity_uuid,node,graph)
        var profile = Authoring.load_data("catalog/forced_movement_profile.json",cache)
        var context = Authoring.load_data("catalog/forced_movement_context.json",cache)
        if fact.start_position!=fact.end_position:
            var track = _track(group,node,actor,profile.target_clip,start,profile.playback_speed,25,cache)
            if not track.is_empty():
                track.duration_ms=profile.duration_ms*context.durationScale
                track.source_start_seconds=float(profile.brace_frame)/Authoring.clip(actor,profile.target_clip,cache).fps
                track.source_end_seconds=track.source_start_seconds
                track.merge({"from_position":fact.start_position,"to_position":fact.end_position,
                    "from_elevation_feet":fact.start_elevation_feet,"to_elevation_feet":fact.end_elevation_feet,
                    "motion":true,"trajectory":"forced","motion_curve":context.motionCurve,"target_position":graph.positions.get(fact.source_entity_uuid)},true)
                finish=start+track.duration_ms
                graph.positions[fact.target_entity_uuid]=fact.end_position
        for child in children: finish=maxf(finish,_schedule(child,finish,state,group,graph,cache))
    elif kind == "condition" and not node.canceled:
        var actor = _actor(state,group,fact.target_entity_uuid,node,graph)
        var recipe: Dictionary = Authoring.load_data("catalog/condition_recipes.json",cache).get(fact.condition.behavior_id,{})
        graph.recipes[node.uuid]=recipe
        var phase = "removal" if fact.event_type=="condition_removal" else "application"
        var body: Dictionary=recipe.get(phase,{}).get("bodyAnimation",{}) if fact.event_type in ["condition_application","condition_removal"] else {}
        if not body.is_empty():
            var track=_track(group,node,actor,body.bodyClip,start,body.get("bodyPlaybackSpeed",1.0),35,cache)
            if not track.is_empty():
                _held_contact(track,fact.target_entity_uuid,graph)
                Tracks.body_keys(track,{"actor":{"hiddenSlots":[]},"reversed":body.get("reversed",false)},Authoring.clip(actor,body.bodyClip,cache))
                track.holding_pose=false
                finish=start+track.duration_ms
        for child in children: finish=maxf(finish,_schedule(child,start,state,group,graph,cache))
    elif kind == "spell" and not node.canceled:
        var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
        var recipe = Authoring.spell(fact,cache)
        graph.recipes[node.uuid]=recipe
        var cast: Dictionary=recipe.get("cast",{})
        var application: Variant=fact.get("application")
        var cast_key: String=application.lineage_uuid if application!=null else node.lineage_uuid
        var contact=start
        if not graph.casts.has(cast_key) and not cast.is_empty():
            var rate=cast.get("bodyPlaybackSpeed",1.0)*Authoring.playback_rate(actor,cache)
            var track=_track(group,node,actor,cast.actionClip,start,rate,20,cache)
            if not track.is_empty():
                _held_contact(track,fact.source_entity_uuid,graph)
                track.target_position=graph.positions.get(fact.get("target_entity_uuid"))
                track.hidden_slots=["weapon","offhand"] if cast.get("equipment",{}).get("kind")=="hidden" else []
                track.effect_layers=Components.cast_layers(cast,actor,cache)
                contact=start+cast.get("releaseFrame",0)/Authoring.clip(actor,cast.actionClip,cache).fps*1000.0/rate
                track.contact_ms=contact
                finish=start+track.duration_ms
            graph.casts[cast_key]={"start":start,"release":contact,"finish":finish,"recipe":recipe,"source_event_uuid":node.uuid}
        var owner: Dictionary=graph.casts.get(cast_key,{"release":start,"finish":start,"start":start})
        contact=owner.release
        if application!=null:
            contact+=float(application.index)*recipe.get("projectile",{}).get("missileStaggerMs",0)
            var projectile: Dictionary=recipe.get("projectile",{})
            var source: Variant=graph.positions.get(fact.source_entity_uuid)
            var target: Variant=graph.positions.get(fact.get("target_entity_uuid"))
            if not projectile.is_empty() and source!=null and target!=null:
                var config=Authoring.load_data("catalog/rig.json",cache)
                var distance=Vector2(source[0]-target[0],source[1]-target[1]).length()*float(config.TILE_W)
                var travel=maxf(projectile.get("minimumTravelDurationMs",150),distance/maxf(1,projectile.get("speedPxPerSecond",800))*1000)
                Components.projectile(group,node,recipe,contact,travel,source,target,graph.contacts,cache)
                contact+=travel
        var has_applications=false
        for child in children:
            if child.get("fact")!=null and child.fact.kind=="spell" and child.fact.get("application")!=null: has_applications=true
        for child in children: finish=maxf(finish,_schedule(child,owner.start if has_applications else contact,state,group,graph,cache))
        finish=maxf(finish,contact)
    elif kind == "damage" and fact.stage == "applied" and not node.canceled:
        var actor = _actor(state,group,fact.target_entity_uuid,node,graph)
        var timing=DamageTiming.resolve(node,graph,actor,start,cache)
        graph.damage_timings[node.uuid]=timing
        start=timing.start
        graph.starts[node.uuid]=start
        finish=maxf(start,timing.hp)
        var body:Dictionary=timing.body
        if timing.body_enabled:
            var track = _track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,30,cache)
            if not track.is_empty():
                _held_contact(track,fact.target_entity_uuid,graph)
                Tracks.body_keys(track,body,Authoring.clip(actor,body.actor.clip,cache))
                finish = maxf(finish,start + track.duration_ms)
        for child in children: finish = maxf(finish,_schedule(child,timing.hp,state,group,graph,cache))
    elif kind == "life" and not node.canceled:
        start=DamageTiming.life_time(node,graph,start)
        graph.starts[node.uuid]=start
        finish=start
        var actor = _actor(state,group,fact.entity_uuid,node,graph)
        var body = Authoring.body("death" if fact.new_state == "dead" else "life",actor,fact,cache)
        if not body.is_empty() and body.actor.enabled:
            var track = _track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,40,cache)
            if not track.is_empty():
                _held_contact(track,fact.entity_uuid,graph)
                Tracks.body_keys(track,body,Authoring.clip(actor,body.actor.clip,cache))
                track.holding_pose = fact.new_state != "alive"
                var previous_pose:Dictionary=Authoring.load_data("catalog/life_state_context.json",cache).bodyPoses.get(fact.previous_state,{})
                if fact.new_state=="dead" and previous_pose.get("bodyPose")==track.clip:
                    # Dying/Stable already owns this terminal pose. Death does
                    # not replay a fresh fall from a standing source frame.
                    track.source_start_seconds=track.source_end_seconds
                    track.erase("source_time_keys")
                    track.duration_ms=0.0
                finish = start + track.duration_ms
        for child in children: finish = maxf(finish,_schedule(child,start,state,group,graph,cache))
    else:
        for child in children: finish = maxf(finish,_schedule(child,start,state,group,graph,cache,jump))
        group.skipped.append({"occurrence":node.lineage_uuid,"kind":kind,"reason":"canceled_body" if node.canceled else "no_body_visual_in_this_pass"})
    # HP/life after-values are exposed at their effect contact, not recovery end.
    graph.times[node.uuid] = equipment_commit if kind=="equipment" else (graph.damage_timings[node.uuid].hp if graph.damage_timings.has(node.uuid) else (start if kind in ["damage","life","condition"] else finish))
    graph.ends[node.uuid] = finish
    return finish

static func compile(before: Dictionary, packet: Dictionary, cache: Dictionary) -> Dictionary:
    var recorded = Reducer._reduce_operation_recorded(before,packet)
    if not recorded.ok: return recorded
    return compile_recorded(before,packet,cache,recorded.value,recorded.transitions)

static func compile_admitted(before: Dictionary, packet: Dictionary, cache: Dictionary, final_state: Dictionary) -> Dictionary:
    # Compatibility for callers retaining only an admitted final state. Live
    # sessions hand off captures directly to compile_recorded instead.
    var recorded = Reducer._reduce_operation_recorded(before,packet)
    if not recorded.ok: return recorded
    return compile_recorded(before,packet,cache,final_state,recorded.transitions)

static func compile_recorded(before: Dictionary, packet: Dictionary, cache: Dictionary,
        final_state: Dictionary, transitions: Dictionary) -> Dictionary:
    var authoring_errors = Authoring.Catalog.validate_native(cache)
    if not authoring_errors.is_empty():
        return Reducer.failure("Invalid native presentation authoring: "+"; ".join(authoring_errors))
    # Private records belong to this exact admitted operation. Applying their
    # immutable after-values advances a local presentation view without folding
    # observations, world updates or sensory facts for a second time.
    if transitions.get("lineages",[]).size()!=packet.lineages.size():
        return Reducer.failure("Recorded transition lineage count differs from operation")
    var target = before.duplicate()
    for field in ["actors","tiles","objects","spatial_commit_cursors","combat_log_appends"]:
        target[field] = before[field].duplicate()
    var groups: Array = []
    for lineage_index in packet.lineages.size():
        var lineage: Dictionary = packet.lineages[lineage_index]
        var recorded: Dictionary = transitions.lineages[lineage_index]
        for field in ["lineage_uuid","start_cursor","end_cursor"]:
            if recorded.get(field)!=lineage[field]:
                return Reducer.failure("Recorded transition identity differs from lineage")
        if lineage.start_cursor!=target.reducer_cursor:
            return Reducer.failure("Recorded transition lineage does not follow presentation state")
        if recorded.get("events",[]).size()!=lineage.events.size():
            return Reducer.failure("Recorded transition event count differs from lineage")
        var group = {"id":lineage.lineage_uuid,"start_cursor":lineage.start_cursor,"end_cursor":lineage.end_cursor,
            "operation_sequence":packet.get("cursor",{}).get("sequence",-1),"operation_end":false,
            "duration_ms":0.0,"actor_tracks":[],"components":[],"commits":[],"staged_actors":{},"staged_at_ms":{},"staged_tiles":{},"staged_tile_at_ms":{},"skipped":[]}
        for observation in lineage.observations:
            if not target.actors.has(observation.actor.uuid) and not group.staged_actors.has(observation.actor.uuid):
                group.staged_actors[observation.actor.uuid] = observation.actor.duplicate(true)
        for update in lineage.world_updates:
            for tile in update.tiles:
                var key = Reducer.Audience.point_key(tile.position)
                if not target.tiles.has(key) and not group.staged_tiles.has(key): group.staged_tiles[key] = tile.duplicate(true)
        var graph = {"nodes":{},"first":{},"times":{},"starts":{},"ends":{},"recipes":{},"visited":{},"positions":{},"actor_inputs":{},"object_inputs":{},"contacts":{},"impact_contacts":{},"last_motion":{},"casts":{},"damage_timings":{}}
        # Retain only authoritative blood receiving cells needed to reveal a
        # later residue increment. No future tile or full-map snapshot is made.
        graph.initial_tiles={}
        for event in lineage.events:
            var release: Variant=event.get("fact",{}).get("body_release") if event.get("fact")!=null else null
            if release==null or release.get("release_id")!="body.blood":continue
            for region in release.get("regions",[]):
                for point in region.positions:
                    var key=Reducer.Audience.point_key(point)
                    graph.initial_tiles[key]=target.tiles.get(key,{})
        for actor in target.actors.values() + group.staged_actors.values():
            graph.positions[actor.uuid] = actor.last_visual_position.duplicate() if actor.last_visual_position != null else null
            if actor.last_visual_position != null:
                var tile: Dictionary = target.tiles.get(Reducer.Audience.point_key(actor.last_visual_position),group.staged_tiles.get(Reducer.Audience.point_key(actor.last_visual_position),{}))
                graph.contacts[actor.uuid] = {"from_elevation_feet":tile.get("elevation_steps",0)*5.0,
                    "to_elevation_feet":tile.get("elevation_steps",0)*5.0}
        var cursors = {}
        for row in lineage.version_rows:
            cursors[row.event_uuid] = row.source_index
            graph.first[row.lineage_uuid] = mini(graph.first.get(row.lineage_uuid,row.source_index),row.source_index)
        for node in lineage.events: graph.nodes[node.lineage_uuid] = node
        for event_index in lineage.events.size():
            var node: Dictionary = lineage.events[event_index]
            var captured: Dictionary = recorded.events[event_index]
            if captured.event_uuid!=node.uuid or captured.source_index!=cursors[node.uuid]:
                return Reducer.failure("Recorded transition identity differs from event")
            graph.actor_inputs[node.uuid] = captured.actor_inputs
            if node.fact!=null and node.fact.kind=="object_damage":
                graph.object_inputs[node.uuid]=target.objects.get(node.fact.object_uuid,{})
            apply_delta(target,captured.delta)
            group.commits.append({"at_ms":0.0,"source_index":captured.source_index,"event_uuid":node.uuid,
                "delta":captured.delta})
        var trailing: Dictionary = recorded.trailing
        if trailing.set.get("reducer_cursor")!=lineage.end_cursor:
            return Reducer.failure("Recorded trailing cursor differs from lineage")
        apply_delta(target,trailing)
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
        Components.compile(group,lineage,graph,cache)
        group.events = EventTrace.compile_rows(lineage,group,graph,cache)
        groups.append(group)
    if target.reducer_cursor!=final_state.reducer_cursor:
        return Reducer.failure("Recorded transitions do not reach the admitted final cursor")
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
