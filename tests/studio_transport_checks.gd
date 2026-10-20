extends SceneTree
## Real track input, playback and asynchronous case publication in native Studio.
const Studio=preload("res://studio/studio.gd")
const Studies=preload("res://studio/study_catalog.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks=0
var failures:Array=[]
var evidence={}
var saved_layout=""
var had_layout=false
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("STUDIO_TRANSPORT_FAIL ",label)
func ready(s:Control)->bool:
    return not s.index.is_empty() and s.loader==null and (s.seeker==null or s.preparing_loop) and (not s.installing or s.preparing_loop) and s.requested_seek<0
func settle(s:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while not ready(s) and Time.get_ticks_msec()<deadline:await process_frame
    check(ready(s),"Visible requested selection publishes independently of background loop preparation")
    return ready(s)
func button(view:Control,at:Vector2,pressed:bool)->void:
    var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at
    view._gui_input(event)
func motion(view:Control,at:Vector2)->void:
    var event=InputEventMouseMotion.new();event.position=at;event.button_mask=MOUSE_BUTTON_MASK_LEFT
    view._gui_input(event)
func root_button(at:Vector2,pressed:bool)->void:
    var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
    event.position=at;event.global_position=at;root.push_input(event,true)
func root_motion(at:Vector2,relative:Vector2)->void:
    var event=InputEventMouseMotion.new();event.position=at;event.global_position=at
    event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event,true)
func host_count(s:Control)->int:
    return s.get_children().filter(func(child):return child is SubViewport and not child.is_queued_for_deletion()).size()
func projection(world:Node3D)->Vector2:
    var focus:Vector3=world.camera_focus
    return world.camera.unproject_position(focus+world.camera.basis.x)-world.camera.unproject_position(focus)
func scrub(s:Control,start:float,intermediate:float,target:float)->void:
    var clock:float=s.world.timeline.display_ms
    var generation:int=s.seek_generation
    button(s.tracks,Vector2(s.tracks._x(start),10),true)
    motion(s.tracks,Vector2(s.tracks._x(intermediate),10))
    await process_frame
    check(is_equal_approx(s.tracks.playhead_ms,intermediate) and is_equal_approx(s.world.timeline.display_ms,clock),"Ruler motion immediately updates requested playhead while retaining the displayed authoritative scene")
    check(s.seeker==null and not s.installing and s.requested_seek<0,"Pointer motion does not create a worker or renderer for each sample")
    motion(s.tracks,Vector2(s.tracks._x(target),10))
    button(s.tracks,Vector2(s.tracks._x(target),10),false)
    check(s.seek_generation==generation+1,"Ruler release submits exactly one final seek intent")
    if not await settle(s):return
    var expected=Studio.Recording.restore(s.index,target)
    check(is_equal_approx(s.world.timeline.display_ms,target) and s.world.timeline.state==expected.state and s.world.timeline.sequence==expected.sequence,"Released forward/backward ruler seek publishes the exact independently restored prefix")
    check(s.world.timeline.paused and s.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"Released scrub leaves an updated paused native preview")
func capture_ready(s:Control)->void:
    var body_rows=s.index.rows.filter(func(row):return row.kind=="body" and row.track.clip=="TakeDamage")
    if not body_rows.is_empty():s.tracks.reveal(body_rows[0].id)
    await process_frame;await RenderingServer.frame_post_draw
    var started=Time.get_ticks_msec();var deadline=started+30000
    while not s.tracks.prepare_visible().settled and Time.get_ticks_msec()<deadline:await process_frame
    var keys:Array=s.tracks.preview_demand.keys()
    check(keys.all(func(key):return s.tracks.thumbnails.textures.has(key) or s.tracks.thumbnails.inactive.has(key)),"Visible actual sprite/effect previews finish without source errors before the usable UI capture")
    var body_count=0
    if not body_rows.is_empty():
        for key in s.tracks.thumbnails.textures:
            if ":"+body_rows[0].id+":" in key:body_count+=1
    check(body_count>0,"TakeDamage timeline has actual composed sprite previews, not preparation placeholders")
    evidence.visible_thumbnails={"awaited_keys":keys.size(),"ready_ms":Time.get_ticks_msec()-started,"take_damage_previews":body_count}
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/transport")
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/studio/transport/study-ready.png")
func run()->void:
    had_layout=FileAccess.file_exists(Studio.CONFIG)
    if had_layout:saved_layout=FileAccess.get_file_as_string(Studio.CONFIG)
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,720)
    var s=Studio.new();root.add_child(s)
    s._load(Fixtures.journal("gallery"))
    if not await settle(s):await finish(s);return
    check(s.active_directory==Fixtures.journal("gallery"),"Transport starts from the unchanged durable Gallery, independent of production library ordering")
    check(s.loop_enabled and s.loop_button.button_pressed,"Loop is enabled by default")
    var world=s.world
    s._seek(s.world.timeline.display_ms)
    check(s.world==world and s.seeker==null and not s.installing,"Selecting current time does not rebuild the displayed world")
    s.tracks.filter="TakeDamage";s.tracks.rebuild_rows()
    var preparation:Dictionary=s.tracks.prepare_visible()
    s._seek(s.world.timeline.display_ms,true)
    check(s.world==world and s.seeker==null and not s.installing,"Same-clock play after revealing different tracks retains the actual renderer")
    check(not s.world.timeline.paused,"Same-clock play resumes while optional source previews finish")
    if not await settle(s):await finish(s);return
    check(not s.world.timeline.paused,"Optional source previews do not pause recorded playback")
    s._toggle_play();s.tracks.filter="";s.tracks.rebuild_rows()
    var bodies=s.index.rows.filter(func(r):return r.kind=="body" and r.end_ms>r.start_ms)
    var body:Dictionary=bodies.filter(func(r):return r.track.clip=="TakeDamage")[0]
    s.tracks.reveal(body.id)
    var tracks_deadline=Time.get_ticks_msec()+30000
    while not s.tracks.prepare_visible().settled and Time.get_ticks_msec()<tracks_deadline:await process_frame
    var y=s.tracks.RULER-s.tracks.scroll_y
    for item in s.tracks.rows:
        if item.row.id==body.id:break
        y+=s.tracks._height(item.row)
    var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
    click.position=Vector2(s.tracks.gutter-20,y+20)
    var started=Time.get_ticks_msec();s.tracks._gui_input(click)
    if not await settle(s):await finish(s);return
    evidence.select_to_ready_ms=Time.get_ticks_msec()-started
    check(s.selected_row.id==body.id and s.loop_start==body.start_ms and s.loop_end==body.end_ms,"Track-label selection sets the exact clicked animation interval")
    check(not s.world.timeline.paused,"Selected animation starts without a separate Play click")
    var wraps=0;var last=s.world.timeline.display_ms;var end_wait=-1;var max_wait=0
    var frame_times:Array=[];var last_frame=Time.get_ticks_usec()
    var seen_hosts={};var max_hosts=0
    var deadline=Time.get_ticks_msec()+30000
    while wraps<3 and Time.get_ticks_msec()<deadline:
        await process_frame
        var now=Time.get_ticks_usec();frame_times.append((now-last_frame)/1000.0);last_frame=now
        seen_hosts[s.world.get_instance_id()]=true;max_hosts=maxi(max_hosts,host_count(s))
        var at=s.world.timeline.display_ms
        if at>=s.loop_end-.001 and end_wait<0:end_wait=Time.get_ticks_msec()
        if at<last:
            wraps+=1
            if end_wait>=0:max_wait=maxi(max_wait,Time.get_ticks_msec()-end_wait)
            end_wait=-1
            var reference=Studio.Recording.restore(s.index,at)
            check(s.world.timeline.sequence==reference.sequence and s.world.timeline.state.actors==reference.state.actors,"Prepared loop restores exact authoritative participant state: "+str(wraps))
        last=at
    evidence.loop_wraps=wraps;evidence.max_loop_end_hold_ms=max_wait;evidence.loop_visible_hosts=seen_hosts.size();evidence.max_hosts=max_hosts
    frame_times.sort()
    if not frame_times.is_empty():evidence.loop_frame_ms={"median":frame_times[frame_times.size()/2],"p95":frame_times[mini(frame_times.size()-1,int(frame_times.size()*.95))],"max":frame_times.back()}
    check(wraps==3,"Selected interval repeats automatically")
    check(seen_hosts.size()==2 and max_hosts<=2,"Three loops alternate exactly two existing hosts without accumulating native worlds")
    check(s.transport_measurements.filter(func(row):return row.get("loop",false) and row.get("reused_spare",false)).size()>=2,"Warm loops prepare the existing spare rather than constructing another renderer")
    s._toggle_play();await process_frame
    check(s.world.timeline.paused and not s.preparing_loop,"Pause works during background loop preparation")
    var interval:float=body.end_ms-body.start_ms
    await scrub(s,body.start_ms+interval*.3,body.start_ms+interval*.8,body.start_ms+interval*.45)
    await scrub(s,body.start_ms+interval*.45,body.start_ms+interval*.1,body.start_ms+interval*.7)
    var unchanged_index:Dictionary=s.index;var unchanged_rows:Array=s.index.rows
    var unchanged_world=s.world;var table=s.world.light_table
    var textures:Dictionary=s.world.textures.duplicate()
    var before_projection=projection(s.world);var before_pane=s.preview.size
    var divider=Vector2(s.split.global_position.x+s.split.size.x*.5,(s.preview.global_position.y+s.preview.size.y+s.bottom.global_position.y)*.5)
    root_button(divider,true);root_motion(divider+Vector2(0,-45),Vector2(0,-45));root_button(divider+Vector2(0,-45),false)
    await process_frame;await process_frame;await process_frame
    check(s.preview.size.y!=before_pane.y,"Native splitter responds to actual pointer drag")
    check(projection(s.world).distance_to(before_projection)<.01,"Dragging actual Studio divider keeps native world pixel scale unchanged")
    check(s.world==unchanged_world and is_same(s.index,unchanged_index) and is_same(s.index.rows,unchanged_rows),"Divider resize preserves the renderer, recording and resolved track objects")
    var rotation_times=[]
    for turn in 4:
        var started_rotation=Time.get_ticks_msec();var quarter:int=s.world.quarter
        s.preview.grab_focus()
        var key=InputEventKey.new();key.physical_keycode=KEY_E;key.pressed=true
        s._unhandled_key_input(key)
        var rotation_deadline=Time.get_ticks_msec()+30000
        while s.world.rotation_pending() and Time.get_ticks_msec()<rotation_deadline:await process_frame
        rotation_times.append(Time.get_ticks_msec()-started_rotation)
        check(s.world.quarter==posmod(quarter+1,4) and not s.world.rotation_pending(),"Actual preview rotation key publishes prepared quarter "+str(turn))
        check(s.world==unchanged_world and is_same(s.index,unchanged_index) and is_same(s.index.rows,unchanged_rows) and s.loader==null and s.seeker==null,"Camera rotation preserves resolved tracks and does not reindex or restore the recording")
        check(s.world.light_table==table,"Camera rotation retains the existing receiving light table")
    var same_sources=0
    for path in textures:
        if s.world.textures.get(path)==textures[path]:same_sources+=1
    check(same_sources==textures.size(),"All resident immutable GPU source handles survive divider drag and four camera rotations")
    evidence.rotation_ready_ms=rotation_times;evidence.retained_texture_handles=same_sources
    var report=Studies.build({},s.case_records);var cap={};var scenario={};var record={}
    for c in report.capabilities:
        for study in c.scenarios:
            if study.id=="base.AT01":
                cap=c;scenario=study
                for binding in study.recordings:
                    if binding.available:record=binding.record;break
                break
        if not record.is_empty():break
    check(not record.is_empty(),"Current AT01 nonlethal study references a real production library recording; retired melee-seed3 cannot qualify it")
    if not record.is_empty():
        var previous_study=s.study_scenario;var previous_world=s.world
        s._open_study_recording(cap,scenario,record)
        check(s.study_scenario==previous_study and s.world==previous_world,"Pending study does not relabel the retained previous preview")
        if not await settle(s):await finish(s);return
        check(s.study_scenario.id==scenario.id and s.active_case.id==record.id,"Study expectations publish together with their matching scene")
        check(s.capability_picker.get_item_text(s.capability_picker.selected)==record.capability and s.case_picker.get_item_text(s.case_picker.selected)==record.label,"Header labels switch to the actual newly published study instead of retaining the previous case")
        check(not s.study_panel.visible and not s.study_button.disabled,"Study expectations remain available without opening extra text by default")
        s.study_button.pressed.emit()
        check(s.study_panel.visible,"Study button opens the selected expectations on demand")
        s.study_button.pressed.emit()
        check(not s.world.timeline.paused,"Changing recorded study starts playback automatically")
        s._toggle_play();await process_frame
        await capture_ready(s)
        var selected_study=s.study_scenario
        var retained_world=s.world;var retained_clock:float=s.world.timeline.display_ms;var retained_texture=s.preview.texture
        s._load("res://.runtime/does-not-exist-study-transport")
        if not await settle(s):await finish(s);return
        check(s.study_scenario==selected_study and s.pending_study_selection.is_empty(),"Rejected recording retains the matching study and clears pending metadata")
        check(s.world==retained_world and s.world.timeline.display_ms==retained_clock and s.preview.texture==retained_texture and s.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"Failed source selection retains the exact world/clock/output without stranding a disabled viewport")
        DirAccess.make_dir_recursive_absolute("res://.captures/studio/transport")
        await process_frame;await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.captures/studio/transport/study.png")
    check(s.world.presentation_errors.is_empty(),"No render errors in actual selections/loops")
    evidence.preparations=s.transport_measurements.duplicate(true)
    await finish(s)
func finish(s:Control)->void:
    s.queue_free();await process_frame;await process_frame
    if had_layout:FileAccess.open(Studio.CONFIG,FileAccess.WRITE).store_string(saved_layout)
    else:DirAccess.remove_absolute(ProjectSettings.globalize_path(Studio.CONFIG))
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Native actual track-label/ruler/splitter/key input, exact forward/backward seek, three causal two-host loops, retained source/track/light-table handles, no-op seek, study/case atomic publication and rejected case retention."}
    FileAccess.open("res://generated/studio_transport_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_TRANSPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
