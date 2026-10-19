extends RefCounted
const Appearance=preload("res://presentation/condition_appearance.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
## Passive presentation of admitted occurrences. The SDK reducer owns truth.
const Tracks = preload("res://presentation/tracks.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Transitions = preload("res://sdk/transitions.gd")
const Authoring = preload("res://presentation/authoring.gd")
const EventTrace = preload("res://presentation/event_trace.gd")
const Components = preload("res://presentation/components.gd")
const SpellDelivery=preload("res://presentation/spell_delivery.gd")
const DamageTiming = preload("res://presentation/damage_timing.gd")
const Conditions = preload("res://presentation/conditions.gd")
const ActorConstruction = preload("res://presentation/actor_construction.gd")
const WorldRows = preload("res://presentation/world.gd")

static func empty_delta() -> Dictionary:
    return Transitions.empty_delta()

static func apply_delta(target: Dictionary, delta: Dictionary) -> void:
    for key in delta.get("set", {}): target[key] = delta.set[key]
    # Each operation publishes only its new log rows. Replaying another
    # timeline must not mutate the retained delta or repeat previous history.
    if delta.has("log_appends"):
        target.combat_log_appends.append_array(delta.log_appends)
    for key in delta.get("objects_removed", []): target.objects.erase(key)
    for key in delta.get("tiles_removed", []): target.tiles.erase(key)
    for field in ["actors", "items", "tiles", "objects", "spatial_commit_cursors"]:
        var values:Dictionary=delta.get(field,{})
        if not values.is_empty():target[field].merge(values,true)

static func _actor(state: Dictionary, group: Dictionary, identity: Variant, node: Dictionary, graph: Dictionary) -> Dictionary:
    var observed: Dictionary = graph.actor_inputs.get(node.id,{})
    if observed.has(identity): return observed[identity]
    if state.actors.has(identity): return state.actors[identity]
    return group.staged_actors.get(identity, {})

static func _spell_actor_inputs(node:Dictionary,captured:Dictionary,state:Dictionary,graph:Dictionary)->Dictionary:
    if node.get("fact")==null or node.fact.kind!="spell":return captured
    var source:Variant=Occurrences.spell(node,graph).get("source_entity_uuid")
    if source==null or captured.has(source) or not state.actors.has(source):return captured
    # A sparse native application inherits its source from the cast. Borrow
    # only that actor at this pre-row cut, never the final operation state or
    # the mutable future choreography position table.
    var result:Dictionary=captured.duplicate()
    result[source]=state.actors[source]
    return result

static func _track(group: Dictionary, node: Dictionary, actor: Dictionary, clip_name: String,
        start: float, speed: float, priority: int, cache: Dictionary, graph:Dictionary) -> Dictionary:
    var clip = Authoring.clip(actor, clip_name, cache)
    if clip.is_empty():
        group.skipped.append({"occurrence":node.lineage_id,"kind":node.fact.kind,"reason":"missing_authored_clip","clip":clip_name})
        return {}
    var row = Tracks.body(actor.uuid,Authoring.rig_id(actor,cache),clip_name,clip,speed,priority)
    row.merge({"trace_track_id":"%s:%s:%s" % [group.operation_sequence,node.id,group.actor_tracks.size()],
        "occurrence":node.lineage_id,"source_event_uuid":node.id,"source_lineage":node.lineage_id,"start_ms":start},true)
    row.activity={"attack":"attack","spell":"cast","action":"act","shove":"act","condition":"act","damage":"hit","life":"hit","forced_movement":"forced_move"}.get(node.fact.kind,"idle")
    if node.fact.kind=="step":row.activity="jump" if node.fact.trajectory in ["direct_arc","connector_transfer"] else "move"
    # The source outfit belongs to this occurrence, not its operation endpoints.
    row.presentation_actor = {}
    for field in ["uuid","creature_content_ref","appearance","visual_loadout","last_visual_position","life_state","present","spatial_disposition","remains_disposition"]:
        if actor.has(field): row.presentation_actor[field] = actor[field]
    row.presentation_item_looks=Authoring.Characters.item_looks(row.presentation_actor,{"items":graph.item_inputs.get(node.id,{})})
    group.actor_tracks.append(row)
    return row

static func _held_contact(track: Dictionary, identity: String, graph: Dictionary) -> void:
    if track.is_empty(): return
    var contact: Dictionary = graph.contacts.get(identity,{})
    track.merge(contact,true)
    var point: Variant = graph.positions.get(identity)
    track.from_position = point
    track.to_position = point

static func _cast_track(group:Dictionary,node:Dictionary,actor:Dictionary,recipe:Dictionary,spell_id:String,
        start:float,aim:Variant,graph:Dictionary,cache:Dictionary,release_ms:float=INF)->Dictionary:
    var cast:Dictionary=recipe.get("cast",{})
    if actor.is_empty() or cast.is_empty() or not cast.get("enabled",true):return {}
    var rate:float=cast.get("bodyPlaybackSpeed",1.0)*Authoring.playback_rate(actor,cache)
    var clip:Dictionary=Authoring.clip(actor,cast.actionClip,cache)
    if clip.is_empty() or rate<=0:return _track(group,node,actor,cast.actionClip,start,rate,20,cache,graph) if rate>0 else {}
    var release_source:float=float(cast.get("releaseFrame",0))/clip.fps
    var source_start:float=0.0
    if is_finite(release_ms):
        # A reaction cannot move its authoritative application. Fit its windup
        # before that existing commit, cropping only at this group's boundary.
        start=maxf(0.0,release_ms-release_source*1000.0/rate)
        source_start=maxf(0.0,release_source-(release_ms-start)*rate/1000.0)
    var track=_track(group,node,actor,cast.actionClip,start,rate,20,cache,graph)
    if track.is_empty():return track
    _held_contact(track,actor.uuid,graph)
    track.activity="cast";track.target_position=aim
    track.hidden_slots=["weapon","offhand"] if cast.get("equipment",{}).get("kind")=="hidden" else []
    track.effect_layers=Components.cast_layers(cast,actor,cache)
    track.source_start_seconds=source_start
    track.duration_ms=(track.source_end_seconds-source_start)*1000.0/rate
    track.contact_ms=release_ms if is_finite(release_ms) else start+release_source*1000.0/rate
    track.cast_source="spells/"+spell_id+".json:/cast"
    return track

static func _reaction_casts(lineage:Dictionary,state:Dictionary,group:Dictionary,graph:Dictionary,cache:Dictionary)->void:
    var commits:Dictionary={}
    for commit in group.commits:commits[commit.event_uuid]=commit.at_ms
    for node in lineage.events:
        if node.canceled:continue
        for cue in graph.condition_cues.get(node.id,[]):
            var recipe:Dictionary=cue.recipe
            var binding:String=recipe.get("reactionCastBinding","")
            if cue.phase!="application" or binding.is_empty():continue
            var actor=_actor(state,group,cue.actor_uuid,node,graph)
            if actor.get("last_visual_position")==null:continue
            var aim:Variant=null
            var ancestor:Dictionary=graph.nodes.get(node.get("parent_lineage"),{})
            var declared:bool=false
            while not ancestor.is_empty():
                var cause:Variant=Occurrences.spell(ancestor,graph) if ancestor.get("fact")!=null and ancestor.fact.kind=="spell" else ancestor.get("fact")
                if cause!=null and cause.get("kind")=="spell" and cause.get("behavior_id")==binding and cause.get("source_entity_uuid")==actor.uuid:declared=true;break
                if cause!=null and cause.get("source_entity_uuid")!=null and cause.source_entity_uuid!=actor.uuid:
                    var threat=_actor(state,group,cause.source_entity_uuid,ancestor,graph)
                    aim=cause.get("source_position",threat.get("last_visual_position"))
                    if aim!=null:break
                ancestor=graph.nodes.get(ancestor.get("parent_lineage"),{})
            if declared:continue
            var cast_recipe:Dictionary=_spell_sources(binding,graph,cache).recipe
            var track=_cast_track(group,node,actor,cast_recipe,binding,0.0,aim,graph,cache,float(commits[node.id]))
            if track.is_empty():continue
            var held:Dictionary=cue.get("reaction_contact",{})
            track.merge(held.get("contact",{}),true)
            track.from_position=held.get("position",actor.last_visual_position);track.to_position=track.from_position
            track.reaction_cast_binding=binding;track.condition_uuid=cue.condition.condition_uuid
            track.source=Authoring.Catalog.source_pointer("catalog/condition_recipes.json",str(cue.condition.behavior_id)+"/reactionCastBinding",cache)
            graph.ends[node.id]=maxf(graph.ends.get(node.id,0.0),track.start_ms+track.duration_ms)
            group.duration_ms=maxf(group.duration_ms,track.start_ms+track.duration_ms)

static func _spell_sources(behavior: String, graph: Dictionary, cache: Dictionary) -> Dictionary:
    # Both selectors consume only the behavior and immutable authored documents.
    # Applications retain their own timing/delivery below; share no runtime state.
    if not graph.spell_sources.has(behavior):
        graph.spell_sources[behavior] = {"recipe":Components.NativeSpells.recipe({"behavior_id":behavior},cache),
            "selection":Components.NativeSpells.selection(behavior,cache)}
    return graph.spell_sources[behavior]

static func _children(node: Dictionary, graph: Dictionary) -> Array:
    var rows: Array = []
    for identity in node.children_lineages:
        if graph.nodes.has(identity): rows.append(graph.nodes[identity])
    return rows

static func _schedule(node: Dictionary, start: float, state: Dictionary, group: Dictionary,
        graph: Dictionary, cache: Dictionary, jump: Dictionary = {}) -> float:
    if graph.visited.has(node.lineage_id): return start
    graph.visited[node.lineage_id] = true
    graph.starts[node.id] = start
    var fact: Variant = Occurrences.spell(node,graph) if node.fact!=null and node.fact.kind=="spell" else node.fact
    if fact!=null and fact.kind=="damage":
        graph.impact_contacts[node.id]=graph.contacts.get(fact.target_entity_uuid,{}).duplicate()
    var children = _children(node,graph)
    var finish = start
    var effect_commit = INF
    var equipment_commit = start
    var kind: String = fact.kind if fact != null else "undisclosed"
    if kind == "movement":
        if node.canceled: group.skipped.append({"occurrence":node.lineage_id,"kind":kind,"reason":"canceled_body"})
        var context = {"occurrence":node.lineage_id}
        if fact.trajectory == "direct_arc" and not fact.path.is_empty():
            var motion = Authoring.load_data("catalog/movement_context.json",cache)
            context = Tracks.jump_context(fact.path,motion,node.lineage_id)
        for child in children: finish = _schedule(child,finish,state,group,graph,cache,context)
    elif kind == "step":
        if fact.trajectory=="connector_transfer":
            fact=fact.duplicate()
            for connector in state.get("connectors",{}).values():
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
            var held = _track(group,node,actor,previous.get("clip","Idle"),start,1.0,5,cache,graph)
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
            var track = _track(group,node,actor,body.actor.clip,finish,rate,10,cache,graph)
            if not track.is_empty():
                if fact.trajectory=="direct_arc" and not jump.has("path"):
                    group.skipped.append({"occurrence":node.lineage_id,"kind":kind,"reason":"undisclosed_jump_arc_uses_disclosed_edge_only"})
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
                group.skipped.append({"occurrence":node.lineage_id,"kind":kind,"reason":"motion_trajectory_out_of_pass","trajectory":fact.trajectory})
        for child in children:
            if not graph.visited.has(child.lineage_id): end_motion = maxf(end_motion,_schedule(child,end_motion,state,group,graph,cache))
        finish = end_motion
    elif kind == "attack" and not node.canceled:
        var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
        var recipe = Authoring.attack(fact,actor,cache)
        graph.recipes[node.id] = recipe
        var contact = start
        if not recipe.is_empty() and recipe.actor.enabled:
            var speed = recipe.actor.playbackSpeed * Authoring.playback_rate(actor,cache)
            var track = _track(group,node,actor,recipe.actor.clip,start,speed,20,cache,graph)
            if not track.is_empty():
                _held_contact(track,fact.source_entity_uuid,graph)
                track.target_uuid = fact.target_entity_uuid
                var target = _actor(state,group,fact.target_entity_uuid,node,graph)
                track.target_position = fact.target_position if fact.get("target_position") != null else graph.positions.get(fact.target_entity_uuid,target.get("last_visual_position"))
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
        else: group.skipped.append({"occurrence":node.lineage_id,"kind":kind,"reason":"missing_authored_attack_recipe"})
        for child in children: finish = maxf(finish,_schedule(child,contact,state,group,graph,cache))
        effect_commit=contact
    elif kind in ["action","shove"] and not node.canceled:
        var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
        var recipe = Authoring.action(fact,cache,actor)
        graph.recipes[node.id] = recipe
        var contact = start
        if recipe.get("actor",{}).get("enabled",false):
            var rate = recipe.actor.playbackSpeed*Authoring.playback_rate(actor,cache)
            var track = _track(group,node,actor,recipe.actor.clip,start,rate,20,cache,graph)
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
        effect_commit=contact
    elif kind == "equipment" and not node.canceled:
        var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
        var body = Authoring.body("equipment",actor,fact,cache)
        graph.recipes[node.id] = body
        if body.get("actor",{}).get("enabled",false):
            var clip = Authoring.clip(actor,body.actor.clip,cache)
            var track = _track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,20,cache,graph)
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
            var track = _track(group,node,actor,profile.target_clip,start,profile.playback_speed,25,cache,graph)
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
    elif kind == "actor_change" and not node.canceled:
        var changed:Dictionary={}
        for change in fact.get("actors",[]):
            if not change.get("rows",[]).any(func(row):return row.get("field") in ["layer","active_weapon_set"]):continue
            if changed.has(change.actor_uuid):continue
            changed[change.actor_uuid]=true
            var actor=_actor(state,group,change.actor_uuid,node,graph)
            var body:Dictionary=Authoring.body("equipment",actor,{},cache)
            if not body.get("actor",{}).get("enabled",false):continue
            var clip:Dictionary=Authoring.clip(actor,body.actor.clip,cache)
            var track=_track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,20,cache,graph)
            if track.is_empty():continue
            _held_contact(track,actor.uuid,graph)
            Tracks.body_keys(track,body,clip)
            track.activity="act";track.source=body.source;track.equipment_change=true
            finish=maxf(finish,start+track.duration_ms)
            for anchor in body.get("anchors",[]):
                if anchor.name=="commit":
                    var frame:float=float(clip.frames)-1-float(anchor.frame) if body.get("reversed",false) else float(anchor.frame)
                    equipment_commit=maxf(equipment_commit,start+minf(track.duration_ms,frame*1000.0/clip.fps/body.actor.playbackSpeed))
            track.commit_ms=equipment_commit
        for cue in graph.condition_cues.get(node.id,[]):
            var actor=_actor(state,group,cue.actor_uuid,node,graph)
            var recipe:Dictionary=cue.recipe
            if cue.phase=="application" and recipe.get("reactionCastBinding")!=null:
                cue.reaction_contact={"position":graph.positions.get(cue.actor_uuid),"contact":graph.contacts.get(cue.actor_uuid,{}).duplicate()}
            var body:Dictionary=recipe.get(cue.phase,{}).get("bodyAnimation",{})
            if not body.is_empty():
                var track=_track(group,node,actor,body.bodyClip,start,body.get("bodyPlaybackSpeed",1.0),35,cache,graph)
                if not track.is_empty():
                    _held_contact(track,cue.actor_uuid,graph)
                    Tracks.body_keys(track,{"actor":{"hiddenSlots":[]},"reversed":body.get("reversed",false)},Authoring.clip(actor,body.bodyClip,cache))
                    track.holding_pose=false;track.condition_uuid=cue.condition.condition_uuid
                    finish=maxf(finish,start+track.duration_ms)
        for child in children:finish=maxf(finish,_schedule(child,start,state,group,graph,cache))
    elif kind == "spell" and not node.canceled:
        var actor = _actor(state,group,fact.source_entity_uuid,node,graph)
        var sources = _spell_sources(str(fact.behavior_id),graph,cache)
        var recipe: Dictionary = sources.recipe
        graph.recipes[node.id]=recipe
        var cast: Dictionary=recipe.get("cast",{})
        var application: bool=Occurrences.application(node)
        var cast_key: String=SpellDelivery.cast_key(node,graph)
        var contact=start
        if not graph.casts.has(cast_key) and not cast.is_empty() and cast.get("enabled",true):
            var rate=cast.get("bodyPlaybackSpeed",1.0)*Authoring.playback_rate(actor,cache)
            var track=_cast_track(group,node,actor,recipe,str(fact.behavior_id),start,SpellDelivery.aim_position(fact,graph),graph,cache)
            if not track.is_empty():
                contact=track.contact_ms
                finish=start+track.duration_ms
            var preparation=start+float(cast.get("prepareFrame",recipe.get("projectile",{}).get("prepare",{}).get("startFrame",0)))/maxf(1.0,Authoring.clip(actor,cast.actionClip,cache).get("fps",12))*1000.0/rate
            graph.casts[cast_key]={"start":start,"prepare":preparation,"release":contact,"finish":finish,"recipe":recipe,"source_event_uuid":node.id}
        var owner: Dictionary=graph.casts.get(cast_key,{"release":start,"finish":start,"start":start})
        contact=maxf(start,owner.release)
        var has_applications=false
        for child in children:
            if child.get("fact")!=null and child.fact.kind=="spell" and Occurrences.application(child): has_applications=true
        var selected:Dictionary=sources.selection
        var selected_delivery:Dictionary={}
        if not selected.is_empty():selected_delivery=SpellDelivery.for_occurrence(SpellDelivery.selected_for(selected,fact),node,has_applications)
        var shared_area:bool=not selected_delivery.is_empty() and selected_delivery.get("delivery",{}).get("scope")=="area"
        if not selected_delivery.is_empty():
            if SpellDelivery.owns_delivery(node,graph,selected_delivery,has_applications):
                var points=SpellDelivery.endpoints(fact,graph,state,selected_delivery)
                if not points.is_empty():
                    if application:contact+=float(Occurrences.application_index(node,graph))*recipe.get("projectile",{}).get("missileStaggerMs",0)
                    var travel=SpellDelivery.travel_ms(selected_delivery,recipe,points,cache)
                    Components.native_spell(group,node,recipe,selected_delivery,contact,travel,points,cache,owner,fact,Occurrences.application_index(node,graph),graph)
                    contact+=travel
            elif shared_area:
                # The carrier already scheduled the single ground effect. Every
                # recipient applies its actual outcome at that carrier contact.
                contact=start
        elif application or not has_applications:
            if application:contact+=float(Occurrences.application_index(node,graph))*recipe.get("projectile",{}).get("missileStaggerMs",0)
            var projectile: Dictionary=recipe.get("projectile",{})
            var source: Variant=graph.positions.get(fact.source_entity_uuid)
            var target: Variant=graph.positions.get(fact.get("target_entity_uuid"))
            if not projectile.is_empty() and source!=null and target!=null:
                var config=Authoring.load_data("catalog/rig.json",cache)
                var distance=Vector2(source[0]-target[0],source[1]-target[1]).length()*float(config.TILE_W)
                var travel=maxf(projectile.get("minimumTravelDurationMs",150),distance/maxf(1,projectile.get("speedPxPerSecond",800))*1000)
                Components.projectile(group,node,recipe,contact,travel,source,target,graph.contacts,cache,owner,fact,Occurrences.application_index(node,graph))
                contact+=travel
        for child in children: finish=maxf(finish,_schedule(child,owner.start if has_applications and not shared_area else contact,state,group,graph,cache))
        finish=maxf(finish,contact)
        effect_commit=contact
    elif kind == "damage" and fact.stage == "applied" and not node.canceled:
        var actor = _actor(state,group,fact.target_entity_uuid,node,graph)
        var timing=DamageTiming.resolve(node,graph,actor,start,cache)
        graph.damage_timings[node.id]=timing
        start=timing.start
        graph.starts[node.id]=start
        finish=maxf(start,timing.hp)
        var body:Dictionary=timing.body
        if timing.body_enabled:
            var track = _track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,30,cache,graph)
            if not track.is_empty():
                _held_contact(track,fact.target_entity_uuid,graph)
                Tracks.body_keys(track,body,Authoring.clip(actor,body.actor.clip,cache))
                finish = maxf(finish,start + track.duration_ms)
        for child in children: finish = maxf(finish,_schedule(child,timing.hp,state,group,graph,cache))
    elif kind == "life" and not node.canceled:
        start=DamageTiming.life_time(node,graph,start)
        graph.starts[node.id]=start
        finish=start
        var actor = _actor(state,group,fact.entity_uuid,node,graph)
        var body = Authoring.body("death" if fact.new_state == "dead" else "life",actor,fact,cache)
        if not body.is_empty() and body.actor.enabled:
            var track = _track(group,node,actor,body.actor.clip,start,body.actor.playbackSpeed,40,cache,graph)
            if not track.is_empty():
                _held_contact(track,fact.entity_uuid,graph)
                Tracks.body_keys(track,body,Authoring.clip(actor,body.actor.clip,cache))
                track.holding_pose = fact.new_state != "alive"
                if fact.new_state!="alive" and fact.previous_state in ["dying","stable","dead"]:
                    # An already downed body stays down through stabilization
                    # and death. Only a real recovery permits another fall.
                    # The new state may select another rig-specific rest clip;
                    # sample its endpoint without replaying its standing entry.
                    track.source_start_seconds=track.source_end_seconds
                    track.erase("source_time_keys")
                    track.duration_ms=0.0
                finish = start + track.duration_ms
        for child in children: finish = maxf(finish,_schedule(child,start,state,group,graph,cache))
    else:
        for child in children: finish = maxf(finish,_schedule(child,start,state,group,graph,cache,jump))
        effect_commit=start
        group.skipped.append({"occurrence":node.lineage_id,"kind":kind,"reason":"canceled_body" if node.canceled else "no_body_visual_in_this_pass"})
    # Application/passive envelopes complete after their children's effects,
    # not their recovery animations. The source-order commit pass below must
    # not make one missile's TakeDamage recovery delay the next missile's HP.
    if is_finite(effect_commit):
        for child in children:effect_commit=maxf(effect_commit,graph.times.get(child.id,start))
    else:effect_commit=finish
    # HP/life after-values are exposed at their effect contact, not recovery end.
    graph.times[node.id] = equipment_commit if kind in ["equipment","actor_change"] else (graph.damage_timings[node.id].hp if graph.damage_timings.has(node.id) else (start if kind in ["damage","life","actor_change"] else effect_commit))
    graph.ends[node.id] = finish
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

static func _native_requirements(before: Dictionary, groups: Array, cache: Dictionary) -> void:
    # Commit clocks are known only after scheduling. Project persistent owners
    # once on this compiler worker; never replay these commits during readiness.
    var owners: Dictionary = {}; var areas: Dictionary = {}
    Conditions.observe(owners,before.actors,0.0,true)
    var condition_inputs:Dictionary={}
    for id in before.actors:
        condition_inputs[id]=[before.actors[id].get("conditions",[]),before.actors[id].get("life_state","alive")]
    var spatial_inputs:Dictionary={} if before.senses==null else before.senses.get("spatial_effects",{})
    if before.senses!=null:
        Conditions.NativePersistent.observe_spatial(areas,before.senses.get("spatial_effects",{}),0.0,true)
    var start = 0.0
    for group in groups:
        group.native_requirements = []
        var previous: Dictionary = {}
        _native_requirement_cut(group,previous,owners,areas,start,0.0,cache)
        var sampled_at:float=start
        for commit in group.get("commits",[]):
            var delta: Dictionary = commit.delta
            if delta.get("actors",{}).is_empty() and not delta.get("set",{}).has("senses"): continue
            var at: float = start+commit.at_ms
            var changed:bool=false
            for id in delta.get("actors",{}):
                var actor:Dictionary=delta.actors[id]
                var selected:Array=[actor.get("conditions",[]),actor.get("life_state","alive")]
                changed=changed or condition_inputs.get(id,[])!=selected
                condition_inputs[id]=selected
            changed=Conditions.observe(owners,delta.get("actors",{}),at,false,commit.get("condition_rows",[])) or changed
            if delta.get("set",{}).has("senses"):
                var spatial:Dictionary=delta.set.senses.get("spatial_effects",{}) if delta.set.senses!=null else {}
                Conditions.NativePersistent.observe_spatial(areas,spatial,at)
                changed=changed or spatial_inputs!=spatial
                spatial_inputs=spatial
            # Several HP/position after-values can share one effect contact.
            # They change no persistent constructor operand. Keep all distinct
            # clocks and real condition/life/spatial changes, in source order.
            if not changed and at==sampled_at:continue
            _native_requirement_cut(group,previous,owners,areas,at,commit.at_ms,cache)
            sampled_at=at
        start += float(group.duration_ms)

static func _native_requirement_cut(group: Dictionary, previous: Dictionary, owners: Dictionary,
        areas: Dictionary, at_ms: float, local_ms: float, cache: Dictionary) -> void:
    var samples: Array = Conditions.samples(owners,at_ms,cache,{},false)
    samples.append_array(Conditions.NativePersistent.spatial_samples(areas,at_ms,cache))
    var outlined:Dictionary={}
    var actor_ids:Dictionary={}
    for sample in samples:
        if sample.kind=="condition":actor_ids[sample.actor_uuid]=true
    for actor_id in actor_ids:
        for selected in Conditions.select_recipes(actor_id,samples):
            if selected.recipe.get("persistent",{}).has("bodyOutline"):outlined[selected.condition_uuid]=true
    for sample in samples:
        # Only constructor/source/shape operands cross this boundary. Runtime
        # owner age, removal, initial state and material sampling stay private.
        var row: Dictionary = sample.duplicate()
        if row.kind=="condition":
            if not outlined.has(row.condition_uuid):continue
            row={"id":str(row.id)+":outline","kind":"condition_outline","actor_uuid":row.actor_uuid,
                "condition_uuid":row.condition_uuid,"status":"available"}
        elif row.kind not in ["native_effect","audio"]:continue
        var runtime_fields:Array=["age_ms","initial","removal_age_ms","alpha","source_age_ms","selection_alpha","condition","recipe"]
        if row.kind!="audio":runtime_fields.append_array(["start_ms","absolute_start_ms","duration_ms"])
        for field in runtime_fields:
            row.erase(field)
        if sample.has("native_cue"):
            row.native_cue = sample.native_cue.duplicate()
            row.native_cue.erase("initial"); row.native_cue.erase("owner_end_seconds")
        if previous.get(row.id,{}) == row: continue
        previous[row.id] = row
        var requirement = row.duplicate()
        requirement.preparation_at_ms = local_ms
        requirement.preparation_key = str(group.id)+":native_requirement:"+str(group.native_requirements.size())
        group.native_requirements.append(requirement)

static func _actor_cut(cuts:Dictionary,at:float,id:String,duration:float)->void:
    if at<0.0 or at>duration:return
    if not cuts.has(at):cuts[at]={}
    cuts[at][id]=true

static func _actor_structure_inputs(actor:Dictionary,state:Dictionary,staged:bool,loadouts:Dictionary)->Array:
    if actor.is_empty() or not WorldRows.visible_actor(actor,state,staged):return []
    var selected=ActorConstruction.actor_with_loadout(actor,loadouts)
    return [selected.get("creature_content_ref"),selected.appearance,selected.visual_loadout,selected.get("presentation_layers",[]),Authoring.Characters.item_looks(selected,state)]

static func _actor_structure_value(actor:Dictionary,loadouts:Dictionary,inputs:Array,cache:Dictionary)->Dictionary:
    if inputs.is_empty():return {}
    if Authoring.Characters.effect_owned(actor,cache):return {}
    var selected=Authoring.Characters.structure(ActorConstruction.actor_with_loadout(actor,loadouts),cache,inputs[4])
    return selected.value if selected.ok else {"error":selected.error}

## Only effect layers (spell overlays) differ. A live host builds those layers
## while sampling (play.gd _reconcile_actor_layers): no world preparation.
static func _effect_only_change(before:Dictionary,after:Dictionary)->bool:
    if before.is_empty() or after.is_empty() or before.has("error") or after.has("error"):return false
    if before.rig!=after.rig or before.appearance!=after.appearance:return false
    var base:=func(layer):return layer.get("effect",{}).is_empty() or layer.get("effect",{}).get("kind")=="condition_appearance"
    return before.equipment_layers.filter(base)==after.equipment_layers.filter(base)

static func _actor_source_clip(actor:Dictionary,structure:Dictionary,sample:Dictionary,cache:Dictionary)->String:
    if structure.is_empty() or structure.has("error"):return ""
    if not sample.is_empty():return sample.clip
    var rig:Dictionary=Authoring.rigs(cache)[structure.rig]
    var pose:Dictionary=Conditions.pose(actor,structure.rig,cache)
    if not pose.is_empty() and rig.clips.has(pose.clip):return pose.clip
    var resting:Dictionary=Authoring.Characters.rest_sample(actor,rig,cache)
    return resting.value.clip if resting.ok else ""

static func _actor_structure_requirements(before:Dictionary,groups:Array,cache:Dictionary)->void:
    # Sparse after-value overlay: the admitted base stays read-only. Inspect only
    # touched actors and authored selector edges, never all actors at every cut.
    var actors:Dictionary={}
    var state={"senses":before.senses,"audience":before.audience,"items":before.items.duplicate()}
    var retained:Array=[]
    var appearance_owners:Dictionary={}
    Conditions.observe(appearance_owners,before.actors,0.0,true)
    var start=0.0
    for group in groups:
        var duration:float=group.duration_ms
        var cuts:Dictionary={};var affected:Dictionary={}
        for track in group.get("actor_tracks",[]):
            _actor_cut(cuts,track.start_ms,track.actor_uuid,duration)
            _actor_cut(cuts,track.start_ms+track.duration_ms,track.actor_uuid,duration)
            _actor_cut(cuts,duration,track.actor_uuid,duration)
        var layers:Array=retained.duplicate()
        for component in group.get("components",[]):
            if component.kind!="sprite_layer":continue
            layers.append({"component":component,"start_ms":start+component.start_ms})
        for item in layers:
            _actor_cut(cuts,item.start_ms-start,item.component.actor_uuid,duration)
            _actor_cut(cuts,item.start_ms+item.component.duration_ms-start,item.component.actor_uuid,duration)
        for id in group.get("staged_actors",{}):
            _actor_cut(cuts,float(group.get("staged_at_ms",{}).get(id,0.0)),id,duration)
            _actor_cut(cuts,duration,id,duration)
        for owner in appearance_owners.values():
            if not is_inf(owner.end_ms) and not Appearance.declarations(owner.condition,cache).is_empty():
                _actor_cut(cuts,float(owner.end_ms)+Appearance.removal_ms(owner.condition)-start,owner.actor_uuid,duration)
        for commit in group.get("commits",[]):
            for id in commit.delta.get("actors",{}):_actor_cut(cuts,commit.at_ms,id,duration)
            for change in commit.get("condition_rows",[]):
                if change.after==null and change.before!=null and not Appearance.declarations(change.before,cache).is_empty():
                    _actor_cut(cuts,float(commit.at_ms)+Appearance.removal_ms(change.before),change.actor_uuid,duration)
        for ids in cuts.values():affected.merge(ids)
        # Sensory cuts already require world publication. Updating these cached
        # signatures there keeps a later actor-only cut relative to that view.
        for commit in group.get("commits",[]):
            if commit.delta.get("set",{}).has("senses"):
                for id in affected:_actor_cut(cuts,commit.at_ms,id,duration)
        var previous_inputs:Dictionary={};var previous:Dictionary={};var previous_clips:Dictionary={}
        var initial_layers:Array=retained.filter(func(item):return item.start_ms<=start and start<item.start_ms+item.component.duration_ms).map(func(item):return item.component)
        initial_layers.append_array(Appearance.components(appearance_owners,start,cache))
        var initial_loadouts=ActorConstruction.loadouts({},initial_layers)
        for id in affected:
            var actor:Dictionary=actors.get(id,before.actors.get(id,{}))
            previous_inputs[id]=_actor_structure_inputs(actor,state,false,initial_loadouts)
            previous[id]=_actor_structure_value(actor,initial_loadouts,previous_inputs[id],cache)
            previous_clips[id]=_actor_source_clip(actor,previous[id],{},cache)
        var times:Array=cuts.keys();times.sort()
        var boundaries:Dictionary={};var source_boundaries:Dictionary={};var effect_boundaries:Dictionary={};var cursor=0
        for at in times:
            while cursor<group.commits.size() and group.commits[cursor].at_ms<=at:
                var commit:Dictionary=group.commits[cursor]
                for id in commit.delta.get("actors",{}):
                    var actor:Dictionary=commit.delta.actors[id]
                    actors[id]=actor
                Conditions.observe(appearance_owners,commit.delta.get("actors",{}),start+commit.at_ms,false,commit.get("condition_rows",[]))
                for id in commit.delta.get("items",{}):state.items[id]=commit.delta.items[id]
                if commit.delta.get("set",{}).has("senses"):state.senses=commit.delta.set.senses
                cursor+=1
            var active_layers:Array=layers.filter(func(item):return item.start_ms<=start+at and start+at<item.start_ms+item.component.duration_ms).map(func(item):return item.component)
            var samples:Dictionary=Tracks.samples(group.get("actor_tracks",[]),at) if at<duration else {}
            active_layers.append_array(Appearance.components(appearance_owners,start+at,cache))
            var loadouts=ActorConstruction.loadouts(samples,active_layers)
            for id in cuts[at]:
                var staged:bool=at<duration and group.get("staged_actors",{}).has(id) and at>=float(group.get("staged_at_ms",{}).get(id,0.0))
                var actor:Dictionary=actors.get(id,before.actors.get(id,group.get("staged_actors",{}).get(id,{}) if staged else {}))
                var inputs=_actor_structure_inputs(actor,state,staged,loadouts)
                if previous_inputs[id]!=inputs:
                    var value=_actor_structure_value(actor,loadouts,inputs,cache)
                    if previous[id]!=value:
                        if _effect_only_change(previous[id],value):effect_boundaries[float(at)]=true
                        else:boundaries[float(at)]=true
                    previous_inputs[id]=inputs;previous[id]=value
                var clip:String=_actor_source_clip(actor,previous[id],samples.get(id,{}),cache)
                if previous_clips[id]!=clip:source_boundaries[float(at)]=true
                previous_clips[id]=clip
        # Commits with no actor selector edge still carry the next sensory view.
        while cursor<group.commits.size():
            var commit:Dictionary=group.commits[cursor]
            if commit.delta.get("set",{}).has("senses"):state.senses=commit.delta.set.senses
            cursor+=1
        group.actor_structure_times=boundaries.keys();group.actor_structure_times.sort()
        group.actor_source_times=source_boundaries.keys();group.actor_source_times.sort()
        group.actor_effect_times=effect_boundaries.keys();group.actor_effect_times.sort()
        start+=duration
        retained=layers.filter(func(item):return item.start_ms+item.component.duration_ms>start)

static func _profile_phase(phases:Dictionary,name:String,started:int)->int:
    var now:int=Time.get_ticks_usec()
    phases[name]=phases.get(name,0.0)+(now-started)/1000.0
    return now

static func compile_recorded(before: Dictionary, packet: Dictionary, cache: Dictionary,
        final_state: Dictionary, transitions: Dictionary, profile_enabled:bool=false) -> Dictionary:
    # Private records belong to this exact admitted operation. Applying their
    # immutable after-values advances a local presentation view without folding
    # observations, world updates or sensory facts for a second time.
    var compile_phases:Variant={} if profile_enabled else null
    var compile_started:int=Time.get_ticks_usec() if profile_enabled else 0
    var stage_started:int=compile_started
    var target:Dictionary=Reducer._retained_target(before)
    var groups:Array=[]
    if profile_enabled:stage_started=_profile_phase(compile_phases,"input_shell",stage_started)
    for lineage_index in packet.get("lineages",[]).size():
        var native:Dictionary=packet.lineages[lineage_index]
        var lineage:Dictionary=Occurrences.group(native)
        var recorded:Dictionary=transitions.lineages[lineage_index]
        var group={"id":lineage.id,"start_cursor":lineage.start_cursor,"end_cursor":lineage.end_cursor,
            "operation_sequence":packet.get("cursor",{}).get("sequence",-1),"operation_end":false,
            "duration_ms":0.0,"actor_tracks":[],"components":[],"commits":[],"staged_actors":{},"staged_at_ms":{},"staged_tiles":{},"staged_tile_at_ms":{},"skipped":[]}
        for captured in recorded.events:
            for id in captured.delta.get("actors",{}):
                var actor:Dictionary=captured.delta.actors[id]
                if not target.actors.has(id) and (not group.staged_actors.has(id) or group.staged_actors[id].last_visual_position==null):group.staged_actors[id]=actor
            for key in captured.delta.get("tiles",{}):
                if not target.tiles.has(key) and not group.staged_tiles.has(key):group.staged_tiles[key]=captured.delta.tiles[key]
        var graph = {"nodes":{},"first":{},"times":{},"starts":{},"ends":{},"recipes":{},"visited":{},"positions":{},"actor_inputs":{},"item_inputs":{},"object_inputs":{},"contacts":{},"impact_contacts":{},"reaction_contacts":{},"last_motion":{},"casts":{},"damage_timings":{},"spell_sources":{},"spell_facts":{},"application_indices":{},"condition_cues":{}}
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
        graph.version_index=EventTrace._version_index(lineage.version_rows)
        graph.first=graph.version_index.first
        var cursors:Dictionary=graph.version_index.events
        for node in lineage.events:graph.nodes[node.lineage_id]=node
        var applications:Dictionary={}
        graph.application_results=Components.ApplicationResults.index(lineage.events)
        for node in lineage.events:
            var resolution:Dictionary=node.resolution_record
            if resolution.get("application_id")==null:continue
            var owner:String=str(resolution.lineage)
            var identity:String=str(resolution.application_id)
            if not applications.has(owner):applications[owner]=[]
            if identity not in applications[owner]:applications[owner].append(identity)
            graph.application_indices[identity]=applications[owner].find(identity)
        for event_index in lineage.events.size():
            var node: Dictionary = lineage.events[event_index]
            var captured: Dictionary = recorded.events[event_index]
            graph.actor_inputs[node.id]=_spell_actor_inputs(node,captured.actor_inputs,target,graph)
            graph.item_inputs[node.id]=captured.item_inputs
            var cues:Array=[]
            for change in captured.get("condition_rows",[]):
                if change.row.get("field")!="condition":continue
                var member:Variant=change.after if change.after!=null else change.before
                if member==null:continue
                if change.after!=null and change.before!=null:continue
                cues.append({"actor_uuid":change.actor_uuid,"condition":member,"phase":"application" if change.after!=null else "removal",
                    "row":change.row,"recipe":Authoring.load_data("catalog/condition_recipes.json",cache).get(str(member.get("behavior_id","")),{})})
            graph.condition_cues[node.id]=cues
            if node.fact!=null and node.fact.kind=="object_damage":
                graph.object_inputs[node.id]=target.objects.get(node.fact.object_uuid,{})
            apply_delta(target,captured.delta)
            group.commits.append({"at_ms":0.0,"source_index":captured.source_index,"event_uuid":node.id,
                "delta":captured.delta,"condition_rows":captured.get("condition_rows",[])})
        var trailing: Dictionary = recorded.trailing
        apply_delta(target,trailing)
        if profile_enabled:stage_started=_profile_phase(compile_phases,"lineage_inputs",stage_started)
        if lineage.root != null: group.duration_ms = _schedule(lineage.root,0.0,target,group,graph,cache)
        for node in lineage.events:
            if not graph.visited.has(node.lineage_id):
                group.duration_ms = maxf(group.duration_ms,_schedule(node,0.0,target,group,graph,cache))
        var at = 0.0
        for commit in group.commits:
            at = maxf(at,graph.times.get(commit.event_uuid,at))
            commit.at_ms = at
        group.duration_ms = maxf(group.duration_ms,at)
        _reaction_casts(lineage,target,group,graph,cache)
        if profile_enabled:stage_started=_profile_phase(compile_phases,"schedule_delivery",stage_started)
        # A staged row is disclosed at its first commit, actor admission or
        # track endpoint. Fold those few clocks once per source, visiting each
        # identity's candidates in the same order as a per-row scan would,
        # instead of rescanning every commit/track (and formatting every
        # endpoint) for every staged row.
        var end: float = group.duration_ms
        var actor_clocks: Dictionary = {}
        for commit in group.commits:
            for identity in commit.delta.actors:
                if group.staged_actors.has(identity): actor_clocks[identity] = minf(actor_clocks.get(identity,end),commit.at_ms)
        for track in group.actor_tracks:
            var target_uuid: Variant = track.get("target_uuid")
            for identity in [track.actor_uuid] if target_uuid == track.actor_uuid else [track.actor_uuid,target_uuid]:
                if group.staged_actors.has(identity): actor_clocks[identity] = minf(actor_clocks.get(identity,end),track.start_ms)
        for identity in group.staged_actors: group.staged_at_ms[identity] = actor_clocks.get(identity,end)
        var tile_clocks: Dictionary = {}
        if not group.staged_tiles.is_empty():
            for commit in group.commits:
                for key in commit.delta.tiles:
                    if group.staged_tiles.has(key): tile_clocks[key] = minf(tile_clocks.get(key,end),commit.at_ms)
            for identity in group.staged_actors:
                var point: Variant = group.staged_actors[identity].last_visual_position
                if point == null: continue
                var key: String = Reducer.Audience.point_key(point)
                if group.staged_tiles.has(key): tile_clocks[key] = minf(tile_clocks.get(key,end),group.staged_at_ms[identity])
            for track in group.actor_tracks:
                for field in ["from_position","to_position","target_position"]:
                    if track.get(field) == null: continue
                    var key: String = Reducer.Audience.point_key(track[field])
                    if group.staged_tiles.has(key): tile_clocks[key] = minf(tile_clocks.get(key,end),track.start_ms)
        for key in group.staged_tiles: group.staged_tile_at_ms[key] = tile_clocks.get(key,end)
        group.commits.append({"at_ms":group.duration_ms,"source_index":lineage.end_cursor,"delta":trailing})
        if profile_enabled:stage_started=_profile_phase(compile_phases,"disclosure_times",stage_started)
        var components:Dictionary=Components.compile(group,lineage,graph,cache)
        if not components.ok:return components
        if profile_enabled:stage_started=_profile_phase(compile_phases,"components",stage_started)
        group.events = EventTrace.compile_rows(lineage,group,graph,cache)
        if profile_enabled:stage_started=_profile_phase(compile_phases,"event_trace",stage_started)
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
    if not packet.get("content_additions",[]).is_empty(): ending.set.content = final_state.content.duplicate(true)
    if not packet.get("combat_log_appends",[]).is_empty(): ending.log_appends = packet.combat_log_appends.duplicate(true)
    last.commits.append({"at_ms":last.duration_ms,"source_index":final_state.reducer_cursor,"delta":ending,
        "trace_logs":EventTrace.operation_logs(packet)})
    if profile_enabled:stage_started=_profile_phase(compile_phases,"ending",stage_started)
    _native_requirements(before,groups,cache)
    if profile_enabled:stage_started=_profile_phase(compile_phases,"native_requirements",stage_started)
    _actor_structure_requirements(before,groups,cache)
    if profile_enabled:stage_started=_profile_phase(compile_phases,"actor_cuts",stage_started)
    var skipped: Array = []
    for group in groups: skipped.append_array(group.skipped)
    var compiled:Dictionary=Reducer.success({"groups":groups,"final_state":final_state,"skipped":skipped})
    if profile_enabled:
        compile_phases.total=(Time.get_ticks_usec()-compile_started)/1000.0
        compiled.compile_phases_ms=compile_phases
    return compiled
