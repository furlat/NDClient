extends SceneTree
## Real single-preview replay controls and independently selected faction journals.
const Studio=preload("res://studio/studio.gd")
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var report_path="res://generated/studio_replay_native_checks.json"
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("REPLAY_NATIVE_FAIL ",label)
func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while (studio.index.is_empty() or studio.loader!=null or (not studio.preparing_loop and (studio.seeker!=null or studio.installing or studio.requested_seek>=0))) and Time.get_ticks_msec()<deadline:await process_frame
    var ready=not studio.index.is_empty() and studio.loader==null and (studio.preparing_loop or (studio.seeker==null and not studio.installing and studio.requested_seek<0))
    check(ready,"Single preview installation ready: "+studio.status.text)
    return ready
func verify_prefix(studio:Control,label:String)->void:
    for pane in [{"world":studio.world,"perspective_id":studio.active_perspective}]:
        var actual=pane.world.timeline
        var expected=Recording.restore(studio.case_bundle.views[pane.perspective_id],actual.display_ms)
        check(actual.state==expected.state,label+": "+pane.perspective_id+" owns exact admitted prefix")
        check(actual.completed_group_count==expected.completed_group_count and actual.commit_index==expected.commit_index and actual.current.get("id","")==expected.current.get("id",""),label+": "+pane.perspective_id+" includes every equal-time cut")
        check(pane.world.session==null,label+": no live Session")
        for id in actual.state.actors:
            var disclosed=Studio.Play.WorldRows.visible_actor(actual.state.actors[id],actual.state,actual.staged_actors().has(id))
            check(disclosed or not pane.world.visual_actors.has(id),label+": undisclosed actor absent from native pane")
    check(studio.world.component_renderer.audio.enabled,label+": selected faction is audible")
    for owner in [studio.world]:
        var members={}
        for entry in owner.static_entries:members[entry.node.get_instance_id()]=true
        check(owner.static_complete_order.all(func(entry):return is_instance_valid(entry.node) and members.has(entry.node.get_instance_id())),label+": cached order owns only current live members")
    for owner in [studio.candidate_world,studio.spare_world]:
        if owner!=null:check(not owner.component_renderer.audio.enabled,label+": private primary silent")
func save_capture(studio:Control,label:String)->void:
    await RenderingServer.frame_post_draw
    var path="res://.captures/studio/replay-comparison/"+label
    studio.viewport.get_texture().get_image().save_png(path+"-primary.png")
    root.get_texture().get_image().save_png(path+"-studio.png")
func play_once(studio:Control,label:String)->void:
    studio.loop_enabled=false;studio._play_study()
    if not await settle(studio):return
    var deadline=Time.get_ticks_msec()+45000
    var next_sample=0.0;var frames=0;var longest=0.0;var last=Time.get_ticks_usec()
    while not studio.world.timeline.paused and Time.get_ticks_msec()<deadline:
        await process_frame
        var now=Time.get_ticks_usec();longest=maxf(longest,(now-last)/1000.0);last=now;frames+=1
        if studio.world.timeline.display_ms>=next_sample:
            verify_prefix(studio,label+" playback "+str(studio.world.timeline.display_ms));next_sample=studio.world.timeline.display_ms+150.0
        if not failures.is_empty():break
    check(studio.world.timeline.paused,label+": reaches stop")
    verify_prefix(studio,label+" terminal")
    check(not studio.world.timeline.busy(),label+": selected terminal prefix drained")
    evidence.append({"case":label,"frames":frames,"functional_max_frame_ms_including_oracle":longest,"diagnostics":studio.replay_diagnostics(),"audio_primary":studio.world.component_renderer.audio.diagnostics()})
func measure_single(studio:Control)->void:
    studio.loop_enabled=false;studio._play_study()
    if not await settle(studio):return
    var durations:Array=[];var last=Time.get_ticks_usec();var deadline=Time.get_ticks_msec()+30000
    var max_hosts=0;var max_texture_bytes=0;var max_buffer_bytes=0
    # No restore/oracle or pixel readback runs in this measured playback window.
    while not studio.world.timeline.paused and Time.get_ticks_msec()<deadline:
        await process_frame
        var now=Time.get_ticks_usec();durations.append((now-last)/1000.0);last=now
        max_hosts=maxi(max_hosts,studio.get_children().filter(func(child):return child is SubViewport and not child.is_queued_for_deletion()).size())
        max_texture_bytes=maxi(max_texture_bytes,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
        max_buffer_bytes=maxi(max_buffer_bytes,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED))
    check(studio.world.timeline.paused,"Measured single preview completes without oracle work")
    check(max_hosts<=2,"Single preview plus prepared/spare host stays bounded at two")
    durations.sort()
    evidence.append({"measurement":"native_single_no_oracle","case":studio.active_directory,"frames":durations.size(),"median_frame_ms":durations[durations.size()/2],"p95_frame_ms":durations[int(durations.size()*.95)],"max_frame_ms":durations.back(),"max_texture_bytes":max_texture_bytes,"max_buffer_bytes":max_buffer_bytes,"max_play_hosts":max_hosts,"note":"Whole native process frame interval; includes ordinary replay preparation, excludes test restore oracles and captures."})
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/studio/replay-comparison"))
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    if not await settle(studio):await finish(studio);return
    check(studio.replay_diagnostics().panes.size()==1,"Real Hide recording opens one rendered faction")
    verify_prefix(studio,"initial Hide")
    studio.select_perspective("blue")
    if not await settle(studio):await finish(studio);return
    verify_prefix(studio,"selected Blue")
    var duration=float(studio.index.presentation_end_ms)
    for fraction in [.45,.9,.1,.45]:
        studio._seek(duration*fraction)
        if not await settle(studio):break
        verify_prefix(studio,"Hide seek "+str(fraction))
        check(str(studio.perspective_picker.get_item_metadata(studio.perspective_picker.selected))==studio.active_perspective,"Faction picker survives seek")
        if fraction==.45:await save_capture(studio,"hide-mid")
    studio.select_perspective(studio.active_perspective)
    if failures.is_empty():await play_once(studio,"hide-seed3-v3")
    if not failures.is_empty():await finish(studio);return
    # Newest request wins even if an older restore is already running.
    studio._seek(duration*.2);await process_frame;studio._seek(duration*.8)
    if await settle(studio):
        check(is_equal_approx(studio.world.timeline.display_ms,duration*.8),"Superseded seek cannot publish old preview")
        verify_prefix(studio,"newest seek")
    var old_size=studio.world.camera.size;var old_height=studio.viewport.size.y
    studio.split.split_offset+=70
    for frame in 5:await process_frame
    check(is_equal_approx(studio.world.camera.size/float(studio.viewport.size.y),old_size/float(old_height)),"Divider preserves world units per pixel")
    # Use the actual complete study loop; verify the selected reducer on each new pass.
    studio.loop_enabled=true;studio._play_study();await settle(studio)
    var wraps=0;var prior=studio.world.timeline.display_ms;var deadline=Time.get_ticks_msec()+45000
    while wraps<2 and Time.get_ticks_msec()<deadline:
        await process_frame
        var current=studio.world.timeline.display_ms
        check(current<=studio.loop_end+.001,"Loop never advances beyond Out")
        if current<prior-.1:wraps+=1;verify_prefix(studio,"loop pass "+str(wraps))
        prior=current
    check(wraps==2,"Real Hide loops twice with independent restores")
    studio._toggle_play();studio.loop_enabled=false
    await measure_single(studio)
    for name in ["hide-light-schema9-seed3","invisibility-seed3-v2","oa_jump_lethal-seed5-v2"]:
        studio._load("res://.runtime/studio-cases/"+name+"/amber/journal")
        if not await settle(studio):break
        check(studio.replay_diagnostics().panes.size()==1,name+": one selected renderer")
        if name=="hide-light-schema9-seed3":
            var restores=studio.index.rows.filter(func(row):return row.kind=="condition_restore" and row.owner.condition.behavior_id=="condition.hidden" and row.get("source_perspective",studio.active_perspective)==studio.active_perspective)
            check(not restores.is_empty(),"Actual bright-light Hidden removal has a restoration track")
            if not restores.is_empty():
                var row=restores[0]
                for point in [{"offset":-.001,"clip":"CrouchIdle","alpha":.55},{"offset":1.0,"clip":"Idle","alpha":1.0}]:
                    studio._seek(row.transition.condition_removed_ms+point.offset)
                    if not await settle(studio):break
                    verify_prefix(studio,"light reveal "+str(point.offset))
                    check(studio.world.playbacks.get(row.actor_uuid,{}).get("clip")==point.clip,"Real light reveal chooses "+point.clip)
                    var layers=0
                    for entry in studio.world.visual_actors.get(row.actor_uuid,{}).get("entries",[]):
                        if not entry.node.visible or entry.role=="shadow":continue
                        layers+=1
                        check(is_equal_approx(float(entry.material.get_shader_parameter("condition_alpha")),point.alpha),"Real light reveal applies authored opacity to "+entry.actor_layer.slot)
                    check(layers>1,"Light reveal renders body and equipped layers")
                    await save_capture(studio,"light-reveal-"+("before" if point.offset<0 else "after"))
        await play_once(studio,name)
        await save_capture(studio,name+"-end")
        if not failures.is_empty():break
    await finish(studio)
func finish(studio:Control)->void:
    evidence.append({"transport":studio.transport_measurements})
    studio.queue_free();await process_frame;await process_frame
    FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"  "))
    print("STUDIO_REPLAY_NATIVE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
