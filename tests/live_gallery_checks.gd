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

func collect_pipeline(force: bool = false) -> void:
    var now=Time.get_ticks_usec()
    if not force and now-pipeline_poll_us<250000:return
    pipeline_poll_us=now
    var stream: Dictionary=scene.session.transport.drain_profile()
    pipeline_trace.append_array(stream.records)
    pipeline_dropped=maxi(pipeline_dropped,stream.dropped)

func healthy() -> bool:
    return scene.session.issue.is_empty() and scene.presentation_errors.is_empty() and Time.get_ticks_msec()-started<1200000

func rows() -> Array:
    var result = []
    for family in ["entity_actions","position_actions","self_actions","object_actions"]:
        for row in scene.available_actions[family]:
            if row.can_afford and not row.valid_targets.is_empty(): result.append(row)
    return result

func toward(available: Array, origin: Array, destinations: Array) -> Dictionary:
    var best = {}; var score = INF
    var initial = INF
    for p in destinations: initial = minf(initial,absf(origin[0]-p[0])+absf(origin[1]-p[1]))
    for row in available:
        if row.behavior_id!="action.move": continue
        for target in row.valid_targets:
            if target.get("position")==null: continue
            var distance = INF
            for p in destinations: distance=minf(distance,absf(target.position[0]-p[0])+absf(target.position[1]-p[1]))
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
        if not row.performs_attack and row.behavior_id!="spell.magic_missile": continue
        for target in row.valid_targets:
            if not enemies.has(target.get("target_uuid")): continue
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
        for option in scene.available_actions.world_interactions:
            if option.subject_uuid!=identity or not option.behavior_id.ends_with(".open"): continue
            for row in available:
                if row.behavior_id!=option.behavior_id or row.template_name!=option.template_name: continue
                for target in row.valid_targets:
                    if row.source_item_uuid==identity or target.get("target_uuid")==identity:
                        return {"action":row,"target":target,"opens_stage":true}
            selected=toward(available,current,option.contact_positions)
            break
    else: selected=toward(available,current,[goal[1]])
    if not selected.is_empty():return selected
    for row in available:
        if row.behavior_id=="action.dash":return {"action":row,"target":row.valid_targets[0]}
    return {}

func phase_value() -> Dictionary:
    return {"request":scene.pending_request.get("kind",""),"request_active":scene.action_request>=0,
        "command_busy":scene.command_busy,"sequence":scene.timeline.sequence,"received":scene.session.latest_sequence,
        "group":scene.timeline.current.get("id",""),"media_wait":scene.timeline.waiting_for_media,
        "world_wait":scene.timeline.waiting_for_world,"ready":ready()}

func issue(selected: Dictionary) -> bool:
    var actor: String=scene.available_actions.entity_uuid
    var number: int=scene.session.status.next_command_number
    var sequence: int=scene.timeline.sequence
    var command_start=Time.get_ticks_usec()
    var label: String=selected.action.behavior_id if not selected.is_empty() else "end_turn"
    scene.profile.label="command_%d_%s" % [number,label]
    collect_pipeline(true)
    var record={"number":number,"behavior":label,"stage":stage,"actor":actor,"from":scene.timeline.state.actors[actor].last_visual_position.duplicate(),"start_us":command_start,
        "first_movement_ms":null,"first_animation_ms":null,"published_packet_ms":null,"input":"admitted_action_handler",
        "start_frame":Engine.get_process_frames(),"phases":[],"samples":[],"frame_intervals":[],"phase_peaks":{},"slow_frames":[]}
    if selected.is_empty():scene.end_turn()
    else:
        var target: Variant=selected.target.get("position")
        var click=false
        if label=="action.move" and target!=null:
            var screen=grid_screen(target)
            click=root.get_visible_rect().has_point(screen) and not scene.hud.pointer_over_controls(screen) and scene.pick_world(screen).get("kind")=="ground" and scene.pick_cell(screen).get("position")==target
        if click:
            scene.cancel_selection();scene.selected_mode="action.move"
            record.input="viewport_click"
            click_grid(target)
        else:scene._execute_admitted({"action":selected.action,"selection":scene.Interaction.selection(selected.action,[selected.target.index])})
    var previous={};var native_previous={}
    var deadline=Time.get_ticks_msec()+60000
    while healthy() and Time.get_ticks_msec()<deadline:
        await RenderingServer.frame_post_draw
        collect_pipeline()
        var phase=phase_value()
        var elapsed=(Time.get_ticks_usec()-command_start)/1000.0
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
            if record.first_movement_ms==null and native.position!=record.from:record.first_movement_ms=elapsed
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
            var next: Array=scene.selection_preview.get("next_targets",[])
            if not next.is_empty():
                scene.target_selection.target_indices.append(next[0].index)
                scene._request_selection(true)
        if ready() and scene.timeline.sequence>sequence and scene.session.status.next_command_number>number:break
    record.elapsed_ms=(Time.get_ticks_usec()-command_start)/1000.0
    record.end_us=Time.get_ticks_usec()
    record.frame_ms=FrameProfile.distribution(record.frame_intervals)
    record.erase("frame_intervals")
    record.end_frame=Engine.get_process_frames()
    record.to=scene.timeline.state.actors[actor].last_visual_position.duplicate()
    command_trace.append(record)
    var completed: bool=ready() and scene.timeline.sequence>sequence and scene.session.status.next_command_number>number
    check(completed,"Client command finishes: %s %d" % [label,number])
    check(scene.timeline.state==scene.session.journal.state,"Client command reaches canonical state: %d" % number)
    scene.profile.label="receipt_validation_%d" % number
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
    scene=Player.instantiate();scene.profile.recording=true
    evidence.atlas_reference=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--reference-atlas="):
            evidence.atlas_reference=argument.trim_prefix("--reference-atlas=")
            scene.native_light_atlas=preload("res://tests/atlas_reference.gd").instantiate(evidence.atlas_reference)
    scene.session.transport.set_profiling(true)
    root.add_child(scene)
    # Default to approved capped lighting; an explicit diagnostic run can
    # compare the same real movement/reveal route with the cap disabled.
    var profile_cap := not OS.get_cmdline_user_args().has("--profile-light-cap=off")
    scene.light_cap_enabled=profile_cap
    scene.native_light_atlas.set_light_cap(1.0 if profile_cap else 0.0)
    evidence.light_cap_enabled=profile_cap
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
    while stage<ROUTE.size() and command_trace.size()<180 and healthy():
        if not await until(ready,"Next client command is offered"):break
        if stage>=8: scene.camera.size=28.0 if stage==9 else 16.0
        var goal: Array=ROUTE[stage]
        if not goal[1] is String and scene.timeline.state.actors[leader].last_visual_position==goal[1]:
            print("LIVE_MILESTONE ",goal[0]," tiles=",scene.timeline.state.tiles.size());stage+=1;continue
        var p: Array=scene.timeline.state.actors[scene.available_actions.entity_uuid].last_visual_position
        scene.camera_focus=Vector3(p[0],0,p[1]);scene.position_camera()
        var selected=select_route()
        if not await issue(selected):break
        if selected.get("opens_stage",false):stage+=1
    check(stage==ROUTE.size(),"Actual player reaches far Gallery with client-issued commands")
    evidence.live_commands=command_trace.size()
    evidence.live_route_stage=stage
    evidence.command_trace=scene.game_config.test_result.get_base_dir().path_join("live-command-trace.json")
    evidence.disclosed_tiles=scene.timeline.state.tiles.size()
    evidence.disclosed_objects=scene.timeline.state.objects.size()
    # Same disclosed live scene with no pending command: retain a steady-frame
    # control alongside real movement/reveal measurements, at the same zooms.
    var idle_sequence=scene.timeline.sequence
    for cap in [false,true]:
        scene.light_cap_enabled=cap
        scene.native_light_atlas.set_light_cap(1.0 if cap else 0.0)
        for zoom in [8.137,16.0,28.0]:
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
    await finish()
