extends SceneTree
## Real single-preview replay controls and independently selected faction journals.
const Studio=preload("res://studio/studio.gd")
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var prefix_ordinals:Dictionary={}
var report_path="res://generated/studio_replay_native_checks.json"
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("REPLAY_NATIVE_FAIL ",label)
func settle(studio:Control,requested_time:float=-1.0,requested_directory:String="")->bool:
    var diagnostic_at:int=Time.get_ticks_msec()+3000
    var diagnostic_emitted:bool=false
    var deadline=Time.get_ticks_msec()+90000
    while (studio.index.is_empty() or studio.loader!=null or (not studio.preparing_loop and (studio.seeker!=null or studio.installing or studio.requested_seek>=0))) and Time.get_ticks_msec()<deadline:
        if not diagnostic_emitted and Time.get_ticks_msec()>=diagnostic_at:
            diagnostic_emitted=true
            if studio.candidate_world!=null:print("STUDIO_WAIT_DIAGNOSTIC ",JSON.stringify({"requested_ms":requested_time,"candidate":studio.candidate_world._detailed_frame_context(false)}))
        await process_frame
    var ready=not studio.index.is_empty() and studio.loader==null and (studio.preparing_loop or (studio.seeker==null and not studio.installing and studio.requested_seek<0))
    ready=ready and not studio.status.text.begins_with("Candidate rejected") and not studio.status.text.begins_with("Recording rejected")
    ready=ready and studio.world.presentation_errors.is_empty() and studio.world.media_issue.is_empty()
    if ready and requested_time>=0:ready=is_equal_approx(studio.world.timeline.display_ms,requested_time)
    if ready and not requested_directory.is_empty():ready=studio.active_directory==requested_directory
    if not ready:
        var details:Dictionary={"requested_ms":requested_time,"status":studio.status.text,"replay":studio.replay_diagnostics()}
        if studio.candidate_world!=null:
            details.candidate=studio.candidate_world._detailed_frame_context(false)
        evidence.append({"installation_failure":details})
        print("STUDIO_INSTALLATION_DIAGNOSTIC ",JSON.stringify(details))
    check(ready,"Single preview installation ready: "+studio.status.text)
    return ready
func prefix_shape(timeline)->Dictionary:
    var commits:Array=[]
    for commit in timeline.current.get("commits",[]):
        commits.append({"at_ms":commit.at_ms,"absolute_ms":timeline.group_start_ms+commit.at_ms,
            "fields":commit.delta.keys(),"event":commit.get("event_uuid","")})
    return {"display_ms":timeline.display_ms,"group_start_ms":timeline.group_start_ms,"sequence":timeline.sequence,
        "completed":timeline.completed_group_count,"commit_index":timeline.commit_index,"world_revision":timeline.world_revision,
        "current":timeline.current.get("id",""),"duration_ms":timeline.current.get("duration_ms",0.0),"commits":commits,
        "queued":timeline.queue.size(),"cursor":timeline.state.get("reducer_cursor")}
func prefix_diff(actual:Variant,expected:Variant,path:String,output:Array)->void:
    if actual==expected or output.size()>=32:return
    if actual is Dictionary and expected is Dictionary:
        var keys:Array=actual.keys()
        for key in expected:
            if not actual.has(key):keys.append(key)
        for key in keys:prefix_diff(actual.get(key),expected.get(key),path+"/"+str(key),output)
    elif actual is Array and expected is Array and actual.size()==expected.size():
        for i in actual.size():prefix_diff(actual[i],expected[i],path+"/"+str(i),output)
    else:output.append({"path":path,"actual":actual,"expected":expected})
func yielded_recorded_prefix(index:Dictionary,timeline)->RefCounted:
    # Live publication intentionally yields after one world cut. A clock at a
    # group endpoint can therefore name several different ordered prefixes.
    var count:int=timeline.completed_group_count
    if not timeline.current.is_empty() or count<=0 or count>=index.groups.size():return null
    var item:Dictionary=index.groups[count-1]
    if timeline.display_ms!=item.start_ms+float(item.group.duration_ms):return null
    var next:Dictionary=index.groups[count]
    if float(next.start_ms)>timeline.display_ms or timeline.queue.is_empty() or timeline.queue[0].id!=next.group.id:return null
    var world_cut:bool=item.group.commits.any(func(commit):return float(commit.at_ms)==float(item.group.duration_ms) and timeline._world_delta(commit.delta))
    world_cut=world_cut or float(item.group.duration_ms) in item.group.get("actor_structure_times",[]) or not item.group.get("staged_tiles",{}).is_empty()
    if not world_cut and not timeline.waiting_for_media and not timeline.waiting_for_world:return null
    return Recording.restore_boundary(index,count-1,item.group.commits.size())
func verify_prefix(studio:Control,label:String,allow_atomic_yield:bool=false)->void:
    for pane in [{"world":studio.world,"perspective_id":studio.active_perspective}]:
        var actual=pane.world.timeline
        var index:Dictionary=studio.case_bundle.views[pane.perspective_id]
        var expected=Recording.restore(index,actual.display_ms)
        var exact_yield:RefCounted=yielded_recorded_prefix(index,actual) if allow_atomic_yield else null
        if exact_yield!=null:expected=exact_yield
        var prior:Dictionary=prefix_ordinals.get(actual.get_instance_id(),{})
        if not prior.is_empty():check(actual.completed_group_count>=prior.ordinal,label+": published source ordinals never regress")
        prefix_ordinals[actual.get_instance_id()]={"ordinal":actual.completed_group_count}
        for i in actual.completed_groups.size():
            var ordinal:int=actual.completed_group_count-actual.completed_groups.size()+i
            check(ordinal>=0 and ordinal<index.groups.size() and actual.completed_groups[i].id==index.groups[ordinal].group.id,
                label+": completed source groups preserve every recorded ID in order")
        if actual.state!=expected.state or actual.completed_group_count!=expected.completed_group_count or actual.commit_index!=expected.commit_index or actual.current.get("id","")!=expected.current.get("id",""):
            var difference:Array=[];prefix_diff(actual.state,expected.state,"",difference)
            var failure:Dictionary={"failure":"prefix","label":label,"directory":studio.active_directory,"perspective":pane.perspective_id,
                "actual":prefix_shape(actual),"expected":prefix_shape(expected),"difference":difference}
            evidence.append(failure)
            FileAccess.open("res://.runtime/studio-prefix-failure.json",FileAccess.WRITE).store_string(JSON.stringify(failure,"  "))
        check(actual.state==expected.state,label+": "+pane.perspective_id+" owns exact admitted prefix")
        check(actual.completed_group_count==expected.completed_group_count and actual.commit_index==expected.commit_index and actual.current.get("id","")==expected.current.get("id",""),label+": "+pane.perspective_id+" owns the exact ordered source cut")
        check(pane.world.session==null,label+": no live Session")
        for id in actual.state.actors:
            var disclosed=Studio.Play.WorldRows.visible_actor(actual.state.actors[id],actual.state,actual.staged_actors().has(id))
            check(disclosed or not pane.world.visual_actors.has(id),label+": undisclosed actor absent from native pane")
    check(studio.world.component_renderer.audio.enabled,label+": selected faction is audible")
    check(studio.world.presentation_errors.is_empty() and not studio.world.publication_failed,label+": displayed native owner has no publication errors")
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
    var atomic_targets:Dictionary={};var atomic_seen:Dictionary={}
    if label=="hide-light-schema9-seed3":
        for i in range(studio.index.groups.size()-1):
            var item:Dictionary=studio.index.groups[i];var next:Dictionary=studio.index.groups[i+1]
            var end:float=item.start_ms+float(item.group.duration_ms)
            if item.group.duration_ms>0 and next.group.duration_ms==0 and next.start_ms==end:
                atomic_targets[i+1]={"at_ms":end,"group":item.group.id}
        check(atomic_targets.size()>=2,label+": real recording includes both positive-duration cuts followed by zero-time tails")
    while not studio.world.timeline.paused and Time.get_ticks_msec()<deadline:
        await process_frame
        var now=Time.get_ticks_usec();longest=maxf(longest,(now-last)/1000.0);last=now;frames+=1
        var timeline=studio.world.timeline
        if timeline.current.is_empty() and atomic_targets.has(timeline.completed_group_count) and not atomic_seen.has(timeline.completed_group_count):
            var cut:Dictionary=atomic_targets[timeline.completed_group_count]
            check(timeline.display_ms==cut.at_ms,label+": native atomic cut uses the exact recorded absolute clock")
            verify_prefix(studio,label+" atomic cut "+str(timeline.completed_group_count),true)
            atomic_seen[timeline.completed_group_count]=true
        if studio.world.timeline.display_ms>=next_sample:
            verify_prefix(studio,label+" playback "+str(studio.world.timeline.display_ms),true);next_sample=studio.world.timeline.display_ms+150.0
        if not failures.is_empty():break
    if not studio.world.timeline.paused:
        var w=studio.world;var pw=w.pending_world
        print("PLAYBACK_STALL ",JSON.stringify({"display_ms":w.timeline.display_ms,"waiting_media":w.timeline.waiting_for_media,"busy":w.timeline.busy(),
            "world_revision":w.world_revision,"pending":pw!=null,"phase":pw.phase if pw!=null else "","atlas_stage":pw.atlas_stage if pw!=null else "",
            "prepared":pw.prepared if pw!=null else false,"media_issue":w.media_issue,"errors":w.presentation_errors.slice(0,3),
            "media_gate":w.media_gate,"rotation":w.rotation_pending()}))
    check(studio.world.timeline.paused,label+": reaches stop")
    check(atomic_seen.size()==atomic_targets.size(),label+": every requested native atomic cut was observed before ordered zero-time tails drained")
    check(is_equal_approx(studio.world.timeline.display_ms,studio.index.presentation_end_ms),label+": reaches actual recorded endpoint")
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
    check(is_equal_approx(studio.world.timeline.display_ms,studio.index.presentation_end_ms),"Measured single preview reaches actual endpoint")
    check(not studio.world.timeline.busy(),"Measured single preview drains every due recorded group")
    check(max_hosts<=2,"Single preview plus prepared/spare host stays bounded at two")
    check(not durations.is_empty(),"Measured replay renders actual playback frames")
    if durations.is_empty():return
    durations.sort()
    evidence.append({"measurement":"native_single_no_oracle","case":studio.active_directory,"frames":durations.size(),"median_frame_ms":durations[durations.size()/2],"p95_frame_ms":durations[int(durations.size()*.95)],"max_frame_ms":durations.back(),"max_texture_bytes":max_texture_bytes,"max_buffer_bytes":max_buffer_bytes,"max_play_hosts":max_hosts,"note":"Whole native process frame interval; includes ordinary replay preparation, excludes test restore oracles and captures."})
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/studio/replay-comparison"))
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    if not await settle(studio):await finish(studio);return
    var movement_directory="res://.runtime/studio-cases/movement-oa/journal"
    if studio.active_directory!=movement_directory:
        studio._load(movement_directory)
        if not await settle(studio,0,movement_directory):await finish(studio);return
    check(studio.replay_diagnostics().panes.size()==1,"Real movement/OA recording opens one rendered audience")
    verify_prefix(studio,"initial movement/OA")
    var duration=float(studio.index.presentation_end_ms)
    for fraction in [.45,.9,.1,.45]:
        studio._seek(duration*fraction)
        if not await settle(studio,duration*fraction):break
        verify_prefix(studio,"Movement/OA seek "+str(fraction))
        check(str(studio.perspective_picker.get_item_metadata(studio.perspective_picker.selected))==studio.active_perspective,"Faction picker survives seek")
        if fraction==.45:await save_capture(studio,"hide-mid")
    studio.select_perspective(studio.active_perspective)
    if failures.is_empty():await play_once(studio,"movement-oa")
    if not failures.is_empty():await finish(studio);return
    # Newest request wins even if an older restore is already running.
    studio._seek(duration*.2);await process_frame;studio._seek(duration*.8)
    if await settle(studio,duration*.8):
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
    check(wraps==2,"Real movement/OA loops twice with independent restores")
    studio._toggle_play();studio.loop_enabled=false
    await measure_single(studio)
    for name in ["hide-seed3-v3","hide-light-schema9-seed3","invisibility-seed3-v2","oa_jump_lethal-seed5-v2"]:
        var directory="res://.runtime/studio-cases/"+name+"/amber/journal"
        studio._load(directory)
        if not await settle(studio,0,directory):break
        check(studio.replay_diagnostics().panes.size()==1,name+": one selected renderer")
        if name=="hide-seed3-v3":
            verify_prefix(studio,"Hide amber audience")
            studio.select_perspective("blue")
            if not await settle(studio,0,"res://.runtime/studio-cases/"+name+"/blue/journal"):break
            check(studio.active_perspective=="blue","Hide faction switch installs actual Blue journal")
            verify_prefix(studio,"Hide blue audience")
        if name=="invisibility-seed3-v2":
            var cast:Dictionary={}
            for item in studio.index.groups:
                if int(item.group.operation_sequence)==6 and item.group.components.any(func(component):return component.kind=="sprite_layer"):cast=item;break
            check(not cast.is_empty(),"Real See Invisibility cast is available for mid-cast seek")
            if not cast.is_empty():
                var middle:float=cast.start_ms+cast.group.duration_ms*.5
                studio._seek(middle)
                if not await settle(studio,middle):break
                verify_prefix(studio,"Invisibility active-cast seek")
                studio._seek(0)
                if not await settle(studio,0):break
        if name=="hide-light-schema9-seed3":
            var restores=studio.index.rows.filter(func(row):return row.kind=="condition_restore" and row.owner.condition.behavior_id=="condition.hidden" and row.get("source_perspective",studio.active_perspective)==studio.active_perspective)
            check(not restores.is_empty(),"Actual bright-light Hidden removal has a restoration track")
            if not restores.is_empty():
                var row=restores[0]
                for point in [{"offset":-.001,"clip":"CrouchIdle","alpha":.55},{"offset":1.0,"clip":"Idle","alpha":1.0}]:
                    studio._seek(row.transition.condition_removed_ms+point.offset)
                    if not await settle(studio,row.transition.condition_removed_ms+point.offset):break
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
        if name=="invisibility-seed3-v2" and failures.is_empty():
            studio.loop_enabled=true;studio._play_study()
            if not await settle(studio):break
            var wrapped:bool=false
            var previous:float=studio.world.timeline.display_ms
            var limit:int=Time.get_ticks_msec()+30000
            while not wrapped and Time.get_ticks_msec()<limit:
                await process_frame
                var now:float=studio.world.timeline.display_ms
                check(now<=studio.loop_end+.001,"Invisibility loop never advances beyond actual Out")
                if now<previous-.1:
                    wrapped=true;verify_prefix(studio,"Invisibility automatic loop restore")
                previous=now
            check(wrapped,"Real Invisibility automatically loops through a fresh exact reducer restore")
            if not studio.world.timeline.paused:studio._toggle_play()
            studio.loop_enabled=false
        if not failures.is_empty():break
    await finish(studio)
func finish(studio:Control)->void:
    evidence.append({"transport":studio.transport_measurements})
    studio.queue_free();await process_frame;await process_frame
    FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"  "))
    print("STUDIO_REPLAY_NATIVE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
