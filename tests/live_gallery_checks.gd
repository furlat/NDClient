extends "res://tests/player_live_checks.gd"
# Slow native lane: discover, preview and issue every command through the real
# player. Route goals are the same as tools/gallery_recording.py; no replay or
# fabricated state. Timings distinguish input waits from actual frame stalls.
const ROUTE = [["Crypt passage","open"],["move",[10,6]],
    ["Burial hall door","open"],["move",[13,6]],
    ["Gallery passage","open"],["move",[22,6]],
    ["Lantern gallery door","open"],["gallery_entry",[26,6]],
    ["gallery_nave",[46,6]],["gallery_centre",[46,20]],["gallery_far",[68,20]]]
var command_trace: Array = []
var stage = 0
var leader = ""
var pipeline_trace: Array = []
var pipeline_dropped = 0
var pipeline_poll_us = 0
var choice_sizes: Dictionary = {}
var largest_choices: Dictionary = {}
var largest_choices_bytes = 0
var largest_choices_request = -1
var profile_view_size = 0.0
var profile_stop_stage = ROUTE.size()
var bounded_profile = false

class CapturingPlayer extends "res://play.gd":
    var choices_observed: Callable
    var profiling_configured:Dictionary
    var submit_markers:Array=[]
    func _submit(intent:Dictionary)->void:
        submit_markers.append({"time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames(),"number":session.status.next_command_number,"intent":intent.duplicate(true)})
        super._submit(intent)
    var media_gate_trace:Array=[]
    var last_gate_snapshot:Dictionary={}
    func _media_ready(group:Dictionary)->bool:
        var result:bool=super._media_ready(group)
        if not game_config.get("live_fireball_ui",false) or group.is_empty():return result
        var missing:Array=[]
        for path in media_plan.required:
            if not media_warmup.ready_paths.has(path):missing.append(path)
        var missing_environment:Array=[]
        for path in media_environment_required:
            if not media_warmup.ready_paths.has(path):missing_environment.append(path)
        var snapshot={"group":group.id,"ready":result,"display_ms":timeline.display_ms,"media_target_ms":timeline.media_target_ms,"group_start_ms":timeline.group_start_ms,"current":timeline.current.get("id",""),"gate":media_gate.duplicate(true),"missing":missing,"environment_missing":missing_environment,
            "pending":media_warmup.pending.size(),"jobs":media_warmup.decode_jobs.size(),"decoded":MediaWarmup.physical(media_warmup).decoded,
            "required_count":media_plan.required.size(),"optical_required":component_renderer.native_spells.required_images.size(),"worker_decode_ms":MediaWarmup.physical(media_warmup).decode_ms,"publication":MediaWarmup.physical(media_warmup).publication.duplicate(true)}
        if snapshot!=last_gate_snapshot:
            last_gate_snapshot=snapshot
            media_gate_trace.append({"time_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames(),"snapshot":snapshot})
        return result
    var capture_media_demand=false
    var media_demand_trace:Array=[]
    func _prepare_media(first:Dictionary={}) -> void:
        var runs:int=media_warmup.demand_runs
        super._prepare_media(first)
        if not capture_media_demand or runs==media_warmup.demand_runs:return
        var missing:Array=[]
        if MediaWarmup.physical(media_warmup).unknown_required>0:
            for path in media_warmup.wanted:
                if MediaWarmup._estimate(media_warmup,path)<0:missing.append(path)
        media_demand_trace.append({"frame":Engine.get_process_frames(),"display_ms":timeline.display_ms,
            "counts":media_warmup.demand_counts.duplicate(),"phases":media_warmup.demand_phases.duplicate(),
            "unknown_paths":missing,"selected":media_warmup.preload_selected.size(),"size_headers":media_warmup.source_sizes.size()})
    func _init()->void:
        # Play creates a Session lazily in _ready. Supply that same real owner
        # before its transport starts; profiling cannot be enabled afterward.
        session=Session.new()
        profiling_configured=session.transport.set_profiling(true)
    func _poll_actions() -> void:
        if action_request>=0 and pending_request.get("kind")=="choices" and session.responses.has(action_request):
            var result: Dictionary=session.responses[action_request]
            if result.ok: choices_observed.call(action_request,result.value)
        super._poll_actions()

func capture_choices(request_id: int, value: Dictionary) -> void:
    # The admission profile publishes the original HTTP byte count before
    # the response. Keep one immutable value owner; serialize only after timing.
    collect_pipeline(true)
    var bytes: int=choice_sizes.get(request_id,0)
    choice_sizes.erase(request_id)
    if bytes<=largest_choices_bytes:return
    scene.session.retire_record(largest_choices)
    largest_choices=value
    largest_choices_bytes=bytes
    largest_choices_request=request_id

func collect_pipeline(force: bool = false) -> void:
    var now=Time.get_ticks_usec()
    if not force and now-pipeline_poll_us<250000:return
    pipeline_poll_us=now
    var stream: Dictionary=scene.session.transport.drain_profile()
    pipeline_trace.append_array(stream.records)
    for record in stream.records:
        if record.stage=="http_admission" and record.operation=="choices" and record.ok:
            choice_sizes[int(record.request_id)]=int(record.bytes)
    pipeline_dropped=maxi(pipeline_dropped,stream.dropped)

func healthy() -> bool:
    return scene.session.issue.is_empty() and scene.presentation_errors.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()-started<1200000

func rows() -> Array:
    var result = []
    for family in ["entity_actions","position_actions","self_actions","object_actions"]:
        for row in scene.available_actions.get(family,[]):
            if row.can_afford and not Choices.action_options(scene.available_actions,row).is_empty(): result.append(row)
    return result

func toward(available: Array, origin: Array, destinations: Array) -> Dictionary:
    var best = {}; var score = INF
    var initial = INF
    for p in destinations: initial = minf(initial,absf(origin[0]-p[0])+absf(origin[1]-p[1]))
    for row in available:
        if row.behavior_id!="action.move": continue
        for target in Choices.action_options(scene.available_actions,row):
            var position: Variant = Choices.binding_position(scene.available_actions,target)
            if position==null: continue
            var distance = INF
            for p in destinations: distance=minf(distance,absf(position[0]-p[0])+absf(position[1]-p[1]))
            if distance<initial and distance<score:
                best={"action":row,"target":target};score=distance
    return best

func select_route() -> Dictionary:
    var available = rows()
    var actor: String = scene.available_actions.entity_uuid
    var current: Array = scene.timeline.state.actors[actor].last_visual_position
    var enemies = {}
    for id in scene.timeline.state.actors:
        var value: Dictionary = scene.timeline.state.actors[id]
        if id not in scene.timeline.state.audience.controlled and value.get("present",false) and value.normal_hp>0 and value.name!="Gallery Curator": enemies[id]=true
    var attack = {};var score=INF
    for row in available:
        if not row.get("performs_attack",false) and row.behavior_id!="spell.magic_missile": continue
        for target in Choices.action_options(scene.available_actions,row):
            var subject: Variant = Choices.binding_subject(scene.available_actions,target)
            if subject==null or not enemies.has(subject.uuid): continue
            var distance: float = target.get("distance",0) if target.get("distance")!=null else 0
            var value = distance+(0 if row.behavior_id=="spell.magic_missile" else 1000)+(0 if row.behavior_id=="spell.fire_bolt" else 100)
            if value<score:attack={"action":row,"target":target};score=value
    if not attack.is_empty(): return attack
    if actor!=leader: return toward(available,current,[scene.timeline.state.actors[leader].last_visual_position])
    var goal: Array = ROUTE[stage]
    var selected = {}
    if goal[1] is String:
        var identity = ""
        for id in scene.timeline.state.objects:
            if scene.timeline.state.objects[id].item.name==goal[0]: identity=id;break
        for option in scene.available_actions.get("world_interactions",[]):
            if option.subject_uuid!=identity or not option.behavior_id.ends_with(".open"): continue
            for row in available:
                if row.behavior_id!=option.behavior_id or row.template_name!=option.template_name: continue
                for target in Choices.action_options(scene.available_actions,row):
                    var subject: Variant = Choices.binding_subject(scene.available_actions,target)
                    if row.get("source_item_uuid")==identity or (subject!=null and subject.uuid==identity):
                        return {"action":row,"target":target,"opens_stage":true}
            selected=toward(available,current,option.get("contact_positions",[]))
            break
    else: selected=toward(available,current,[goal[1]])
    if not selected.is_empty():return selected
    for row in available:
        if row.behavior_id=="action.dash":return {"action":row,"target":Choices.action_options(scene.available_actions,row)[0]}
    return {}

func phase_value() -> Dictionary:
    return {"request":scene.pending_request.get("kind",""),"request_active":scene.action_request>=0,
        "command_busy":scene.command_busy,"sequence":scene.timeline.sequence,"received":scene.session.latest_sequence,
        "group":scene.timeline.current.get("id",""),"media_wait":scene.timeline.waiting_for_media,
        "world_wait":scene.timeline.waiting_for_world,"ready":ready()}

func _subject_uuid(owner:Dictionary,option:Dictionary)->String:
    var subject:Variant=Choices.binding_subject(owner,option)
    return "" if subject==null else str(subject.uuid)

func _issue_input(selected:Dictionary,record:Dictionary)->void:
    if selected.is_empty():scene.end_turn()
    else:
        var target: Variant=Choices.binding_position(scene.available_actions,selected.target)
        var click=false
        if record.behavior=="action.move" and target!=null:
            var screen=grid_screen(target)
            click=root.get_visible_rect().has_point(screen) and not scene.hud.pointer_over_controls(screen) and scene.pick_world(screen).get("kind")=="ground" and scene.Interaction.same_position(scene.pick_cell(screen).get("position"),target)
        if click:
            scene.cancel_selection();scene.selected_mode="action.move"
            record.input="viewport_click"
            click_grid(target)
        else:scene._execute_admitted({"action":selected.action,"selection":scene.Interaction.selection(selected.action,[selected.target.index])})

func issue(selected: Dictionary) -> bool:
    var actor: String=scene.available_actions.entity_uuid
    var number: int=scene.session.status.next_command_number
    var sequence: int=scene.timeline.sequence
    var command_start=Time.get_ticks_usec()
    var label: String=selected.action.behavior_id if not selected.is_empty() else "end_turn"
    scene.profile.label="command_%d_%s" % [number,label]
    collect_pipeline(true)
    var record={"number":number,"behavior":label,"stage":stage,"actor":actor,"from":scene.timeline.state.actors[actor].last_visual_position.duplicate(),"start_us":command_start,
        "camera_size":scene.camera.size,"pipeline_before":FrameProfile.pipeline_compilations(),
        "first_movement_ms":null,"first_animation_ms":null,"published_packet_ms":null,"input":"admitted_action_handler",
        "start_frame":Engine.get_process_frames(),"phases":[],"samples":[],"frame_intervals":[],"phase_peaks":{},"slow_frames":[],
        "playback_complete_ms":null,"playback_complete_frame":null,"choices_applied_ms":null,"choices_applied_frame":null,
        "early_choices_publications":[],"post_ready_frames":[],"bar_settled_ms":null,"bar_settled_frame":null}
    var painted_generation: int = scene.available_actions.get("discovery_generation",0)
    await _issue_input(selected,record)
    if not failures.is_empty():
        record.input_failed=true
        command_trace.append(record)
        return false
    record.submit_markers=scene.submit_markers.filter(func(marker):return marker.time_us>=command_start)
    var previous={};var native_previous={}
    var previous_compilations:Dictionary=record.pipeline_before
    record.pipeline_changes=[]
    var deadline=Time.get_ticks_msec()+60000
    while healthy() and Time.get_ticks_msec()<deadline:
        await RenderingServer.frame_post_draw
        collect_pipeline()
        var compilations=FrameProfile.pipeline_compilations()
        if compilations!=previous_compilations:
            record.pipeline_changes.append({"frame":Engine.get_process_frames(),"elapsed_ms":(Time.get_ticks_usec()-command_start)/1000.0,"counts":compilations})
            previous_compilations=compilations
        var phase=phase_value()
        var elapsed=(Time.get_ticks_usec()-command_start)/1000.0
        if phase.group.is_empty() and phase.sequence>sequence and (previous.get("group","")!="" or previous.get("sequence",sequence)!=phase.sequence):
            record.playback_complete_ms=elapsed
            record.playback_complete_frame=Engine.get_process_frames()
        var adopted_generation: int = scene.available_actions.get("discovery_generation",0)
        if adopted_generation!=painted_generation:
            record.choices_applied_ms=elapsed
            record.choices_applied_frame=Engine.get_process_frames()
            if scene.timeline.busy() or not scene.session.ready_for_input(scene.timeline.sequence) or scene.available_actions.entity_uuid!=scene.timeline.state.current_actor_uuid:
                record.early_choices_publications.append({"ms":elapsed,"frame":Engine.get_process_frames()})
            painted_generation=adopted_generation
        if record.published_packet_ms==null and scene.session.latest_sequence>sequence:record.published_packet_ms=elapsed
        if not scene.profile.frames.is_empty():
            var sampled_frame: Dictionary=scene.profile.frames[posmod(scene.profile.cursor-1,scene.profile.frames.size())]
            record.frame_intervals.append(sampled_frame.frame_ms)
            for name in sampled_frame.cpu_ms:
                record.phase_peaks[name]=maxf(record.phase_peaks.get(name,0),sampled_frame.cpu_ms[name])
            if sampled_frame.frame_ms>33.333:
                record.slow_frames.append({"frame":sampled_frame.frame,"ms":sampled_frame.frame_ms,"cpu_ms":sampled_frame.cpu_ms.duplicate()})
        if phase!=previous:
            record.phases.append({"ms":elapsed,"state":phase});previous=phase
        var observations=[]
        observe_actor(actor,observations)
        if not observations.is_empty():
            var native: Dictionary=observations[0]
            if record.first_movement_ms==null and not scene.Interaction.same_position(native.position,record.from):record.first_movement_ms=elapsed
            if record.first_animation_ms==null and str(native.clip).to_lower()!="idle":record.first_animation_ms=elapsed
            native.occurrence=scene.displayed_samples.get(actor,{}).get("occurrence","")
            native.frame_uv=[]
            if scene.visual_actors.has(actor):
                for entry in scene.visual_actors[actor].entries:
                    if entry.node.visible and entry.role=="body":
                        var uv:Vector4=entry.material.get_shader_parameter("frame_uv")
                        native.frame_uv=[uv.x,uv.y,uv.z,uv.w];break
            if native!=native_previous:
                record.samples.append({"ms":elapsed,"native":native});native_previous=native
        # Multi-target native previews ask for their remaining disclosed targets.
        if scene.action_request<0 and not scene.command_busy and scene.session.status.next_command_number==number and not scene.selection_preview.is_empty() and not scene.selection_preview.can_confirm:
            var next: Array=Choices.next_options(scene.selection_preview)
            if not next.is_empty():
                var target:Dictionary=next[0]
                if selected.has("recipient_uuid"):
                    var matching=next.filter(func(option):return _subject_uuid(scene.selection_preview,option)==selected.recipient_uuid)
                    if matching.is_empty():
                        check(false,"Real multi-target preview retains requested recipient");break
                    target=matching[0]
                scene.target_selection.target_indices.append(target.index)
                scene._request_selection(true)
        if ready() and scene.timeline.sequence>sequence and scene.session.status.next_command_number>number:break
    record.submit_markers=scene.submit_markers.filter(func(marker):return marker.time_us>=command_start)
    record.pipeline_after=FrameProfile.pipeline_compilations()
    record.elapsed_ms=(Time.get_ticks_usec()-command_start)/1000.0
    record.end_us=Time.get_ticks_usec()
    record.end_frame=Engine.get_process_frames()
    record.end_to_ready_ms=null if record.playback_complete_ms==null else record.elapsed_ms-record.playback_complete_ms
    var completion_sequence: int=scene.timeline.sequence
    var completion_command: int=scene.session.status.next_command_number
    var completion_revision: String=scene.session.status.boundary.state_revision
    var completed: bool=ready() and completion_sequence>sequence and scene.session.status.next_command_number>number
    if not completed:
        record.failure_context={"notice":scene.notice_text,"pending_kind":scene.pending_request.get("kind",""),
            "command_number":scene.pending_request.get("number",-1),"phase":phase_value()}
    # HUD adoption occurs after Player's frame sample. Capture these intervals
    # before deep canonical comparisons or sorting the command frame samples:
    # test validation must not masquerade as the first post-ready render hitch.
    scene.profile.label="post_ready_%d" % number
    var post_ready_deadline=Time.get_ticks_msec()+5000
    var post_ready_count=0
    while healthy() and Time.get_ticks_msec()<post_ready_deadline and (post_ready_count<5 or scene.hud.bar_pending()):
        await RenderingServer.frame_post_draw
        post_ready_count+=1
        var hud_pending: bool=scene.hud.bar_pending()
        if not hud_pending and record.bar_settled_ms==null:
            record.bar_settled_ms=(Time.get_ticks_usec()-command_start)/1000.0
            record.bar_settled_frame=Engine.get_process_frames()
        if not scene.profile.frames.is_empty():
            var sampled: Dictionary=scene.profile.frames[posmod(scene.profile.cursor-1,scene.profile.frames.size())]
            record.post_ready_frames.append({"frame":sampled.frame,"frame_ms":sampled.frame_ms,"cpu_ms":sampled.cpu_ms.duplicate(),
                "state":phase_value(),"media_metadata_pending":scene.media_warmup.plan_task>=0,"hud_pending":hud_pending,"pipeline_compilations":FrameProfile.pipeline_compilations()})
    scene.profile.label="receipt_validation_%d" % number
    record.validation_start_us=Time.get_ticks_usec()
    record.frame_ms=FrameProfile.distribution(record.frame_intervals)
    record.frame_budget_counts={"total":record.frame_intervals.size(),"over_10_ms":0,"over_16_667_ms":0,"over_33_333_ms":0,"over_100_ms":0}
    for interval in record.frame_intervals:
        if interval>10.0:record.frame_budget_counts.over_10_ms+=1
        if interval>16.667:record.frame_budget_counts.over_16_667_ms+=1
        if interval>33.333:record.frame_budget_counts.over_33_333_ms+=1
        if interval>100.0:record.frame_budget_counts.over_100_ms+=1
    record.erase("frame_intervals")
    record.to=scene.timeline.state.actors[actor].last_visual_position.duplicate()
    command_trace.append(record)
    check(completed,"Client command finishes: %s %d" % [label,number])
    check(record.early_choices_publications.is_empty(),"Choices remain private until displayed command boundary: %d" % number)
    check(not scene.hud.bar_pending() and record.bar_settled_ms!=null,"Queued action bar completes after command: %d" % number)
    check(not completed or (is_same(scene.hud.painted_discovery,scene.available_actions)
        and scene.hud.action_buttons.all(func(button):return button.get_meta("native_row").get("discovery_generation",0)==scene.available_actions.discovery_generation)),
        "Completed action bar contains current discovery rows: %d" % number)
    record.input_ready_after_samples=ready()
    check(not completed or (post_ready_count>=5 and ready() and record.post_ready_frames.all(func(frame):return frame.state.ready)
        and not scene.timeline.busy() and scene.timeline.sequence==completion_sequence
        and scene.session.status.next_command_number==completion_command
        and scene.session.status.boundary.state_revision==completion_revision),
        "Post-ready samples remain ready at the same quiescent command boundary: %d" % number)
    check(scene.timeline.state==scene.session.journal.state,"Client command reaches canonical state: %d" % number)
    record.validation_cpu_ms=(Time.get_ticks_usec()-record.validation_start_us)/1000.0
    if completed:
        var received=await request("receipt",{"number":number})
        if received.ok:
            record.receipt=received.value.receipt
            check(record.receipt.command_number==number and record.receipt.kind=="committed","Exact submitted command committed: %d" % number)
        if not ready(): await until(ready,"Native choices settle after receipt verification")
    print("LIVE_COMMAND ",JSON.stringify({"number":number,"behavior":label,"elapsed_ms":record.elapsed_ms,"stage":stage,"position":record.to,"ready":ready()}))
    return completed and healthy()

func _run() -> void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--profile-view-size="):
            profile_view_size=argument.trim_prefix("--profile-view-size=").to_float()
            check(profile_view_size>=4.0 and profile_view_size<=80.0,"Profile camera size is within player limits")
        elif argument.begins_with("--profile-stop-stage="):
            profile_stop_stage=argument.trim_prefix("--profile-stop-stage=").to_int()
            bounded_profile=true
            check(profile_stop_stage>=9 and profile_stop_stage<=ROUTE.size(),"Bounded route includes Gallery entry and an interior move")
    if not failures.is_empty():quit(1);return
    if bounded_profile or profile_view_size>0.0:
        root.size=Vector2i(1600,960)
        Engine.max_fps=0
    scene=CapturingPlayer.new();scene.choices_observed=capture_choices;scene.profile.recording=true
    evidence.atlas_reference=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--reference-atlas="):
            evidence.atlas_reference=argument.trim_prefix("--reference-atlas=")
            scene.native_light_atlas=preload("res://tests/atlas_reference.gd").instantiate(evidence.atlas_reference)
    root.add_child(scene)
    check(scene.profiling_configured.ok and scene.session.transport.profiling_enabled(),"Transport profiling configured before live start")
    if profile_view_size>0.0:scene.camera.size=profile_view_size
    # Default to approved capped lighting; an explicit diagnostic run can
    # compare the same real movement/reveal route with the cap disabled.
    var profile_cap := not OS.get_cmdline_user_args().has("--profile-light-cap=off")
    scene.light_cap_enabled=profile_cap
    scene.native_light_atlas.set_light_cap(1.0 if profile_cap else 0.0)
    evidence.light_cap_enabled=profile_cap
    evidence.profile_view_size=profile_view_size if profile_view_size>0.0 else null
    evidence.profile_stop_stage=profile_stop_stage
    evidence.bounded_profile=bounded_profile
    evidence.window_size=[root.size.x,root.size.y]
    if not await until(ready,"Live Gallery initial choices",120000):await finish();return
    evidence.ready_frame=Engine.get_process_frames()
    evidence.ready_elapsed_ms=Time.get_ticks_msec()-started
    for id in scene.timeline.state.audience.controlled:
        if scene.timeline.state.actors[id].name=="Shield Fighter":leader=id
    check(not leader.is_empty(),"Original Gallery leader exists")
    # Exercise the requested grid hotkey through viewport input before commands.
    var grid_before: bool=scene.grid_visible
    var event=InputEventKey.new();event.physical_keycode=KEY_G;event.keycode=KEY_G;event.pressed=true
    root.push_input(event,true)
    check(scene.grid_visible!=grid_before,"G toggles live grid")
    event=event.duplicate();event.pressed=false;root.push_input(event,true)
    await scene.presentation_updated
    check(scene.hud.grid_button.button_pressed==scene.grid_visible,"Grid button follows keyboard state")
    var click=InputEventMouseButton.new();click.position=scene.hud.grid_button.get_global_rect().get_center()
    click.global_position=click.position;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
    root.push_input(click,true)
    click=click.duplicate();click.pressed=false;root.push_input(click,true)
    check(scene.grid_visible==grid_before,"Grid button toggles the live overlay")
    scene.grid_visible=false
    while stage<profile_stop_stage and command_trace.size()<180 and healthy():
        if not await until(ready,"Next client command is offered"):break
        if profile_view_size>0.0:scene.camera.size=profile_view_size
        elif stage>=8: scene.camera.size=28.0 if stage==9 else 16.0
        var goal: Array=ROUTE[stage]
        if not goal[1] is String and scene.timeline.state.actors[leader].last_visual_position==goal[1]:
            print("LIVE_MILESTONE ",goal[0]," tiles=",scene.timeline.state.tiles.size());stage+=1;continue
        var p: Array=scene.timeline.state.actors[scene.available_actions.entity_uuid].last_visual_position
        scene.camera_focus=Vector3(p[0],0,p[1]);scene.position_camera()
        var selected=select_route()
        if not await issue(selected):break
        if selected.get("opens_stage",false):stage+=1
    check(stage==profile_stop_stage,"Actual player reaches the requested Gallery route endpoint with client-issued commands")
    evidence.gallery_viewport_clicks=command_trace.filter(func(record):return record.stage>=8 and record.behavior=="action.move" and record.input=="viewport_click").size()
    if bounded_profile:
        check(command_trace.any(func(record):return record.stage==7 and record.behavior=="action.move" and record.actor==leader and record.to==ROUTE[7][1]),"Bounded profile includes committed leader movement into the Gallery")
        check(command_trace.any(func(record):return record.stage==8 and record.behavior=="action.move" and record.actor==leader and record.to==ROUTE[8][1]),"Bounded profile includes committed leader movement across the Gallery nave")
        check(evidence.gallery_viewport_clicks>=1,"Bounded Gallery route includes an actual interior viewport movement click")
        check(ready() and not scene.timeline.busy() and scene.timeline.state==scene.session.journal.state,"Bounded profile ends at a drained canonical command boundary")
    else:check(evidence.gallery_viewport_clicks>=8,"Gallery route exercises at least eight real viewport movement clicks")
    if profile_view_size>0.0:
        check(command_trace.all(func(record):return is_equal_approx(record.camera_size,profile_view_size)),"All client-issued commands use the requested fixed camera size")
    evidence.live_commands=command_trace.size()
    evidence.live_route_stage=stage
    evidence.command_trace=scene.game_config.test_result.get_base_dir().path_join("live-command-trace.json")
    evidence.disclosed_tiles=scene.timeline.state.tiles.size()
    evidence.disclosed_objects=scene.timeline.state.objects.size()
    # Same disclosed live scene with no pending command: retain a steady-frame
    # control alongside real movement/reveal measurements, at the same zooms.
    var idle_sequence=scene.timeline.sequence
    var idle_caps:Array=[profile_cap] if bounded_profile else [false,true]
    var idle_zooms:Array=[scene.camera.size] if bounded_profile else [8.137,16.0,28.0]
    for cap in idle_caps:
        scene.light_cap_enabled=cap
        scene.native_light_atlas.set_light_cap(1.0 if cap else 0.0)
        for zoom in idle_zooms:
            scene.profile.label="idle_settle"
            scene.camera.size=zoom
            for frame in 30: await scene.presentation_updated
            scene.profile.label="gallery_idle_cap_%s_zoom_%s" % [cap,zoom]
            var idle_until=Time.get_ticks_msec()+3000
            while Time.get_ticks_msec()<idle_until: await scene.presentation_updated
    check(scene.timeline.sequence==idle_sequence and scene.timeline.state==scene.session.journal.state,"Idle zoom/cap profiles preserve canonical displayed state")
    scene.set_process(false)
    scene.session.close()
    collect_pipeline(true)
    evidence.pipeline_trace=scene.game_config.test_result.get_base_dir().path_join("client-pipeline-trace.json")
    check(pipeline_dropped==0,"Bounded pipeline diagnostics are drained without losing records")
    FileAccess.open(evidence.pipeline_trace,FileAccess.WRITE).store_string(JSON.stringify({"clock":"godot_monotonic_usec","dropped":pipeline_dropped,"records":pipeline_trace}))
    FileAccess.open(evidence.command_trace,FileAccess.WRITE).store_string(JSON.stringify(command_trace))
    evidence.full_profile=FrameProfile.save(scene.profile,root,"gallery-live-commands",true)
    if not largest_choices.is_empty():
        evidence.choices_sample={"path":scene.game_config.test_result.get_base_dir().path_join("largest-choices-admitted.json"),
            "original_http_bytes":largest_choices_bytes,"request_id":largest_choices_request,
            "format":"Unnormalized admitted response reserialized with full_precision=true; original field omissions preserved, not original lexical HTTP bytes."}
        FileAccess.open(evidence.choices_sample.path,FileAccess.WRITE).store_string(JSON.stringify(largest_choices,"",true,true))
    await finish()
