extends RefCounted
## Offline semantic index. No transport, SceneTree, images or GPU objects here.
const Journal = preload("res://sdk/journal.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Characters = preload("res://presentation/characters.gd")
const ConditionCoverage = preload("res://presentation/condition_coverage.gd")
const Appearance=preload("res://presentation/condition_appearance.gd")
const ConditionPose = preload("res://presentation/condition_pose.gd")
const World = preload("res://presentation/world.gd")
const LightTracks = preload("res://studio/light_tracks.gd")
const NativeChannels=preload("res://presentation/native_spell_channels.gd")
const NativeItems=preload("res://presentation/native_items.gd")
const NativePersistent=preload("res://presentation/native_persistent.gd")
const ReplayComparison = preload("res://studio/replay_comparison.gd")
const PREVIEW_LEAD_IN_MS = 500.0
const PREVIEW_OPERATION_GAP_MS = 350.0
## Inspection links to the existing finite material mechanisms. Availability
## comes from ConditionCoverage; these links do not qualify rendering.
const MATERIAL_METHODS = {
    "bodyScale":{"label":"Body scale","surface":"whole outfit","renderer":"res://presentation/conditions.gd::material + res://play.gd::_sample_actors"},
    "bodyColor":{"label":"Body color filter","surface":"body","renderer":"res://presentation/conditions.gd::bind","shader":"res://presentation/character_material.gdshaderinc::character_material"},
    "bodyRamp":{"label":"Body material ramp","surface":"body","renderer":"res://presentation/conditions.gd::bind","shader":"res://presentation/character_material.gdshaderinc::character_material"},
    "bodyOutline":{"label":"Body outline","surface":"outline","renderer":"res://presentation/condition_outline.gd::sample","shader":"res://presentation/condition_outline.gdshaderinc::condition_outline_colour"},
    "alphaMultiplier":{"label":"Body opacity","surface":"body","renderer":"res://presentation/conditions.gd::bind","shader":"res://presentation/character_material.gdshaderinc::character_material"}
}

static func _rendered_operation(groups: Array) -> bool:
    for group in groups:
        for track in group.actor_tracks:
            if track.duration_ms > 0: return true
        for component in group.get("components",[]):
            if component.get("status") == "available" and component.duration_ms > 0: return true
    return false

static func cancellation() -> Dictionary:
    return {"mutex":Mutex.new(),"canceled":false}

static func cancel(token: Dictionary) -> void:
    if token.is_empty(): return
    token.mutex.lock();token.canceled=true;token.mutex.unlock()

static func canceled(token: Dictionary) -> bool:
    if token.is_empty(): return false
    token.mutex.lock();var value: bool=token.canceled;token.mutex.unlock()
    return value

static func _movement_allowances(before:Dictionary,after:Dictionary,sequence:int)->Dictionary:
    var prior:Variant=before.get("hud_snapshot")
    var current:Variant=after.get("hud_snapshot")
    if prior==null or current==null:return {}
    var previous={};var result={}
    for sheet in prior.sheets:
        for resource in sheet.resources:
            if resource.key=="movement":previous[sheet.actor_uuid]=resource.current
    for sheet in current.sheets:
        for resource in sheet.resources:
            if resource.key!="movement" or not previous.has(sheet.actor_uuid) or previous[sheet.actor_uuid]==resource.current:continue
            result[sheet.actor_uuid]={"actor_uuid":sheet.actor_uuid,"before_feet":previous[sheet.actor_uuid],"after_feet":resource.current,
                "operation_sequence":sequence,"source":"PlayerOperation.hud.sheets[].resources[movement]"}
    return result

static func read(directory: String, token: Dictionary={}, projection:Dictionary={}, source_cache:Dictionary={}) -> Dictionary:
    var started = Time.get_ticks_usec()
    if not DirAccess.dir_exists_absolute(directory): return {"ok":false,"error":"Recording directory does not exist: "+directory}
    var journal = Journal.new()
    var opened = journal.open(directory,true,false)
    if not opened.ok: return opened
    var files: Array[String] = []
    var expression = RegEx.new()
    expression.compile("^[0-9]{16}\\.json$")
    for filename in DirAccess.get_files_at(directory):
        if expression.search(filename) != null: files.append(filename)
    files.sort()
    if files.is_empty(): return {"ok":false,"error":"No SDK packets found in "+directory}
    var result = {"ok":true,"directory":directory,"initialization":{},"groups":[],"rows":[],"duration_ms":0.0,"operations":0,"cache":{},"bytes":0,"compile_ms":0.0,"correspondence_candidates":{}}
    var read_profile={"decode_ms":0.0,"reduce_ms":0.0,"compile_ms":0.0,"index_ms":0.0,"packets":[]}
    result.cache=source_cache.duplicate()
    if not projection.is_empty():result.cache=projection.cache.duplicate()
    # Inspection spacing is explicit display timing, not a server event or an
    # authored action duration. Compiler-owned group-local clocks stay intact.
    var offset = PREVIEW_LEAD_IN_MS
    var rendered_operation = false
    var condition_history={}
    var condition_removals={}
    var light_history={}
    var spatial_history={}
    var item_owners:Dictionary={};var item_history:Dictionary={};var item_spans:Array=[]
    var spatial_owners={}
    var condition_parents={}
    var condition_intervals={}
    var preview_state={}
    var preview_states={}
    var preview_tracks={}
    var previous_directions={}
    var capture_retained:Array=[]
    for sequence in files.size():
        if canceled(token): return {"ok":false,"canceled":true,"error":"Superseded recording request"}
        if files[sequence] != "%016d.json" % sequence: return {"ok":false,"error":"Recording requires a complete contiguous prefix from initialization"}
        var raw = FileAccess.get_file_as_bytes(directory.path_join(files[sequence]))
        result.bytes += raw.size()
        var phase_started=Time.get_ticks_usec()
        var decoded = journal.decode_record(sequence,raw)
        var packet_profile={"sequence":sequence,"bytes":raw.size(),"decode_ms":(Time.get_ticks_usec()-phase_started)/1000.0}
        read_profile.decode_ms+=packet_profile.decode_ms
        if not decoded.ok: return decoded
        if int(decoded.value.cursor.sequence)!=sequence: return {"ok":false,"error":"Recording filename/cursor mismatch"}
        result.correspondence_candidates.merge(ReplayComparison.packet_causes(decoded.value))
        var before: Dictionary = journal.state
        phase_started=Time.get_ticks_usec()
        var admitted = journal._consume_admitted(decoded.value,raw,true)
        packet_profile.reduce_ms=(Time.get_ticks_usec()-phase_started)/1000.0
        read_profile.reduce_ms+=packet_profile.reduce_ms
        read_profile.packets.append(packet_profile)
        if not admitted.ok: return admitted
        if sequence==0:
            result.identity=decoded.value.cursor.duplicate()
            result.initialization = {"kind":"initialization","state":journal.state.duplicate(true),"sequence":0,
                "events":Compiler.EventTrace.initialization(admitted.normalized.initialization)}
            _observe_condition_history(condition_history,condition_intervals,condition_parents,journal.state.actors,0.0,"",true)
            preview_state=journal.state.duplicate(true)
            NativeItems.observe(item_owners,preview_state,0.0,result.cache)
            _observe_item_history(item_history,item_spans,item_owners,preview_state,0.0,"",result.cache)
            _preview_states(preview_states,preview_state,preview_state.actors,condition_history,0.0,result.cache)
            LightTracks.observe(light_history,preview_state,0.0,"",0,result.cache)
            _observe_spatial_history(spatial_history,spatial_owners,preview_state.senses.get("spatial_effects",{}),0.0,"",true)
            continue
        var compiled:Dictionary
        phase_started=Time.get_ticks_usec()
        if projection.is_empty():compiled=Compiler.compile_recorded(before,admitted.normalized,result.cache,journal.state,admitted.transitions)
        else:
            var groups:Array=projection.operations.get(sequence,[])
            if groups.is_empty() or groups.any(func(group):return group.cursor!=decoded.value.cursor):
                return {"ok":false,"error":"Comparison projection does not belong to this independently admitted operation"}
            compiled={"ok":true,"value":{"groups":groups}}
        packet_profile.compile_ms=(Time.get_ticks_usec()-phase_started)/1000.0
        read_profile.compile_ms+=packet_profile.compile_ms
        if not compiled.ok: return compiled
        phase_started=Time.get_ticks_usec()
        for lineage in admitted.get("transitions",{}).get("lineages",[]):
            for event in lineage.get("events",[]):
                for change in event.get("condition_rows",[]):
                    if change.after==null and change.before!=null:
                        var condition:Dictionary=change.before
                        condition_removals[condition.condition_uuid]={"event_id":"%s:%s"%[sequence,event.occurrence],"event_uuid":str(event.occurrence),"actor_uuid":change.actor_uuid}
        var rendered = _rendered_operation(compiled.value.groups)
        if projection.is_empty() and rendered and rendered_operation: offset += PREVIEW_OPERATION_GAP_MS
        rendered_operation = rendered_operation or rendered
        # HUD resource values describe complete operation boundaries. They are
        # never apportioned into fabricated per-step allowance updates.
        var movement_allowances=_movement_allowances(before,journal.state,sequence)
        for compiled_group in compiled.value.groups:
            var group: Dictionary = compiled_group.duplicate()
            if not projection.is_empty():offset=group.preview_start_ms
            group.preview_start_ms = offset
            result.groups.append({"start_ms":offset,"group":group})
            # The offline index owns historical lifetimes independently of the
            # live Timeline, which may retire ended presentation owners.
            var perception={}
            var nodes={}
            for event in group.events:nodes[event.event_uuid]=event
            for commit in group.commits:
                var captures:Dictionary=Timeline.pose_admissions(commit,preview_state,condition_history,group,offset,previous_directions,result.cache,capture_retained)
                Compiler.apply_delta(preview_state,commit.delta)
                if NativeItems.interested(item_owners,commit.delta,result.cache):
                    NativeItems.observe(item_owners,preview_state,offset+commit.at_ms,result.cache,str(commit.get("event_uuid","")),commit.get("item_rows",[]))
                    _observe_item_history(item_history,item_spans,item_owners,preview_state,offset+commit.at_ms,"%s:%s"%[sequence,commit.get("event_uuid","")],result.cache)
                LightTracks.observe(light_history,preview_state,offset+commit.at_ms,commit.get("event_uuid",""),sequence,result.cache)
                _observe_spatial_history(spatial_history,spatial_owners,preview_state.senses.get("spatial_effects",{}) if preview_state.senses!=null else {},offset+commit.at_ms,commit.get("event_uuid",""),false,commit.get("spatial_rows",[]))
                if nodes.has(commit.get("event_uuid","")):
                    var event:Dictionary=nodes[commit.event_uuid]
                    var contacts={}
                    for actor_id in [event.get("actor_uuid"),event.get("target_uuid")]:
                        if actor_id==null:continue
                        var actor:Dictionary=preview_state.actors.get(actor_id,{})
                        contacts[actor_id]={"known":not actor.is_empty(),"visible":not actor.is_empty() and World.visible_actor(actor,preview_state)}
                    perception[event.event_uuid]=contacts
                var actors: Dictionary=commit.delta.get("actors",{})
                _observe_condition_history(condition_history,condition_intervals,condition_parents,actors,offset+commit.at_ms,
                    "%s:%s"%[sequence,commit.get("event_uuid","")],false,commit.get("condition_rows",[]),captures,commit.get("creation_bindings",{}))
                _preview_states(preview_states,preview_state,actors,condition_history,offset+commit.at_ms,result.cache,commit.get("event_uuid",""))
            var events: Dictionary = {}
            for event in group.events:
                var row = {"id":event.id,"parent":event.parent_id,"kind":"event","label":str(event.name),"depth":0,
                    "start_ms":offset+float(event._start_ms),"end_ms":offset+float(event._end_ms),"event":event,"group_id":group.id,"status":event.status,"markers":[]}
                if event.parent_id.is_empty() and movement_allowances.has(event.actor_uuid):
                    row.movement_allowance=movement_allowances[event.actor_uuid]
                    movement_allowances.erase(event.actor_uuid)
                row.perception=perception.get(event.event_uuid,{})
                for commit in group.commits:
                    if commit.get("event_uuid")==event.event_uuid:row.markers.append({"kind":"commit","at_ms":offset+commit.at_ms,"source":"compiled.commits.at_ms"})
                events[event.event_uuid] = row
                result.rows.append(row)
                _missing_rows(result.rows,row,event.components,offset)
            for track in group.actor_tracks:
                if not preview_tracks.has(track.actor_uuid):preview_tracks[track.actor_uuid]=[]
                var absolute_track:Dictionary=track.duplicate()
                absolute_track.start_ms=offset+track.start_ms;absolute_track.group_end_ms=offset+group.duration_ms
                preview_tracks[track.actor_uuid].append(absolute_track)
                var actor: Dictionary = track.presentation_actor.duplicate()
                if track.has("visual_loadout"): actor.visual_loadout = track.visual_loadout
                actor.presentation_layers=track.get("effect_layers",[])
                var state: Dictionary = before if actor.last_visual_position!=null and before.tiles.has(Compiler.Reducer.Audience.point_key(actor.last_visual_position)) else journal.state
                var resolved = Characters.resolve(actor,state,result.cache)
                var row = {"id":track.trace_track_id,"parent":"%s:%s" % [sequence,track.source_event_uuid],
                    "kind":"body","label":"Body · "+track.clip,"depth":1,"start_ms":offset+track.start_ms,
                    "end_ms":offset+track.start_ms+track.duration_ms,"track":track,"group_start_ms":offset,
                    "actor_name":before.actors.get(track.actor_uuid,journal.state.actors.get(track.actor_uuid,{})).get("name",""),
                    "actor":resolved.value if resolved.ok and resolved.value!=null else {},"status":"available" if resolved.ok and resolved.value!=null else "missing","group_id":group.id,
                    "source_fps":Compiler.Authoring.clip(track.presentation_actor,track.clip,result.cache).get("fps",0),
                    "source_event_uuid":track.source_event_uuid}
                row.markers=[]
                if track.has("contact_ms"):row.markers.append({"kind":"contact","at_ms":offset+track.contact_ms,"source":"compiled.actor_tracks.contact_ms"})
                result.rows.append(row)
                if not row.actor.is_empty():
                    var parts_id: String=row.id+":parts"
                    result.rows.append({"id":parts_id,"parent":row.id,"kind":"parts","label":"Body / gear parts",
                        "actor_uuid":track.actor_uuid,"start_ms":row.start_ms,"end_ms":row.end_ms,"status":"available"})
                    for layer in row.actor.equipment_layers:
                        if layer.slot=="shadow" or layer.slot in track.get("hidden_slots",[]):continue
                        result.rows.append({"id":parts_id+":"+layer.slot,"parent":parts_id,"kind":"part","label":str(layer.slot).capitalize(),
                            "start_ms":row.start_ms,"end_ms":row.end_ms,"status":row.status,"track":track,"actor":row.actor,
                            "source_fps":row.source_fps,"slot":layer.slot,"layer":layer,
                            "source":"catalog/rigs.json:/%s/clips/%s/sheets/%s"%[track.rig,track.clip,layer.category]})
            for compiled_component in group.get("components",[]):
                var component:Dictionary=compiled_component
                if component.has("impact"):
                    component=component.duplicate()
                    component.impact=Timeline.ImpactPlacement.with_direction(component.impact,Timeline.component_direction(group,component,previous_directions),result.cache)
                    if component.impact.status=="missing":component.status="missing";component.reason=component.impact.reason
                var actor={}
                if component.has("presentation_actor"):
                    var resolved=Characters.resolve(component.presentation_actor,journal.state,result.cache)
                    if resolved.ok and resolved.value!=null:actor=resolved.value
                var source_track:Dictionary=component.get("source_track",{})
                if component.has("body_track_id"):
                    for body_row in result.rows:
                        if body_row.id==component.body_track_id:actor=body_row.actor;source_track=body_row.track;break
                result.rows.append({"id":component.id,"parent":component.parent_id,"kind":component.kind,
                    "label":"Weapon impact" if component.get("native_weapon_impact",false) else str(component.native_cue.role).capitalize() if component.get("native_spell",false) else str(component.get("text")) if component.kind=="feedback_text" else str(component.get("cue_id",component.get("source_id",component.kind))),"depth":1,
                    "start_ms":offset+component.start_ms,"end_ms":offset+component.start_ms+component.duration_ms,
                    "component":component,"group_start_ms":offset,"group_id":group.id,
                    "source_event_uuid":component.source_event_uuid,"source":component.get("source",""),
                    "status":component.get("status","missing"),"reason":component.get("reason",""),
                    "missing_category":"source" if component.get("status")=="missing" else "",
                    "coverage":{"implementation":"resolved","source":component.get("status","missing"),"prepared":"not_examined","rendered":"not_witnessed"},"source_fps":component.get("sample_hz",0),"actor":actor,"source_track":source_track,
                    "markers":[{"kind":component.source_marker,"at_ms":offset+component.get("contact_ms",component.start_ms),"source":component.get("timing_source","compiled.component.source_marker")}] if component.has("source_marker") else []})
                for channel in NativeChannels.channels(component):
                    result.rows.append({"id":channel.id,"parent":component.id,"kind":channel.kind,"label":channel.label,
                        "start_ms":offset+channel.start_ms,"end_ms":offset+channel.start_ms+channel.duration_ms,
                        "component":channel,"group_start_ms":offset,"group_id":group.id,"source_event_uuid":channel.source_event_uuid,
                        "source":channel.source,"status":channel.status,"reason":channel.get("reason",""),
                        "render_method":channel.render_method,"preview_scope":channel.get("preview_scope","source_property_keys"),
                        "markers":NativeChannels.markers(channel,offset),
                        "coverage":{"implementation":"resolved","source":channel.status,"prepared":"not_examined","rendered":"not_witnessed"}})
            Timeline._directions(group.actor_tracks,INF,previous_directions)
            capture_retained=capture_retained.filter(func(item):return float(item.group_start_ms)+float(item.component.start_ms)+float(item.component.duration_ms)>offset+float(group.duration_ms))
            for component in group.get("components",[]):
                if component.kind in ["sprite_layer","material_flash","body_surface"] and float(component.start_ms)+float(component.duration_ms)>float(group.duration_ms):capture_retained.append({"component":component,"group_start_ms":offset})
            offset += group.duration_ms
        result.operations += 1
        packet_profile.index_ms=(Time.get_ticks_usec()-phase_started)/1000.0
        read_profile.index_ms+=packet_profile.index_ms
    if not projection.is_empty():offset=maxf(offset,projection.duration_ms)
    result.duration_ms = offset
    result.presentation_end_ms=offset
    for row in result.rows: result.presentation_end_ms=maxf(result.presentation_end_ms,row.end_ms)
    for owner in condition_history.values():
        var fade=Timeline.Conditions.fade_ms(owner.condition,result.cache)
        if not is_inf(owner.end_ms):result.presentation_end_ms=maxf(result.presentation_end_ms,owner.end_ms+fade)
    for owner in spatial_owners.values():
        if not is_inf(owner.end_ms):result.presentation_end_ms=maxf(result.presentation_end_ms,owner.end_ms+_spatial_presentation(owner.effect,result.cache).close_ms)
    var condition_ids={}
    for owner in condition_history.values():condition_ids[owner.condition.behavior_id]=true
    var condition_requirements={}
    if not condition_ids.is_empty():
        for entry in ConditionCoverage.build(result.cache,[],condition_ids).entries:condition_requirements[entry.id]=entry.requirements
    var occurrence_ids={}
    for row in result.rows:
        if row.kind=="event":occurrence_ids[row.event.event_uuid]=row.id
    for owner in condition_history.values():
        var recipe=Timeline.Conditions.recipe(owner.condition,result.cache)
        var end: float=result.presentation_end_ms if is_inf(owner.end_ms) else owner.end_ms
        var origin:Dictionary=condition_parents.get(owner.id,{})
        var parent: String=occurrence_ids.get(origin.get("cause_uuid",""),origin.get("event_id","")) if not origin.get("initial",false) else ""
        var life={"id":"condition:"+owner.id,"parent":parent,"kind":"condition","label":str(owner.condition.name),
            "start_ms":owner.start_ms,"end_ms":end,"owner":owner,"recipe":recipe,
            "source":"catalog/condition_recipes.json:/"+str(owner.condition.behavior_id),
            "status":"missing" if recipe.is_empty() else ("state_only" if recipe.get("disposition")=="state_only" else "available")}
        result.rows.append(life)
        var requirements:Array=condition_requirements.get(owner.condition.behavior_id,[])
        var intervals: Array=condition_intervals.get(owner.id,[])
        if intervals.size()>1 or intervals.any(func(interval):return interval.suppressed):
            for n in intervals.size():
                var interval: Dictionary=intervals[n]
                result.rows.append({"id":life.id+":state:"+str(n),"parent":life.id,"kind":"condition_state",
                    "label":"Suppressed" if interval.suppressed else ("Restored" if n>0 else "Active"),
                    "start_ms":interval.start_ms,"end_ms":end if is_inf(interval.end_ms) else interval.end_ms,
                    "actor_uuid":owner.actor_uuid,"providers":interval.providers,"source_event":interval.source_event,"status":"state_only","source":life.source,
                    "interval_causes":[_condition_cause(interval.source_event,owner.id)]})
        _condition_rows(result.rows,life,owner,intervals,preview_states.get(owner.actor_uuid,[]),result.cache,preview_tracks.get(owner.actor_uuid,[]),requirements)
        _condition_missing_rows(result.rows,life,requirements)
        var fade=Timeline.Conditions.fade_ms(owner.condition,result.cache)
        if fade>0 and not is_inf(owner.end_ms):
            var exit_row={"id":life.id+":exit","parent":life.id,"kind":"condition_exit","label":"Removal fade",
                "start_ms":owner.end_ms,"end_ms":owner.end_ms+fade,"owner":owner,"recipe":recipe,"source":life.source,"status":life.status}
            result.rows.append(exit_row)
            _condition_rows(result.rows,exit_row,owner,[{"start_ms":owner.end_ms,"end_ms":owner.end_ms+fade,"suppressed":Timeline.Conditions.suppressed(owner.condition),"source_event":origin.get("removal_event","")}],preview_states.get(owner.actor_uuid,[]),result.cache,preview_tracks.get(owner.actor_uuid,[]),requirements)
        _condition_restoration_rows(result,owner,condition_removals.get(owner.id,{}),preview_states.get(owner.actor_uuid,[]),preview_tracks.get(owner.actor_uuid,[]))
    for span in item_spans:
        if span.kind=="item_effect_membership":
            result.rows.append(span);continue
        span.end_ms=minf(span.end_ms,result.presentation_end_ms)
        var component:Dictionary=span.component
        component=component.duplicate(false);component.duration_ms=span.end_ms-span.start_ms
        span.component=component
        span.erase("signature")
        result.rows.append(span)
        var receiver:Dictionary=span.duplicate(false)
        receiver.merge({"id":component.id+":weapon_surface:span:"+str(span.start_ms),"parent":span.id,"kind":"native_material",
            "label":"Weapon surface","trace_track_id":component.id+":weapon_surface",
            "render_method":{"surface":"separate modular weapon layer","renderer":"res://presentation/native_weapon_inputs.gd","item_uuid":component.item_owner_uuid},
            "preview_scope":"live_composed_actor","preview_status":"missing","preview_reason":"Inspect the attached effect on the actual weapon in the replay; no isolated composed-weapon thumbnail is supplied."},true)
        result.rows.append(receiver)
        _persistent_native_channels(result.rows,span,component)
    result.rows.append_array(LightTracks.rows(light_history,result,preview_tracks))
    _spatial_rows(result,spatial_history,spatial_owners,occurrence_ids)
    _actor_row_links(result)
    for row in result.rows:
        var actor_value:Variant=row.get("track",row.get("component",{})).get("actor_uuid",row.get("actor_uuid",row.get("owner",{}).get("actor_uuid","")))
        var actor_id:String="" if actor_value==null else str(actor_value)
        if preview_states.has(actor_id):
            row.actor_uuid=actor_id
            row.actor_name=_actor_name_at(preview_states[actor_id],row.start_ms)
            row.preview_states=preview_states[actor_id]
            row.preview_tracks=preview_tracks.get(actor_id,[])
            var sampled: Dictionary=row.preview_states[0]
            for state in row.preview_states:
                if state.at_ms>row.start_ms:break
                sampled=state
            if row.kind not in ["body","part","sprite_layer"]:row.actor=sampled.actor
            row.sampled_pose=sampled.sampled_pose;row.condition_owners=sampled.condition_owners
        var target_id:Variant=row.get("component",{}).get("target_uuid")
        if target_id!=null and not target_id.is_empty():
            row.target_uuid=target_id
            row.target_name=_actor_name_at(preview_states.get(target_id,[]),row.start_ms)
        if row.has("recipient_uuid"):
            row.recipient_name=_actor_name_at(preview_states.get(row.recipient_uuid,[]),row.start_ms)
    result.compile_ms = (Time.get_ticks_usec()-started)/1000.0
    result.read_profile=read_profile
    return result

static func _actor_row_links(index:Dictionary)->void:
    # Offline links reuse the already indexed owners. They neither emit an
    # operation nor qualify pixels, and never borrow another perspective.
    var conditions:Dictionary={};var items:Dictionary={};var item_effects:Dictionary={};var lights:Dictionary={};var tracks:Dictionary={}
    for row in index.rows:
        var track:String=str(row.get("trace_track_id",row.get("track",{}).get("trace_track_id","")))
        if not track.is_empty():
            if not tracks.has(track):tracks[track]=[]
            tracks[track].append(row.id)
        if row.kind=="condition":conditions[[str(row.owner.id),str(row.owner.actor_uuid)]]=row.id
        elif row.kind=="native_effect" and row.get("component",{}).get("native_item",false):
            var component:Dictionary=row.component
            var key:Array=[str(component.item_owner_uuid),str(component.actor_uuid)]
            if not items.has(key):items[key]=[]
            items[key].append(row.id)
            if component.get("dynamic_item_effect",false):
                var identity:Array=[str(component.item_owner_uuid),str(component.item_effect_uuid)]
                if not item_effects.has(identity):item_effects[identity]=[]
                item_effects[identity].append(row.id)
        elif row.kind=="light":
            for key in row.light_keys:
                var identity:Array=[str(key.operation_sequence),str(key.source_event_uuid),str(row.anchor_item_uuid)]
                if not lights.has(identity):lights[identity]=[]
                lights[identity].append(row.id)
    for row in index.rows:
        if row.kind!="event" or not row.event.has("_actor_rows"):continue
        row.actor_rows=row.event._actor_rows.duplicate(true)
        for expected in row.actor_rows:
            expected.trace_track_ids=expected.inspection_links
            expected.inspection_links=[]
            for track in expected.trace_track_ids:
                for linked in tracks.get(track,[]):
                    if linked not in expected.inspection_links:expected.inspection_links.append(linked)
            if expected.has("condition_uuid"):
                var owner:Array=[str(expected.condition_uuid),expected.actor_uuid]
                if conditions.has(owner) and conditions[owner] not in expected.inspection_links:expected.inspection_links.append(conditions[owner])
            if expected.has("item_uuid") and expected.actor_field in ["inventory","layer","active_weapon_set"]:
                for linked in items.get([expected.item_uuid,expected.actor_uuid],[]):
                    if linked not in expected.inspection_links:expected.inspection_links.append(linked)
            if expected.has("item_uuid") and expected.actor_field in ["item_effects","item_effect_duration"]:
                var identities:Array=expected.get("effect_uuids_before",[])+expected.get("effect_uuids_after",expected.get("effect_uuids",[]))
                if expected.has("effect_uuid"):identities.append(expected.effect_uuid)
                for identity in identities:
                    for linked in item_effects.get([expected.item_uuid,str(identity)],[]):
                        if linked not in expected.inspection_links:expected.inspection_links.append(linked)
            if expected.actor_field=="item_state" and "is_lit" in expected.changed_keys:
                for linked in lights.get([str(row.event.sequence),str(row.event.event_uuid),expected.item_uuid],[]):
                    if linked not in expected.inspection_links:expected.inspection_links.append(linked)

static func _actor_name_at(states:Array,at_ms:float)->String:
    var name=""
    for state in states:
        if state.at_ms>at_ms:break
        name=state.actor_name
    return name

static func _condition_presentation_at(states:Array,tracks:Array,at_ms:float,cache:Dictionary)->Dictionary:
    var state={}
    for candidate in states:
        if candidate.at_ms>at_ms:break
        state=candidate
    if state.is_empty():return {}
    var body:Dictionary=Compiler.Tracks.samples(tracks.filter(func(track):return at_ms<track.group_end_ms),at_ms).get(state.actor.id,{})
    var pose:Dictionary=state.sampled_pose if body.is_empty() or state.sampled_pose.get("condition_pose",{}).get("captured",false) else body
    var selected:Dictionary=pose.get("condition_pose",{})
    var source:String=selected.get("source",body.get("source","catalog/rigs.json:/"+state.actor.rig+"/clips/"+pose.clip))
    if source.is_empty():source="catalog/rigs.json:/"+state.actor.rig+"/clips/"+pose.clip
    var materials=Timeline.Conditions.samples(state.condition_owners.duplicate(),at_ms,cache)
    var method_owners={}
    for sample in Timeline.Conditions.select_recipes(state.actor.id,materials):
        var persistent:Dictionary=sample.recipe.get("persistent",{})
        for field in MATERIAL_METHODS:
            if field=="bodyScale":
                if not Timeline.Conditions.scale_operation(sample).is_empty():
                    if not method_owners.has(field):method_owners[field]=[]
                    method_owners[field].append(sample.condition_uuid)
            elif field=="alphaMultiplier":
                if persistent.get(field,1.0)!=1.0:
                    if not method_owners.has(field):method_owners[field]=[]
                    method_owners[field].append(sample.condition_uuid)
            elif not method_owners.has(field) and persistent.get(field)!=null and not persistent[field].is_empty():
                # Conditions.material uses the first selected nonempty color,
                # outline and ramp; alpha composes all selected contributors.
                method_owners[field]=[sample.condition_uuid]
    return {"state":state,"pose":{"clip":pose.clip,"source":source,"condition_uuid":selected.get("condition_uuid",""),"activity":body.get("activity","idle"),
        "sampling":selected.get("sampling","hold" if pose.get("clock")=="fixed" else "loop" if body.is_empty() or body.get("loop",false) else "clip"),"frame":selected.get("frame")},
        "material":Timeline.Conditions.material(state.actor.id,materials),"method_owners":method_owners}

static func _material_operation(value:Dictionary,field:String)->Variant:
    match field:
        "bodyScale":return value.body_scale.factor
        "alphaMultiplier":return value.alpha
        "bodyColor":return {"tint":value.tint,"saturation":value.saturation,"brightness":value.brightness}
        "bodyOutline":return value.outline
        "bodyRamp":return value.ramp
    return null

static func _condition_restoration_rows(index:Dictionary,owner:Dictionary,removal:Dictionary,states:Array,tracks:Array)->void:
    # A missing owner after a sensory update is not proof of a removal. These
    # rows require the actual disclosed condition-removal fact and its commit.
    if removal.is_empty() or is_inf(owner.end_ms) or removal.actor_uuid!=owner.actor_uuid:return
    var occurrence:Dictionary={}
    for row in index.rows:
        if row.id==removal.event_id:occurrence=row;break
    if occurrence.is_empty():return
    var removed=-1.0
    for marker in occurrence.markers:
        if marker.kind=="commit":removed=marker.at_ms;break
    if removed<0:return
    var persistent:Dictionary=Timeline.Conditions.recipe(owner.condition,index.cache).get("persistent",{})
    var fade=Timeline.Conditions.fade_ms(owner.condition,index.cache)
    var fields:Array=[]
    for field in MATERIAL_METHODS:
        if persistent.get(field)!=null and (field!="alphaMultiplier" or persistent[field]!=1.0):fields.append(field)
    if persistent.has("bodyPose") or persistent.has("frozenPose") or not persistent.get("activityPoses",[]).is_empty():fields.append("pose")
    for field in fields:
        var at:float=removed if field=="pose" else maxf(removed,owner.end_ms+fade)
        var before=_condition_presentation_at(states,tracks,maxf(0,removed-.001),index.cache)
        var after=_condition_presentation_at(states,tracks,at,index.cache)
        if before.is_empty() or after.is_empty():continue
        if field!="pose" and owner.id not in before.method_owners.get(field,[]):continue
        var previous:Variant=before.pose if field=="pose" else _material_operation(before.material,field)
        var current:Variant=after.pose if field=="pose" else _material_operation(after.material,field)
        if previous==current:continue
        # An action can own the body during removal. Only a previously selected
        # condition pose is a visible restoration of this owner's pose policy.
        if field=="pose" and previous.condition_uuid!=owner.id:continue
        var end:float=index.presentation_end_ms
        for state in states:
            if state.at_ms>at:end=minf(end,state.at_ms);break
        for track in tracks:
            for boundary in [track.start_ms,track.start_ms+track.duration_ms,track.group_end_ms]:
                if boundary>at:end=minf(end,boundary)
        end=maxf(at,end)
        var source:String=previous.source if field=="pose" else Compiler.Authoring.Catalog.source_pointer("catalog/condition_recipes.json",owner.condition.behavior_id+"/persistent/"+field,index.cache)
        var method:Dictionary={"label":"Body pose selection","surface":"body","renderer":"res://presentation/characters.gd::rest_sample + res://presentation/condition_pose.gd::select"} if field=="pose" else MATERIAL_METHODS[field]
        var label:String="Body pose · "+str(previous.clip)+" → "+str(current.clip) if field=="pose" else method.label+" restored"
        if field=="pose" and previous.clip==current.clip and previous.sampling!=current.sampling:label="Body pose · "+str(current.clip)+" "+str(previous.sampling)+" → "+str(current.sampling)
        if field=="alphaMultiplier":label="Body opacity · %s → %s"%[String.num(previous,2),String.num(current,2)]
        index.rows.append({"id":"condition:"+owner.id+":restore:"+field,"parent":removal.event_id,"kind":"condition_restore","label":label,
            "start_ms":at,"end_ms":end,"owner":owner,"actor_uuid":owner.actor_uuid,"recipient_uuid":owner.actor_uuid,"mechanism":field,
            "source_event_uuid":removal.event_uuid,"source":source,"source_fields":{"removed_operation":source,"observed_removal":"PlayerNode.fact:condition_removal/condition/condition_uuid","selection":method.renderer},
            "render_method":method,"status":"available","coverage":{"implementation":"implemented","source":"available","prepared":"not_examined","rendered":"not_witnessed"},
            "transition":{"at_ms":at,"condition_removed_ms":removed,"from":previous,"to":current,"curve":"step" if field=="pose" or fade==0 else "existing condition removal fade","fade_ms":0.0 if field=="pose" else fade},
            "operations":{field:current},"preview_scope":"composed_actor","diagnostic_scope":"state_inspection",
            "timing_source":"Actual removal commit and existing condition fade; the after-state interval ends at the next recorded presentation boundary.",
            "markers":[{"kind":"restored","at_ms":at,"source":"recorded condition removal + existing Conditions.fade_ms"}],
            "source_fps":Compiler.Authoring.rigs(index.cache)[after.state.actor.rig].clips[after.pose.clip].fps})

static func read_case(case_record: Dictionary, token: Dictionary={}) -> Dictionary:
    # Each audience is admitted independently through the production SDK. A
    # combined inspection index must never become a combined gameplay state.
    var result={"ok":true,"case_id":case_record.id,"perspectives":case_record.perspectives,
        "views":{},"default_perspective_id":""}
    var identity={}
    for perspective in case_record.perspectives:
        if canceled(token):return {"ok":false,"canceled":true,"error":"Superseded case request"}
        var recorded=read(perspective.journal,token)
        if not recorded.ok:return recorded
        if identity.is_empty():identity=recorded.identity
        elif recorded.identity.game_id!=identity.game_id or recorded.identity.game_epoch!=identity.game_epoch:
            return {"ok":false,"error":"Faction views must belong to the same recorded encounter epoch"}
        recorded.perspective_id=perspective.id
        recorded.case_id=case_record.id
        result.views[perspective.id]=recorded
        if result.default_perspective_id.is_empty():result.default_perspective_id=perspective.id
    if result.views.is_empty():return {"ok":false,"error":"This capability has no recorded faction view yet"}
    ReplayComparison.correspondence(result)
    for view in result.views.values():_correspondence_rows(view)
    return result

static func compare_case(bundle:Dictionary,token:Dictionary={})->Dictionary:
    if not bundle.get("ok",false):return bundle
    if not requires_comparison(bundle):
        var unchanged=bundle.duplicate();unchanged.comparison=false
        return unchanged
    var scheduled=ReplayComparison.build(bundle)
    if not scheduled.ok:return scheduled
    var result=bundle.duplicate();result.views={}
    for id in bundle.views:
        if canceled(token):return {"ok":false,"canceled":true,"error":"Superseded comparison request"}
        # Reuse the ordinary independent admission and inspection projection.
        # Condition owners, restoration rows, light keys and source samples are
        # derived from the retimed own deltas; peer facts never enter this pass.
        var projected=read(bundle.views[id].directory,token,scheduled.views[id])
        if not projected.ok:return projected
        projected.perspective_id=id;projected.case_id=bundle.case_id
        projected.correspondence=bundle.views[id].correspondence
        projected.group_correspondence=bundle.views[id].group_correspondence
        _correspondence_rows(projected)
        projected.comparison_mapping=scheduled.mappings[id]
        result.views[id]=projected
    result.comparison=true;result.schedule=scheduled.schedule;result.blocks=scheduled.blocks
    result.duration_ms=scheduled.duration_ms;result.presentation_end_ms=scheduled.duration_ms
    for view in result.views.values():result.presentation_end_ms=maxf(result.presentation_end_ms,view.presentation_end_ms)
    for view in result.views.values():view.presentation_end_ms=result.presentation_end_ms
    return result

static func requires_comparison(bundle:Dictionary)->bool:
    if bundle.get("views",{}).size()<2:return false
    var first:Dictionary={}
    for index in bundle.views.values():
        var signature={"events":_event_signatures(index),"initial":_initial_presentation(index)}
        if first.is_empty():first=signature
        elif signature!=first:return true
    return false

static func _initial_presentation(index:Dictionary)->Dictionary:
    # A replay can differ before its first event. Compare existing rendering
    # projections, never private inventory, HUD resources or audience identity.
    var state:Dictionary=index.initialization.state;var cache:Dictionary=index.cache.duplicate()
    var actors={};var visible={};var owners={};var rows={}
    for actor in state.actors.values():
        if not World.visible_actor(actor,state):continue
        var resolved=Characters.resolve(actor,state,cache)
        actors[actor.uuid]=resolved;visible[actor.uuid]=actor
    Timeline.Conditions.observe(owners,visible,0.0,true)
    for row in World.rows(state,cache).visual_rows:rows[row.id]=row
    var sources={}
    for source in LightTracks.Lighting.resolve(state).sources:sources[source.item_uuid]=source
    return {"world":rows,"visibility":World.visibility(state),"actors":actors,"lights":sources,
        "conditions":Timeline.Conditions.samples(owners,0.0,cache,{},false)}

static func _event_rows(index: Dictionary) -> Dictionary:
    if index.has("clock_events"):return index.clock_events
    var result={}
    for row in index.rows:
        if row.kind=="event":result[row.event.event_uuid]=row
    return result

## Comparison metadata never replaces the seat's actual event/lineage fields.
static func event_key(index:Dictionary,occurrence:String)->String:
    if occurrence.is_empty():return ""
    return ReplayComparison.event_key(index,str(index.get("perspective_id",index.directory)),occurrence)

static func _group_key(index:Dictionary,id:String)->String:
    return ReplayComparison.group_key(index,str(index.get("perspective_id",index.directory)),id)

static func _clock_rows(index:Dictionary)->Dictionary:
    var result:Dictionary={};var rows:Dictionary=_event_rows(index)
    for occurrence in rows:result[event_key(index,str(occurrence))]=rows[occurrence]
    return result

static func _correspondence_rows(index:Dictionary)->void:
    var by_id:Dictionary={}
    for row in index.rows:by_id[row.id]=row
    for row in index.rows:
        var occurrence:String=_row_event(row)
        var parent:String=row.parent
        while occurrence.is_empty() and by_id.has(parent):
            occurrence=_row_event(by_id[parent]);parent=by_id[parent].parent
        row.correspondence_event_key=event_key(index,occurrence)
        row.correspondence_view=str(index.perspective_id)
        var causes:Array=[]
        for cause in row.get("interval_causes",[]):
            if str(cause).begins_with("event:"):causes.append("event:"+event_key(index,str(cause).trim_prefix("event:")))
            elif str(cause).begins_with("track:"):causes.append("view:"+str(index.perspective_id)+":"+str(cause))
            else:causes.append(cause)
        row.correspondence_causes=causes

static func _row_cause(row:Dictionary)->String:
    return str(row.get("correspondence_event_key",_row_event(row)))

static func _row_event(row: Dictionary) -> String:
    return str(row.get("event",{}).get("event_uuid",row.get("source_event_uuid",row.get("track",row.get("component",{})).get("source_event_uuid",row.get("owner",{}).get("condition",{}).get("event_uuid","")))))

static func navigation_anchor(index:Dictionary,at_ms:float,selected:Dictionary={},previous:Dictionary={}) -> Dictionary:
    var key:String=selected.get("source_row_key",_row_key(selected) if not selected.is_empty() else "")
    # A collapsed (unseen) phase has no inverse timestamp. Preserve the causal
    # coordinate while the selected occurrence and displayed instant are held.
    if not previous.is_empty() and is_equal_approx(at_ms,previous.get("mapped_time_ms",-1.0)):
        if key==previous.get("row_key","") or (selected.is_empty() and not previous.get("event_key","").is_empty()):return previous.duplicate()
    var chosen=selected
    if chosen.is_empty() or at_ms<chosen.start_ms or at_ms>chosen.end_ms:
        chosen={}
        for event in _event_rows(index).values():
            if event.end_ms<=event.start_ms or at_ms<event.start_ms or at_ms>=event.end_ms:continue
            if chosen.is_empty() or event.end_ms-event.start_ms<chosen.end_ms-chosen.start_ms:chosen=event
        key=_row_key(chosen) if not chosen.is_empty() else ""
    var duration:float=chosen.get("end_ms",at_ms)-chosen.get("start_ms",at_ms)
    var phase=clampf((at_ms-chosen.start_ms)/duration,0,1) if duration>0 else 0.0
    var group_id:String=chosen.get("group_id","")
    var event_id=_row_event(chosen)
    if group_id.is_empty() and _event_rows(index).has(event_id):group_id=_event_rows(index)[event_id].group_id
    var group_position=-1
    for n in index.groups.size():
        if index.groups[n].group.id==group_id:group_position=n;break
    var boundaries=[]
    if group_position>=0:
        for n in range(group_position,-1,-1):boundaries.append({"id":_group_key(index,str(index.groups[n].group.id)),"side":"start" if n==group_position else "end"})
        for n in range(group_position+1,index.groups.size()):boundaries.append({"id":_group_key(index,str(index.groups[n].group.id)),"side":"start"})
    return {"row_key":key,"event_uuid":event_id,"phase":phase,"group_id":group_id,"boundaries":boundaries,
        "event_key":_row_cause(chosen),
        "condition_uuid":chosen.get("owner",{}).get("id",""),"row_kind":chosen.get("source_kind",chosen.get("kind","")),
        "interval_causes":chosen.get("correspondence_causes",chosen.get("interval_causes",[])),
        "source_time_ms":at_ms,"mapped_time_ms":at_ms}

static func anchor_time(index:Dictionary,anchor:Dictionary) -> float:
    # Use only actual audience rows, never union inspector placeholders.
    for row in index.rows:
        if not row.get("visible_here",true) or row.kind=="perspective":continue
        if _row_key(row)==anchor.row_key:
            return lerpf(row.start_ms,row.end_ms,anchor.phase)
    var events=_clock_rows(index)
    # An absent span is not another span with the same material/layer name.
    # A shared recorded cause can still locate its actual commit boundary.
    for cause in anchor.get("interval_causes",[]):
        if not cause.begins_with("event:") or not events.has(cause.trim_prefix("event:")):continue
        for marker in events[cause.trim_prefix("event:")].get("markers",[]):
            if marker.kind=="commit":return marker.at_ms
    if anchor.row_kind in ["condition","condition_exit"] and not anchor.condition_uuid.is_empty():
        for row in index.rows:
            if row.get("visible_here",true) and row.kind==anchor.row_kind and row.get("owner",{}).get("id")==anchor.condition_uuid:
                return lerpf(row.start_ms,row.end_ms,anchor.phase)
    if events.has(anchor.get("event_key","")):
        var event:Dictionary=events[anchor.event_key]
        return lerpf(event.start_ms,event.end_ms,anchor.phase)
    var groups={}
    for item in index.groups:groups[_group_key(index,str(item.group.id))]=item
    for boundary in anchor.boundaries:
        if groups.has(boundary.id):
            var item:Dictionary=groups[boundary.id]
            return item.start_ms+(item.group.duration_ms if boundary.side=="end" else 0.0)
    return clampf(anchor.source_time_ms,0,index.get("presentation_end_ms",index.duration_ms))

static func _same_clock(a: Dictionary,b: Dictionary) -> bool:
    return is_equal_approx(a.end_ms-a.start_ms,b.end_ms-b.start_ms)

static func switch_time(source: Dictionary, target: Dictionary, at_ms: float, selected: Dictionary={},anchor:Dictionary={}) -> float:
    # An audience can omit an animation altogether. Synchronize by the shared
    # event and authored phase, never by audience-local packet numbers or by
    # assuming identical elapsed seconds represent the same cause.
    if not anchor.is_empty():return anchor_time(target,anchor)
    if not selected.is_empty():return anchor_time(target,navigation_anchor(source,at_ms,selected))
    var source_events=_clock_rows(source)
    var target_events=_clock_rows(target)
    var chosen:Dictionary={}
    var selected_event=_row_cause(selected)
    if source_events.has(selected_event) and target_events.has(selected_event):
        var event:Dictionary=source_events[selected_event]
        if at_ms>=event.start_ms and at_ms<=event.end_ms:chosen=event
    if chosen.is_empty():
        for event in source_events.values():
            if not target_events.has(_row_cause(event)):continue
            if event.end_ms<=event.start_ms or at_ms<event.start_ms or at_ms>=event.end_ms:continue
            if chosen.is_empty() or event.end_ms-event.start_ms<chosen.end_ms-chosen.start_ms:chosen=event
    if not chosen.is_empty():
        var destination:Dictionary=target_events[_row_cause(chosen)]
        var duration:float=chosen.end_ms-chosen.start_ms
        var phase=clampf((at_ms-chosen.start_ms)/duration,0,1) if duration>0 else 0.0
        return lerpf(destination.start_ms,destination.end_ms,phase)
    var target_groups={}
    for item in target.groups:target_groups[_group_key(target,str(item.group.id))]=item
    var previous:Dictionary={}
    for item in source.groups:
        var key:String=_group_key(source,str(item.group.id))
        if not target_groups.has(key):continue
        var destination:Dictionary=target_groups[key]
        if at_ms>=item.start_ms:
            previous={"source":item,"target":destination}
        if item.group.duration_ms>0 and at_ms>=item.start_ms and at_ms<item.start_ms+item.group.duration_ms:
            return destination.start_ms+destination.group.duration_ms*(at_ms-item.start_ms)/item.group.duration_ms
    if not previous.is_empty():
        var elapsed=maxf(0,at_ms-previous.source.start_ms-previous.source.group.duration_ms)
        return minf(target.get("presentation_end_ms",target.duration_ms),previous.target.start_ms+previous.target.group.duration_ms+elapsed)
    return clampf(at_ms,0,target.get("presentation_end_ms",target.duration_ms))

static func _row_key(row: Dictionary) -> String:
    if row.kind=="event":return "event:"+_row_cause(row)
    if row.has("owner"):
        return "condition:%s:%s:%s:%s:%s:%s"%[row.owner.id,row.kind,row.get("source",""),row.label,
            row.get("condition_phase",""),JSON.stringify(row.get("correspondence_causes",row.get("interval_causes",[])))]
    if row.kind=="condition_state":return "condition_state:"+str(row.get("correspondence_view",""))+":"+row.parent+":"+JSON.stringify(row.get("correspondence_causes",row.get("interval_causes",[])))
    if _row_cause(row).is_empty():return "row:"+str(row.get("correspondence_view",""))+":"+row.id
    var data:Dictionary=row.get("track",row.get("component",{}))
    return "%s:%s:%s:%s:%s:%s"%[_row_cause(row),row.kind,row.get("source",""),row.label,data.get("actor_uuid",""),row.get("slot","")]

static func view_index(bundle: Dictionary, perspective_id: String) -> Dictionary:
    if not bundle.views.has(perspective_id):return {"ok":false,"error":"Unknown recorded faction: "+perspective_id}
    if bundle.get("comparison",false):return _comparison_view_index(bundle,perspective_id)
    var original:Dictionary=bundle.views[perspective_id]
    var result:Dictionary=original.duplicate()
    result.rows=[]
    result.perspectives=bundle.perspectives
    result.clock_events=_event_rows(original)
    var keys={}
    var selected_events=_clock_rows(original)
    for row in original.rows:
        var shown:Dictionary=row.duplicate()
        shown.visible_here=true;shown.source_perspective=perspective_id
        shown.source_row_key=_row_key(row)
        shown.audiences=[perspective_id]
        result.rows.append(shown);keys[_row_key(row)]=shown
    for perspective in bundle.perspectives:
        if perspective.id==perspective_id:continue
        var other:Dictionary=bundle.views[perspective.id]
        var other_events=_clock_rows(other)
        var by_id={}
        for source_row in other.rows:by_id[source_row.id]=source_row
        var id_map={}
        # Translate row parents by semantic identity, not by the audience-local
        # sequence prefix. All undisclosed scaffolding remains raw metadata.
        for row in other.rows:
            var key=_row_key(row)
            id_map[row.id]=keys[key].id if keys.has(key) else "view:"+str(perspective.id)+":"+row.id
        for row in other.rows:
            var key=_row_key(row)
            if keys.has(key):
                var existing:Dictionary=keys[key]
                if not perspective.id in existing.audiences:existing.audiences.append(perspective.id)
                if row.kind=="event" and existing.event.kind=="undisclosed" and row.event.kind!="undisclosed":
                    existing.label=row.label+" · "+perspective.label
                    existing.recorded_other_event=row.event
                    existing.source_perspective=perspective.id;existing.visible_here=false
                continue
            if row.kind=="event" and row.event.kind in ["undisclosed","sensory","spatial","turn"]:continue
            var shown:Dictionary=row.duplicate()
            shown.id=id_map[row.id];shown.parent=id_map.get(row.parent,"")
            # A parent may itself be raw metadata omitted above. Retain its
            # nearest actual ancestor so a known effect never becomes an
            # anonymous top-level orphan.
            var parent:String=row.parent
            while by_id.has(parent):
                var ancestor:Dictionary=by_id[parent]
                if keys.has(_row_key(ancestor)) or (ancestor.kind!="event" or ancestor.event.kind not in ["undisclosed","sensory","spatial","turn"]):break
                parent=ancestor.parent
            shown.parent=id_map.get(parent,"")
            shown.source_perspective=perspective.id;shown.visible_here=false;shown.audiences=[perspective.id]
            shown.source_row_id=row.id
            shown.source_row_key=_row_key(row)
            shown.source_interval={"start_ms":row.start_ms,"end_ms":row.end_ms}
            shown.label=row.label+" · "+perspective.label
            var event_id=_row_cause(row)
            var exact=selected_events.has(event_id) and other_events.has(event_id) and _same_clock(selected_events[event_id],other_events[event_id])
            if exact:
                var shift:float=selected_events[event_id].start_ms-other_events[event_id].start_ms
                shown.start_ms=row.start_ms+shift;shown.end_ms=row.end_ms+shift
            else:
                shown.start_ms=switch_time(other,original,row.start_ms,row);shown.end_ms=shown.start_ms
                shown.timing_status="other_perspective"
            if row.kind!="event":
                shown.source_kind=row.kind;shown.kind="other_view"
                shown.reason="Recorded in "+perspective.label+"; select that faction to inspect its presentation. "+str(row.get("reason",""))
            result.rows.append(shown);keys[key]=shown
    result.inspection_scope="Combined recorded factions; executable state remains "+perspective_id
    _split_views(result,bundle,perspective_id)
    return result

static func _comparison_view_index(bundle:Dictionary,selected_id:String)->Dictionary:
    var result:Dictionary=bundle.views[selected_id].duplicate();result.rows=[]
    result.perspectives=bundle.perspectives;result.comparison=true
    result.clock_events=_event_rows(bundle.views[selected_id])
    var events={};var signatures={};var owners={};var by_view={};var split={};var native_events={}
    for perspective in bundle.perspectives:
        var id:String=perspective.id;var view:Dictionary=bundle.views[id]
        native_events[id]=_clock_rows(view)
        signatures[id]=_event_signatures(view);owners[id]=_row_owners(view);by_view[id]={}
        for row in view.rows:
            by_view[id][row.id]=row
            if row.kind!="event":continue
            var uuid:String=_row_cause(row)
            if not events.has(uuid) or (events[uuid].event.kind=="undisclosed" and row.event.kind!="undisclosed"):
                var shown:Dictionary=row.duplicate();shown.id="comparison:event:"+uuid
                shown.source_perspective=id;shown.source_row_id=row.id;shown.visible_here=true;events[uuid]=shown
    for uuid in events:
        var first:Variant=null;var differs=false
        for perspective in bundle.perspectives:
            var signature:Dictionary=signatures[perspective.id].get(uuid,{"kind":"not_disclosed","components":[]})
            if first==null:first=signature
            elif first!=signature:differs=true
        split[uuid]=differs
        var row:Dictionary=events[uuid]
        var source:Dictionary=by_view[row.source_perspective]
        var parent:Dictionary=source.get(row.parent,{})
        row.parent="comparison:event:"+_row_cause(parent) if parent.get("kind")=="event" else ""
        row.split_views=differs;result.rows.append(row)
    var mapped={};var shared={};var faction_rows={}
    for perspective in bundle.perspectives:
        var id:String=perspective.id;mapped[id]={}
        for row in bundle.views[id].rows:
            if row.kind=="event":mapped[id][row.id]="comparison:event:"+_row_cause(row);continue
            var uuid:String=owners[id].get(row.id,"")
            var differs:bool=split.get(uuid,true)
            var key:String=_row_key(row)
            if not differs and shared.has(key):
                mapped[id][row.id]=shared[key].id;shared[key].audiences.append(id);continue
            var shown:Dictionary=row.duplicate()
            shown.id="comparison:"+id+":"+row.id;mapped[id][row.id]=shown.id
            shown.source_row_id=row.id;shown.source_perspective=id;shown.source_row_key=key
            shown.visible_here=true;shown.audiences=[id]
            if not differs:shared[key]=shown
            elif not uuid.is_empty():
                var faction_id="comparison:event:"+uuid+":view:"+id
                if not faction_rows.has(faction_id):
                    faction_rows[faction_id]={"id":faction_id,"parent":"comparison:event:"+uuid,"kind":"perspective","label":perspective.label,
                        "start_ms":events[uuid].start_ms,"end_ms":events[uuid].end_ms,"status":"state_only","source_perspective":id,
                        "source_event_uuid":native_events[id].get(uuid,{}).get("event",{}).get("event_uuid",""),"correspondence_event_key":uuid,"visible_here":true,"disclosed":true,"comparison":true}
            result.rows.append(shown)
    for row in result.rows:
        if row.kind=="event":continue
        var id:String=row.source_perspective;var original:Dictionary=by_view[id][row.source_row_id]
        var uuid:String=owners[id].get(original.id,"")
        var parent:Dictionary=by_view[id].get(original.parent,{})
        if parent.get("kind")=="event" and split.get(uuid,false):row.parent="comparison:event:"+uuid+":view:"+id
        else:row.parent=mapped[id].get(original.parent,"")
    result.rows.append_array(faction_rows.values())
    result.inspection_scope="Common causal schedule; independent recorded source rows for both displayed factions"
    return result

static func _event_signatures(index:Dictionary)->Dictionary:
    var by_id={};var result={}
    for row in index.rows:by_id[row.id]=row
    for row in index.rows:
        if row.kind!="event":continue
        result[_row_cause(row)]={"kind":row.event.kind,"name":row.label,"perception":row.get("perception",{}),"components":[]}
    for row in index.rows:
        if row.kind=="event":continue
        var parent:String=row.parent
        while by_id.has(parent) and by_id[parent].kind!="event":parent=by_id[parent].parent
        if not by_id.has(parent):continue
        var event:Dictionary=by_id[parent]
        # Only presentation/requirement differences split a shared event; local
        # sequence numbers, packet cursors and inspection row IDs do not.
        result[_row_cause(event)].components.append([row.kind,row.label,row.get("source",""),row.get("status",""),row.start_ms-event.start_ms,row.end_ms-row.start_ms])
    return result

static func _row_owners(index:Dictionary)->Dictionary:
    var by_id={};var result={}
    for row in index.rows:by_id[row.id]=row
    for row in index.rows:
        if row.kind=="event":continue
        var parent:String=row.parent
        while by_id.has(parent) and by_id[parent].kind!="event":parent=by_id[parent].parent
        if by_id.has(parent):result[row.id]=_row_cause(by_id[parent])
    return result

static func _split_views(index:Dictionary,bundle:Dictionary,selected_id:String)->void:
    var signatures={};var native_events={}
    for id in bundle.views:
        signatures[id]=_event_signatures(bundle.views[id]);native_events[id]=_clock_rows(bundle.views[id])
    var split_events={}
    var event_rows={}
    var additions=[]
    for row in index.rows:
        if row.kind!="event":continue
        var event_id:String=_row_cause(row)
        var first:Variant=null
        var differs=false
        for perspective in bundle.perspectives:
            var signature:Dictionary=signatures[perspective.id].get(event_id,{"kind":"not_disclosed","components":[]})
            if first==null:first=signature
            elif signature!=first:differs=true
        if not differs:continue
        split_events[row.id]=true
        event_rows[event_id]=row
        row.split_views=true
        for perspective in bundle.perspectives:
            var signature:Dictionary=signatures[perspective.id].get(event_id,{"kind":"not_disclosed","components":[]})
            var disclosed=signature.kind not in ["not_disclosed","undisclosed"]
            var label:String=perspective.label+(" · no event detail" if not disclosed else "")
            additions.append({"id":row.id+":view:"+str(perspective.id),"parent":row.id,"kind":"perspective","label":label,
                "start_ms":row.start_ms,"end_ms":row.end_ms,"status":"state_only","source_perspective":perspective.id,
                "visible_here":perspective.id==selected_id,"perception":signature.get("perception",{}),
                "source_event_uuid":native_events[perspective.id].get(event_id,{}).get("event",{}).get("event_uuid",""),"correspondence_event_key":event_id,"disclosed":disclosed,"reason":"Independent recorded view of this same disclosed cause"})
    for row in index.rows:
        if row.kind=="event" or not split_events.has(row.parent):continue
        row.parent=row.parent+":view:"+str(row.get("source_perspective",selected_id))
    # Differences belong side by side under the SAME occurrence. A common
    # component deduplicated by the union still needs its own inspection row
    # when the surrounding faction composition is different.
    for perspective in bundle.perspectives:
        if perspective.id==selected_id:continue
        var other:Dictionary=bundle.views[perspective.id]
        var owners=_row_owners(other)
        var existing={}
        for row in index.rows:
            if row.get("source_perspective")==perspective.id and row.has("source_row_id"):existing[row.source_row_id]=row
        var translated={}
        for row in other.rows:
            if not event_rows.has(owners.get(row.id,"")):continue
            translated[row.id]=existing[row.id].id if existing.has(row.id) else "view:"+str(perspective.id)+":"+row.id
        for row in other.rows:
            var event_id:String=owners.get(row.id,"")
            if not event_rows.has(event_id):continue
            var parent:String=translated.get(row.parent,event_rows[event_id].id+":view:"+str(perspective.id))
            if existing.has(row.id):existing[row.id].parent=parent;continue
            var shown:Dictionary=row.duplicate()
            shown.id=translated[row.id];shown.parent=parent;shown.source_row_id=row.id
            shown.source_row_key=_row_key(row)
            shown.source_kind=row.kind;shown.kind="other_view"
            shown.source_perspective=perspective.id;shown.visible_here=false;shown.audiences=[perspective.id]
            shown.source_interval={"start_ms":row.start_ms,"end_ms":row.end_ms}
            shown.start_ms=event_rows[event_id].start_ms;shown.end_ms=shown.start_ms
            shown.timing_status="other_perspective"
            shown.reason="Recorded in "+perspective.label+"; select this view for its source timing and presentation. "+str(row.get("reason",""))
            additions.append(shown)
    index.rows.append_array(additions)

static func _missing_rows(rows: Array, parent: Dictionary, requirements: Array, offset: float)->void:
    # Requirements come from authoring even when no executable component exists.
    # A default trace time of zero is not evidence of an authored schedule.
    for n in requirements.size():
        var requirement:Dictionary=requirements[n]
        if requirement.status!="missing" or not str(requirement.get("trace_track_id","")).is_empty():continue
        var timing:Dictionary=requirement.get("timing",{})
        var resolved:bool=timing.get("resolved",false)
        var start:float=offset+float(timing.start_ms) if resolved else parent.start_ms
        var end:float=offset+float(timing.end_ms) if resolved else start
        var name:String=str(requirement.get("label",requirement.get("authored_id",requirement.kind)))
        var gap:String=requirement.get("gap_kind","source" if requirement.get("availability")=="missing" else "renderer")
        var implementation:String=requirement.get("implementation","missing" if gap=="renderer" else "unassessed")
        var inspection:String=requirement.get("inspection","missing" if gap=="inspection" else "unassessed")
        var caption="Unassessed" if gap=="unassessed" else "Missing inspection" if gap=="inspection" else "Missing"
        rows.append({"id":parent.id+":required:"+str(n),"parent":parent.id,"kind":"requirement",
            "required_kind":requirement.kind,"label":caption+" · "+name,"status":"missing","gap_kind":gap,
            "missing_category":"implementation" if gap=="renderer" else gap,"reason":requirement.get("reason","Unresolved presentation requirement"),
            "source":requirement.get("source_pointer",requirement.get("source","")),"requirement":requirement,"group_id":parent.group_id,
            "source_event_uuid":parent.event.event_uuid,"start_ms":start,"end_ms":end,
            "timing_status":"authored" if resolved else "unresolved",
            "timing_reason":timing.get("reason","No resolved authored timing; occurrence anchor only"),
            "coverage":{"implementation":implementation,"inspection":inspection,"source":requirement.get("availability","not_examined"),"prepared":"not_prepared","rendered":"not_rendered"}})

static func _condition_missing_rows(rows:Array,parent:Dictionary,requirements:Array)->void:
    for n in requirements.size():
        var requirement:Dictionary=requirements[n]
        if requirement.status!="missing":continue
        # A resolved material span already reports this method's missing source
        # or implementation. Keep only expectations with no such actual span.
        if rows.any(func(row):return row.parent==parent.id and row.kind=="condition_material" and row.get("mechanism")==requirement.mechanism and row.source==requirement.source):continue
        var owner:Dictionary=parent.owner
        var removal:bool=requirement.phase=="removal" or requirement.source.ends_with("/removal_asset_id") or requirement.source.ends_with("/removal_mask_asset_id")
        var application:bool=requirement.phase=="application" or requirement.source.ends_with("/application_asset_id")
        var witnessed:bool=not is_inf(owner.end_ms) if removal else (not owner.initial if application else true)
        var anchor:float=owner.end_ms if removal and witnessed else parent.start_ms
        var reason="Authored condition component timing is unresolved"
        if removal and not witnessed:reason="Removal is not in this recording; authored expectation only"
        elif application and not witnessed:reason="Condition is already active in initialization; application was not witnessed"
        rows.append({"id":parent.id+":required:"+str(n),"parent":parent.id,"kind":"requirement",
            "required_kind":requirement.mechanism,"label":"Missing · "+requirement.mechanism,
            "owner":owner,"status":"missing","missing_category":"authoring" if requirement.get("gap_kind","") in ["authoring_assignment","authoring_review"] else ("implementation" if requirement.implementation=="missing" else "source"),
            "source":requirement.source,"reason":requirement.reason,"requirement":requirement,
            "start_ms":anchor,"end_ms":anchor,"timing_status":"unresolved","timing_reason":reason,
            "phase_witnessed":witnessed,"coverage":{"implementation":requirement.implementation,"source":requirement.availability,"prepared":"not_prepared","rendered":"not_rendered"}})

static func _condition_cause(event: String,owner_id:String)->String:
    return "event:"+event.get_slice(":",event.get_slice_count(":")-1) if not event.is_empty() else "initial:"+owner_id

static func _condition_rows(rows: Array, parent: Dictionary, owner: Dictionary, intervals: Array, states: Array, cache: Dictionary, tracks: Array=[], requirements:Array=[])->void:
    # Index the same passive samples the live renderer receives. Each interval
    # keeps its true source age; suppression never invents an executing layer.
    var spans:Array=[]
    for interval in intervals:
        var start=maxf(parent.start_ms,interval.start_ms)
        var end=minf(parent.end_ms,interval.end_ms)
        if interval.suppressed or end<=start:continue
        var boundaries=[start];var previous={}
        var causes={start:[_condition_cause(interval.get("source_event",""),owner.id)]}
        for state in states:
            if state.at_ms>=end:break
            var changed=previous.is_empty() or previous.condition_owners!=state.condition_owners or previous.pose_owner!=state.pose_owner
            if state.at_ms>start and changed:
                if state.at_ms not in boundaries:boundaries.append(state.at_ms)
                if not causes.has(state.at_ms):causes[state.at_ms]=[]
                var cause=_condition_cause(state.get("source_event_uuid",""),owner.id)
                if cause not in causes[state.at_ms]:causes[state.at_ms].append(cause)
            for other in state.condition_owners.values():
                var expiry:float=other.end_ms+Timeline.Conditions.fade_ms(other.condition,cache)
                if expiry>start and expiry<end:
                    if expiry not in boundaries:boundaries.append(expiry)
                    if not causes.has(expiry):causes[expiry]=[]
                    var cause="expiry:"+str(other.id)
                    if cause not in causes[expiry]:causes[expiry].append(cause)
            previous=state
        # A condition pose executes only between actual body-track changes;
        # action tracks retain precedence over the condition's resting pose.
        for track in tracks:
            for at in [track.start_ms,track.start_ms+track.duration_ms,track.group_end_ms]:
                if at>start and at<end and at not in boundaries:
                    boundaries.append(at);causes[at]=["track:"+str(track.get("trace_track_id",track.get("source_event_uuid","")))]
        # Each package lifecycle's application ends inside the owner's span.
        if not owner.initial:
            for selection in NativePersistent.lifecycles(owner.condition):
                var at:float=owner.start_ms+float(NativePersistent.Effects.clip(str(selection.condition.phases.application)).get("seconds",0.0))*1000.0
                if at>start and at<end and at not in boundaries:boundaries.append(at);causes[at]=["lifecycle:application_end"]
        boundaries.append(end);boundaries.sort()
        for i in boundaries.size()-1:
            causes[boundaries[i]].sort()
            spans.append({"start_ms":boundaries[i],"end_ms":boundaries[i+1],"causes":causes[boundaries[i]]})
    for n in spans.size():
        var start:float=spans[n].start_ms
        var end:float=spans[n].end_ms
        var sampled_owner:Dictionary=owner.duplicate()
        var sampled_owners={owner.id:sampled_owner}
        var pose_state={}
        for state in states:
            if state.at_ms>start:break
            sampled_owners=state.condition_owners.duplicate();pose_state=state
            if sampled_owners.has(owner.id):sampled_owner=sampled_owners[owner.id].duplicate()
        sampled_owner.end_ms=owner.end_ms
        sampled_owners[owner.id]=sampled_owner
        var selected_pose={};var pose_activity="idle"
        var bodies=Compiler.Tracks.samples(tracks.filter(func(track):return start<track.group_end_ms),start)
        var body:Dictionary=bodies.get(owner.actor_uuid,{})
        if not pose_state.is_empty():
            var pose_actor:Dictionary=pose_state.pose_actor
            var held_pose:Dictionary=ConditionPose.select(pose_actor,pose_state.actor.rig,"idle",cache,sampled_owners)
            if body.is_empty() or held_pose.get("captured",false):
                selected_pose=held_pose
            else:
                pose_activity=body.get("activity","")
                # The compiler selected this pose from its event-time actor;
                # presentation_actor deliberately omits condition ownership.
                selected_pose=body.get("condition_pose",{})
        var samples=Timeline.Conditions.samples(sampled_owners,start,cache,{},false)
        var selected=Timeline.Conditions.select_recipes(owner.actor_uuid,samples)
        var material_selected=selected.any(func(sample):return sample.condition_uuid==owner.id)
        samples=samples.filter(func(sample):return sample.get("condition_uuid")==owner.id or (sample.kind=="audio" and sample.id.begins_with("condition:"+owner.id+":")))
        var prefix:String=parent.id+":member:"+str(n)+":"
        for sample in samples:
            var sample_end:float=end
            if sample.has("lifecycle_phases") and not is_inf(owner.end_ms):
                sample_end=minf(end,float(owner.end_ms)+float(sample.lifecycle_phases.removal.seconds)*1000.0)
                if sample_end<=start:continue
            var common={"parent":parent.id,"start_ms":start,"end_ms":end,"owner":sampled_owner,
                "component":sample,"source":sample.source,"status":sample.status,"source_fps":sample.get("sample_hz",0),
                "condition_phase":parent.kind,"interval_causes":spans[n].causes,
                "source_start_ms":sample.get("absolute_start_ms",sample.start_ms)}
            if sample.kind=="condition":
                for appearance in Appearance.components(sampled_owners,start,cache):
                    if owner.id not in appearance.layer.condition_uuids:continue
                    var source:String=Compiler.Authoring.Catalog.source_pointer("catalog/condition_recipes.json",owner.condition.behavior_id+"/persistent/appearanceLayers",cache)
                    var component:Dictionary=appearance.merged({"id":"condition:"+owner.id+":appearance:"+str(appearance.layer.id),
                        "source":source,"start_ms":owner.start_ms,"duration_ms":end-start,"status":"available"},true)
                    rows.append(common.merged({"id":prefix+"appearance:"+str(appearance.layer.id),"kind":"condition_appearance",
                        "label":"Appearance · "+str(appearance.layer.category),"component":component,
                        "trace_track_id":component.id,"source":source,"recipient_uuid":owner.actor_uuid,
                        "render_method":{"renderer":"res://presentation/condition_appearance.gd","surface":"actual outfit","pose":"current body clip/frame/facing","opacity":"Factory lifecycle lease"},
                        "preview_scope":"appearance_asset_current_pose","diagnostic_scope":"condition_owner"},true))
                var persistent:Dictionary=sample.recipe.get("persistent",{})
                var operations={}
                var scale:Dictionary=Timeline.Conditions.scale_operation(sample)
                if not scale.is_empty():operations.bodyScale=scale
                for field in ["bodyColor","bodyRamp","bodyOutline"]:
                    if persistent.get(field)!=null and not persistent[field].is_empty():operations[field]=persistent[field]
                if persistent.get("alphaMultiplier",1.0)!=1.0:operations.alphaMultiplier=persistent.alphaMultiplier
                if material_selected and not operations.is_empty():
                    for field in operations:
                        var source=Compiler.Authoring.Catalog.source_pointer("catalog/condition_recipes.json",owner.condition.behavior_id+"/persistent/"+field,cache)
                        var requirement:Dictionary={}
                        for candidate in requirements:
                            if candidate.mechanism==field and candidate.source==source:requirement=candidate;break
                        var missing:bool=requirement.get("status")=="missing"
                        var method:Dictionary=MATERIAL_METHODS[field]
                        var material=common.duplicate();material.merge({"id":prefix+"material:"+field,"kind":"condition_material","label":method.label,
                            "mechanism":field,"operations":{field:operations[field]},"source_fields":{field:source},"source":source,
                            "trace_track_id":"condition:"+owner.id+":"+field,
                            "legacy_source":requirement.get("legacy_source","catalog/condition_recipes.json:/"+owner.condition.behavior_id+"/persistent/"+field),
                            "recipient_uuid":owner.actor_uuid,"render_method":method,"preview_scope":"composed_actor","diagnostic_scope":"condition_owner",
                            "status":"missing" if missing else sample.status,"reason":requirement.get("reason",""),
                            "missing_category":("implementation" if requirement.get("implementation")=="missing" else "source") if missing else "",
                            "coverage":{"implementation":requirement.get("implementation","not_examined"),"source":requirement.get("availability","not_examined"),"prepared":"not_examined","rendered":"not_witnessed"}},true)
                        if field=="bodyScale":material.label="Body scale × "+String.num(scale.factor,3)
                        rows.append(material)
                if selected_pose.get("condition_uuid")==owner.id:
                    var pose=common.duplicate();pose.merge({"id":prefix+"pose","kind":"condition_pose","label":("Captured · "+selected_pose.clip+" · frame "+str(selected_pose.frame)) if selected_pose.get("captured",false) else pose_activity.capitalize()+" · "+selected_pose.clip,
                        "pose":selected_pose if selected_pose.legacy_source.contains("/activityPoses/") else persistent.get("frozenPose",persistent.get("bodyPose")),
                        "selected_pose":selected_pose,"source_fps":Compiler.Authoring.rigs(cache)[pose_state.actor.rig].clips[selected_pose.clip].fps,"activity":pose_activity,"source":selected_pose.source,"legacy_source":selected_pose.legacy_source},true)
                    rows.append(pose)
            else:
                var component=common.duplicate()
                component.end_ms=sample_end
                if sample.has("layer"):component.selection_policy="sampled"
                component.merge({"id":prefix+sample.id,"kind":sample.kind,"trace_track_id":sample.id,
                    "label":str(sample.native_cue.role).capitalize() if sample.get("native_spell",false) else str(sample.get("cue_id",sample.get("layer",{}).get("id",sample.get("source_id",sample.kind)))),
                    "coverage":{"implementation":"resolved","source":sample.status,"prepared":"not_examined","rendered":"not_witnessed"}})
                if sample.has("lifecycle_phases"):
                    # One occurrence plays all three phases; each span names its phase's clip.
                    var phase:String=NativePersistent.lifecycle_state(sample,(start-float(sample.absolute_start_ms))/1000.0).phase
                    component.lifecycle_phase=phase;component.effect_clip=str(sample.lifecycle_phases[phase].id)
                    component.label=phase.capitalize()+" · "+component.effect_clip
                elif sample.get("condition_authored",false):
                    component.label="Hold · "+str(sample.recipe.get("label",sample.condition.behavior_id))
                    component.effect_clip=str(sample.native_clip.get("id",""))
                    component.reason=sample.get("reason","")
                rows.append(component)
                if sample.get("native_spell",false):_persistent_native_channels(rows,component,sample)

static func _persistent_native_channels(rows:Array,parent:Dictionary,sample:Dictionary)->void:
    # These are inspection children of the same sampled owner, never a second
    # light/material scheduler. UI spans may split; the source clock does not.
    for channel in NativeChannels.channels(sample):
        var row=parent.duplicate(false)
        row.merge({"id":parent.id+":"+channel.id.trim_prefix(sample.id+":"),"parent":parent.id,
            "kind":channel.kind,"label":channel.label,"component":channel,"trace_track_id":channel.id,
            "source":channel.source,"status":channel.status,"reason":channel.get("reason",""),
            "render_method":channel.render_method,"preview_scope":channel.get("preview_scope","source_property_keys"),
            "markers":NativeChannels.markers(channel,0.0).filter(func(marker):return marker.at_ms>=parent.start_ms and marker.at_ms<=parent.end_ms),"source_clock":sample.native_cue,
            "coverage":{"implementation":"resolved","source":channel.status,"prepared":"not_examined","rendered":"not_witnessed"}},true)
        # Keys follow the actual native entry/held-pose/close mapping. They are
        # source property changes, not invented gameplay illumination curves.
        rows.append(row)

static func _observe_spatial_history(history:Dictionary,owners:Dictionary,effects:Dictionary,at_ms:float,event_uuid:String,initial:bool=false,rows:Array=[])->void:
    NativePersistent.observe_spatial(owners,effects,at_ms,initial,rows)
    for id in owners:
        var owner:Dictionary=owners[id]
        if not history.has(id):history[id]={"source_event_uuid":event_uuid,"keys":[]}
        var keys:Array=history[id].keys
        if not keys.is_empty() and keys.back().owner==owner:continue
        keys.append({"at_ms":at_ms,"source_event_uuid":event_uuid,"owner":owner.duplicate(true)})

static func _spatial_presentation(effect:Dictionary,cache:Dictionary)->Dictionary:
    # Match the existing production sampler's three source arms. A typed held
    # source needs neither a spell handover nor a package condition lifecycle.
    var selected:Dictionary=NativePersistent.spatial_selection(effect,cache)
    var lifecycles:Array=NativePersistent.spatial_lifecycles(effect)
    var identity:String=NativePersistent.SpatialInputs.content_id(effect)
    var config:Dictionary=Compiler.Authoring.load_data("catalog/condition_recipes.json",cache).get(identity,{})
    var authored:Array=NativePersistent.authored_phases(config,identity,cache) if not config.get("persistent",{}).get("nativeEffects",[]).is_empty() else []
    var close_ms:float=NativePersistent.removal_ms(lifecycles) if not lifecycles.is_empty() else NativePersistent.fade_ms(selected)
    return {"selected":selected,"eligible":not selected.is_empty() or not lifecycles.is_empty() or not authored.is_empty(),
        "close_ms":maxf(close_ms,NativePersistent.authored_removal_ms(config))}

static func _spatial_rows(index:Dictionary,history:Dictionary,owners:Dictionary,events:Dictionary)->void:
    # Record the disclosed after-values once. The same NativePersistent sampler
    # used by Timeline owns source age, footprint and actual removal behavior.
    for id in history:
        var owner:Dictionary=owners[id]
        var presentation:Dictionary=_spatial_presentation(owner.effect,index.cache)
        if not presentation.eligible:continue
        var selected:Dictionary=presentation.selected
        var end=minf(index.presentation_end_ms,float(owner.end_ms)+presentation.close_ms)
        var life={"id":"spatial:"+str(id),"parent":events.get(history[id].source_event_uuid,""),
            "kind":"spatial_effect","label":str(owner.effect.get("name",selected.get("id",owner.effect.get("content_ref",{}).get("content_id","")))),
            "start_ms":owner.start_ms,"end_ms":end,"owner":owner,
            "source":"PlayerState.senses.spatial_effects/"+str(id),"status":"available",
            "timing_source":"Actual disclosed spatial-effect membership and after-values"}
        index.rows.append(life)
        var keys:Array=history[id].keys
        for n in keys.size():
            var key:Dictionary=keys[n]
            var start:float=key.at_ms
            var interval_end=minf(end,float(keys[n+1].at_ms) if n+1<keys.size() else end)
            if interval_end<=start:continue
            var sampled_owner:Dictionary=key.owner.duplicate()
            sampled_owner.end_ms=owner.end_ms
            for sample in NativePersistent.spatial_samples({id:sampled_owner},start,index.cache):
                # Successful native phases omit a status override; the live
                # renderer admits them unless explicitly missing. Retain that
                # same source status on the private inspection component.
                sample.status=sample.get("status","available")
                var row={"id":life.id+":member:"+str(n)+":"+sample.id,"parent":life.id,
                    "kind":sample.kind,"label":str(sample.native_cue.role).capitalize(),
                    "start_ms":start,"end_ms":interval_end,"source_start_ms":sample.absolute_start_ms,
                    "owner":sampled_owner,"component":sample,"trace_track_id":sample.id,
                    "source":sample.source,"source_fps":sample.sample_hz,"status":sample.status,
                    "interval_causes":["event:"+str(key.source_event_uuid)] if not key.source_event_uuid.is_empty() else ["initial:"+str(id)],
                    "coverage":{"implementation":"resolved","source":sample.status,"prepared":"not_examined","rendered":"not_witnessed"}}
                index.rows.append(row)
                _persistent_native_channels(index.rows,row,sample)

static func _preview_states(output: Dictionary,state: Dictionary,actors: Dictionary,owners: Dictionary,at_ms: float,cache: Dictionary,source_event_uuid:String="")->void:
    for id in actors:
        var actor: Dictionary=actors[id]
        var resolved=Characters.resolve(actor,state,cache)
        if not resolved.ok or resolved.value==null:continue
        var row: Dictionary=resolved.value
        var rig:Dictionary=Compiler.Authoring.rigs(cache)[row.rig]
        var rest=Characters.rest_sample(actor,rig,cache)
        if not rest.ok:continue
        var pose={"rig":row.rig,"clip":rest.value.clip,"source_seconds":rest.value.source_seconds,
            "clock":"fixed" if actor.life_state in ["dead","dying","stable"] else "display"}
        var condition=Timeline.Conditions.pose(actor,row.rig,cache,owners)
        if not condition.is_empty() and rig.clips.has(condition.clip):
            pose.clip=condition.clip;pose.clock="condition"
            pose.condition_pose=condition
            pose.owner_start_ms=owners.get(condition.condition_uuid,{}).get("start_ms",at_ms)
            pose.source_seconds=ConditionPose.source_seconds(condition,rig.clips[pose.clip],at_ms-pose.owner_start_ms)
        pose.fps=rig.clips[pose.clip].fps
        var local_owners={}
        for key in owners:
            if owners[key].actor_uuid==id:local_owners[key]=owners[key].duplicate()
        if not output.has(id):output[id]=[]
        output[id].append({"at_ms":at_ms,"actor":row,"actor_name":actor.get("name",""),"sampled_pose":pose,"pose_owner":condition.get("condition_uuid",""),"pose_actor":{"life_state":actor.life_state,"conditions":actor.get("conditions",[])},"condition_owners":local_owners,"source_event_uuid":source_event_uuid})

static func _observe_condition_history(history: Dictionary, intervals: Dictionary, parents: Dictionary,
        actors: Dictionary, at_ms: float, event: String, initial: bool=false,rows:Array=[],captures:Dictionary={},creation_bindings:Dictionary={})->void:
    # An event's final snapshot can erase an entire transient lifetime or
    # conceal remove/reapply of an equal member. Keep the native row boundaries
    # before reconciling ordinary member/suppression snapshots below.
    for change in rows:
        if change.row.get("field")!="condition":continue
        var member:Variant=change.after if change.after!=null else change.before
        if member==null:continue
        var id:String=member.condition_uuid
        if change.after!=null and change.before==null:
            parents[id]={"event_id":event,"cause_uuid":member.get("event_uuid",""),"initial":false}
            if not intervals.has(id):intervals[id]=[]
            var states:Array=intervals[id]
            if not states.is_empty() and is_inf(states[-1].end_ms):states[-1].end_ms=at_ms
            var condition_state:Dictionary=member.state if member.get("state")!=null else {}
            var providers:Array=condition_state.get("suppression_provider_uuids",[])
            states.append({"start_ms":at_ms,"end_ms":INF,"suppressed":not providers.is_empty(),
                "providers":providers.duplicate(),"source_event":event})
        elif change.after==null:
            var states:Array=intervals.get(id,[])
            if not states.is_empty() and is_inf(states[-1].end_ms):states[-1].end_ms=at_ms
            if parents.has(id):parents[id].removal_event=event
    for actor_id in actors:
        var live={}
        for condition in actors[actor_id].get("conditions",[]):
            var id: String=condition.condition_uuid
            live[id]=true
            if not history.has(id) and not parents.has(id):parents[id]={"event_id":event,"cause_uuid":condition.get("event_uuid",""),"initial":initial}
            if not intervals.has(id):intervals[id]=[]
            var condition_state:Dictionary=condition.state if condition.get("state")!=null else {}
            var providers:Array=condition_state.get("suppression_provider_uuids",[])
            var states: Array=intervals[id]
            if states.is_empty() or states[-1].providers!=providers or not is_inf(states[-1].end_ms):
                if not states.is_empty() and is_inf(states[-1].end_ms):states[-1].end_ms=at_ms
                states.append({"start_ms":at_ms,"end_ms":INF,"suppressed":not providers.is_empty(),
                    "providers":providers.duplicate(),"source_event":event})
        for owner in history.values():
            if owner.actor_uuid==actor_id and not live.has(owner.id) and intervals.has(owner.id):
                var states: Array=intervals[owner.id]
                if not states.is_empty() and is_inf(states[-1].end_ms):states[-1].end_ms=at_ms
                if is_inf(owner.end_ms):parents[owner.id].removal_event=event
    Timeline.Conditions.observe(history,actors,at_ms,initial,rows,captures,creation_bindings)

static func restore(index: Dictionary, target_ms: float, token: Dictionary={}) -> RefCounted:
    var timeline = Timeline.new()
    timeline.appearance_cache=Compiler.Authoring.Catalog.source_snapshot(index.cache)
    var initial: Dictionary = index.initialization.duplicate()
    # Each playback owns mutable state containers. The retained prefix is immutable.
    initial.state = index.initialization.state.duplicate(true)
    timeline.accept(initial)
    var groups: Array = []
    for item in index.groups: groups.append(item.group)
    timeline.accept({"kind":"operation","groups":groups})
    for item in index.groups:
        if canceled(token): return null
        var boundary=minf(target_ms,item.start_ms+item.group.duration_ms)
        if boundary>timeline.display_ms: timeline.advance(boundary-timeline.display_ms)
        if boundary>=target_ms: break
    if canceled(token): return null
    timeline.advance(maxf(0.0,target_ms-timeline.display_ms))
    timeline.paused = true
    return timeline

static func restore_boundary(index:Dictionary,group_index:int,commit_prefix:int,token:Dictionary={})->RefCounted:
    # Diagnostic exact prefix, including several ordered cuts at one clock.
    # This truncated Timeline is for inspection; ordinary playback/seek uses
    # restore() and retains the complete future queue.
    if group_index<0 or group_index>=index.groups.size():return null
    var item:Dictionary=index.groups[group_index]
    if commit_prefix<0 or commit_prefix>item.group.commits.size():return null
    var prefix=index.duplicate();prefix.groups=index.groups.slice(0,group_index)
    var group:Dictionary=item.group.duplicate()
    group.commits=group.commits.slice(0,commit_prefix)
    group.operation_end=group.operation_end and commit_prefix==item.group.commits.size()
    prefix.groups.append({"start_ms":item.start_ms,"group":group})
    var at:float=item.start_ms+(group.commits.back().at_ms if not group.commits.is_empty() else 0.0)
    return restore(prefix,at,token)

static func step_time(index: Dictionary, row: Dictionary, time_ms: float, direction: int) -> float:
    var limit: float=index.get("presentation_end_ms",index.get("duration_ms",0.0))
    if not row.has("track"):
        var hz: float=row.get("source_fps",0)
        return clampf(time_ms+direction*1000.0/(hz if hz>0 else 60.0),0,limit)
    var track: Dictionary=row.track
    if (direction>0 and time_ms>=row.end_ms) or (direction<0 and time_ms<=row.start_ms):
        return clampf(time_ms+direction*1000.0/60.0,0,limit)
    var fps: float=row.get("source_fps",0)
    if fps<=0:
        fps=Compiler.Authoring.rigs(index.cache).get(track.rig,{}).get("clips",{}).get(track.clip,{}).get("fps",0)
    if fps<=0 or track.duration_ms<=0: return clampf(time_ms,0,limit)
    var keys: Array=track.get("source_time_keys",[[0.0,track.source_start_seconds],[1.0,track.source_end_seconds]])
    var fraction=clampf((time_ms-row.start_ms)/track.duration_ms,0,1)
    var current_frame=int(floor(Compiler.Tracks._source_at(keys,fraction)*fps))
    var result: float=row.end_ms if direction>0 else row.start_ms
    for i in range(1,keys.size()):
        var a: Array=keys[i-1];var b: Array=keys[i]
        if a[1]==b[1]: continue # a hold contains no source-frame transitions
        var first=int(ceil(minf(a[1],b[1])*fps))
        var last=int(floor(maxf(a[1],b[1])*fps))
        for frame in range(first,last+1):
            if frame==current_frame: continue
            var f=lerpf(a[0],b[0],inverse_lerp(a[1],b[1],frame/fps))
            var at: float=row.start_ms+f*track.duration_ms
            if direction>0 and at>time_ms+.000001: result=minf(result,at)
            elif direction<0 and at<time_ms-.000001: result=maxf(result,at)
    return clampf(result,0,limit)

## Exact item eligibility intervals; geometry is still sampled by production
## NativeSpellRenderer from the restored canonical stream in the main preview.
static func _observe_item_history(current:Dictionary,spans:Array,owners:Dictionary,state:Dictionary,at_ms:float,event_id:String,cache:Dictionary)->void:
    # Zero-duration ordered membership is inspection evidence, never an
    # optical component or an invented visible lifetime.
    for owner in NativeItems.transient_memberships(owners,at_ms):
        var end_event:String=str(owner.get("end_event_uuid",""))
        if end_event!=event_id.get_slice(":",1):continue
        var id:String=owner.id+":membership:"+str(owner.start_ms)+":"+str(owner.source_event_uuid)+":"+end_event
        if spans.any(func(span):return span.id==id):continue
        spans.append({"id":id,"parent":event_id if not end_event.is_empty() else "","kind":"item_effect_membership","label":"Item effect membership",
            "start_ms":at_ms,"end_ms":at_ms,"source":owner.definition.source,"source_event_uuid":owner.source_event_uuid,
            "item_uuid":owner.item_uuid,"effect_uuid":str(owner.member.effect_uuid),"member":owner.member,
            "status":"state_only","preview_scope":"source_property_keys","preview_status":"not_applicable",
            "coverage":{"implementation":"resolved","source":"explicit_membership","prepared":"not_applicable","rendered":"not_witnessed"}})
    var active:Dictionary={}
    for sample in NativeItems.samples(owners,state,at_ms):
        active[sample.id]=sample
    for id in current.keys():
        if not active.has(id):
            current[id].end_ms=at_ms;current.erase(id)
    for id in active:
        var component:Dictionary=active[id]
        var location:Dictionary=component.item_effect.location
        var signature:Array=[component.status,component.get("reason",""),component.start_ms,location.kind,location.get("holder_uuid",""),location.get("render_slot","")]
        if current.has(id) and current[id].signature==signature:continue
        if current.has(id):current[id].end_ms=at_ms
        var origin:Dictionary=component.item_effect
        var parent:String=event_id
        var row={"id":component.id+":span:"+str(spans.size()),"parent":parent,"kind":"native_effect","label":"Weapon effect · "+str(component.native_cue.clip).get_file(),
            "start_ms":at_ms,"end_ms":INF,"source_start_ms":component.start_ms,"group_start_ms":component.start_ms,"group_id":"",
            "source_event_uuid":component.source_event_uuid,"actor_uuid":component.actor_uuid,"component":component,
            "source":component.source,"status":component.status,"reason":component.get("reason",""),"signature":signature,
            "markers":[],"source_fps":0,"render_method":{"renderer":"res://presentation/native_spell_renderer.gd","attachment":component.native_cue.attachment,"item_uuid":component.item_owner_uuid,"inputs":component.native_clip.get("inputs",[])},"preview_scope":"actual_item_in_scene","coverage":{"implementation":"resolved","source":component.status,"prepared":"not_examined","rendered":"not_witnessed"}}
        current[id]=row;spans.append(row)
