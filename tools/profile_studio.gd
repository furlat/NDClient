extends SceneTree
## Real-time observation of normal Studio playback. No manual display stepping,
## screenshots, texture readbacks or output writes inside the measured window.
const Studio=preload("res://studio/studio.gd")
const Profile=preload("res://frame_profile.gd")
const CASE="res://generated/studio_gallery_spell_case.json"

class ObservedStudio extends Studio:
    var measured_process_ms:float=0
    var measured_pair_ms:float=0
    var no_prewarm:bool=false
    var observing:bool=true
    func _process(delta:float)->void:
        if not observing:
            super._process(delta)
            return
        measured_pair_ms=0
        var started:int=Time.get_ticks_usec()
        super._process(delta)
        if no_prewarm:
            tracks.thumbnails.prewarm_suspended=true
            if candidate_tracks!=null:candidate_tracks.thumbnails.prewarm_suspended=true
        measured_process_ms=(Time.get_ticks_usec()-started)/1000.0
    func _advance_replay_owners(target:float)->void:
        var started:int=Time.get_ticks_usec()
        super._advance_replay_owners(target)
        measured_pair_ms=(Time.get_ticks_usec()-started)/1000.0

var studio:ObservedStudio
var frames:Array=[]
var failures:Array=[]
var watched:Dictionary={}
var label:String="single"
var output:String=""
var start_ms:float=0
var end_ms:float=20000
var max_wall_seconds:float=120
var warmup_seconds:float=0
var no_prewarm:bool=false
var hide_timeline:bool=false
var no_follow:bool=false
var keep_open:bool=false
var profile_max_fps:int=0
var started_usec:int=0
var previous_usec:int=0
var first_display_ms:float=0
var last_display_ms:float=0
var setup:Dictionary={}

func _initialize()->void:run.call_deferred()

func observe_node(node:Node)->void:
    if node is Viewport:
        RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(),true)
        watched[node.get_instance_id()]={"node":weakref(node),"path":str(node.get_path())}

func owners()->Array:
    return [studio.world]

func ready()->bool:
    if studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0 or not studio.pending_directory.is_empty():return false
    for owner in owners():
        if owner.rotation_pending() or not owner.playback_prepared():return false
    return true

func wait_ready()->bool:
    var deadline:int=Time.get_ticks_msec()+120000
    while Time.get_ticks_msec()<deadline:
        if ready():return true
        await process_frame
    failures.append("Studio preparation timeout: "+studio.status.text)
    return false

func viewport_metrics()->Dictionary:
    var values:Array=[];var expired:Array=[]
    var enabled:int=0;var with_draws:int=0
    var cpu:float=0;var gpu:float=0
    for id in watched:
        var view:Viewport=watched[id].node.get_ref()
        if view==null:expired.append(id);continue
        var mode:int=view.render_target_update_mode if view is SubViewport else -1
        if mode==SubViewport.UPDATE_DISABLED:continue
        enabled+=1
        var rid:RID=view.get_viewport_rid()
        var draw_calls:int=view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
        var cpu_ms:float=RenderingServer.viewport_get_measured_render_time_cpu(rid)
        var gpu_ms:float=RenderingServer.viewport_get_measured_render_time_gpu(rid)
        if draw_calls>0:with_draws+=1
        cpu+=cpu_ms;gpu+=gpu_ms
        values.append({"id":id,"path":watched[id].path,"size":[view.get_visible_rect().size.x,view.get_visible_rect().size.y],"mode":mode,"cpu_ms":cpu_ms,"gpu_ms":gpu_ms,"draw_calls":draw_calls})
    for id in expired:watched.erase(id)
    return {"enabled":enabled,"with_draw_calls":with_draws,"cpu_sum_ms":cpu,"gpu_sum_ms":gpu,"views":values}

func sample(now:int)->void:
    var observing:int=Time.get_ticks_usec()
    var players:Array=[]
    for owner in owners():
        var record:Dictionary={}
        if not owner.profile.frames.is_empty():record=owner.profile.frames[posmod(owner.profile.cursor-1,owner.profile.frames.size())]
        var native_count:int=0
        for component in owner.displayed_components:
            if component.get("native_spell",false):native_count+=1
        players.append({"perspective":"primary" if owner==studio.world else "peer","display_ms":owner.timeline.display_ms,
            "phases":record.get("cpu_ms",{}),"view":record.get("view",{}),"active_motion":record.get("view",{}).get("active_motion",false),
            "native_components":native_count,"held_media":owner.timeline.waiting_for_media,"held_world":owner.timeline.waiting_for_world,
            "source_receivers":owner.native_light_atlas.live_receivers,"atlas_pixels":owner.native_light_atlas.packed_pixels,
            "native_handles":owner.component_renderer.native_spells.handles.size(),"camera_size":owner.camera.size})
    var cache:RefCounted=studio.tracks.thumbnails
    var view:Dictionary=viewport_metrics()
    var display:float=studio.world.timeline.display_ms
    var followed:String=studio.tracks.followed_row
    var lane:String=studio.tracks.display_row_for.get(followed,followed)
    var followed_visible:bool=studio.tracks.followed_visible()
    frames.append({"engine_frame":Engine.get_process_frames(),"wall_ms":(now-started_usec)/1000.0,"frame_ms":(now-previous_usec)/1000.0,
        "display_ms":display,"display_advance_ms":display-last_display_ms,"studio_process_ms":studio.measured_process_ms,"pair_advance_ms":studio.measured_pair_ms,
        "engine_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
        "render_setup_ms":RenderingServer.get_frame_setup_time_cpu(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "root_render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
        "root_render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
        "pipeline_compilations":Profile.pipeline_compilations(),
        "players":players,"viewports":view,"pair_waiting":false,"pair_wait_frames":0,
        "follow":{"source":followed,"lane":lane,"visible":followed_visible,"scroll_y":studio.tracks.scroll_y,
            "origin_ms":studio.tracks.origin_ms,"pixels_per_second":studio.tracks.pixels_per_second,
            "playhead_visible":studio.tracks._x(display)>=studio.tracks.gutter and studio.tracks._x(display)<=studio.tracks.size.x,
            "rows":studio.tracks.rows.size()},
        "thumbnails":{"pending":cache.pending.size(),"optional_pending":cache.warm_pending.size(),"ordinary_composites":cache.composites.size(),
            "native_composites":cache.native_composites.size(),"worker_active":cache.worker!=null and cache.worker.is_alive(),"active_job":not cache.active.is_empty(),
            "native_disk_hits":cache.native_store.hits,"native_disk_misses":cache.native_store.misses,"source_reads":cache.source_reads,"source_hits":cache.source_hits,
            "resident":cache.textures.size(),"bytes":cache.texture_bytes,"prewarm_suspended":cache.prewarm_suspended,
            "cpu_ms":studio.tracks.frame_cpu_ms,"candidate_cpu_ms":studio.candidate_tracks.frame_cpu_ms if studio.candidate_tracks!=null else {}},
        "observer_ms":(Time.get_ticks_usec()-observing)/1000.0})
    previous_usec=now;last_display_ms=display

func distribution(field:String)->Dictionary:
    return Profile.distribution(frames.map(func(frame):return float(frame.get(field,0))))

func summary()->Dictionary:
    var result:Dictionary={}
    result.frames_over_ms={}
    for threshold in [10.0,16.667,33.333,100.0]:
        result.frames_over_ms[str(threshold)]=frames.filter(func(frame):return frame.frame_ms>threshold).size()
    for field in ["frame_ms","display_advance_ms","studio_process_ms","pair_advance_ms","engine_process_ms","render_setup_ms","draw_calls","root_render_cpu_ms","root_render_gpu_ms","observer_ms"]:result[field]=distribution(field)
    var player_phases:Dictionary={};var view_times:Dictionary={};var atlas_phases:Dictionary={};var thumbnail_phases:Dictionary={}
    for frame in frames:
        for player in frame.players:
            if not player_phases.has(player.perspective):player_phases[player.perspective]={}
            for phase in player.phases:
                if not player_phases[player.perspective].has(phase):player_phases[player.perspective][phase]=[]
                player_phases[player.perspective][phase].append(player.phases[phase])
            for phase in player.view.get("native_2d_reconcile_phases",{}):
                if not str(phase).ends_with("_ms"):continue
                if not atlas_phases.has(phase):atlas_phases[phase]=[]
                atlas_phases[phase].append(player.view.native_2d_reconcile_phases[phase])
        for owner in ["cpu_ms","candidate_cpu_ms"]:
            var phases:Dictionary=frame.thumbnails.get(owner,{})
            if phases.get("frame",-1)!=frame.engine_frame:continue
            for phase in ["visible","optional","poll","total"]:
                if not phases.has(phase):continue
                var key:String=owner+"/"+phase
                if not thumbnail_phases.has(key):thumbnail_phases[key]=[]
                thumbnail_phases[key].append(phases[phase])
        for view in frame.viewports.views:
            if not view_times.has(view.path):view_times[view.path]={"cpu":[],"gpu":[],"draws":[],"size":view.size}
            view_times[view.path].cpu.append(view.cpu_ms);view_times[view.path].gpu.append(view.gpu_ms);view_times[view.path].draws.append(view.draw_calls)
    result.player_phases={}
    for side in player_phases:
        result.player_phases[side]={}
        for phase in player_phases[side]:result.player_phases[side][phase]=Profile.distribution(player_phases[side][phase])
    result.atlas_reconcile_ms={}
    for phase in atlas_phases:result.atlas_reconcile_ms[phase]=Profile.distribution(atlas_phases[phase])
    result.thumbnail_cpu_ms={}
    for phase in thumbnail_phases:result.thumbnail_cpu_ms[phase]=Profile.distribution(thumbnail_phases[phase])
    result.viewport_times={}
    for path in view_times:
        var row:Dictionary=view_times[path]
        result.viewport_times[path]={"samples":row.gpu.size(),"size":row.size,"cpu_ms":Profile.distribution(row.cpu),"gpu_ms":Profile.distribution(row.gpu),"draw_calls":Profile.distribution(row.draws)}
    return result

func run()->void:
    var startup_started:int=Time.get_ticks_usec()
    var directory:String=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
        elif arg.begins_with("--profile-label="):label=arg.trim_prefix("--profile-label=")
        elif arg.begins_with("--profile-start="):start_ms=float(arg.trim_prefix("--profile-start="))*1000
        elif arg.begins_with("--profile-end="):end_ms=float(arg.trim_prefix("--profile-end="))*1000
        elif arg.begins_with("--profile-wall-limit="):max_wall_seconds=float(arg.trim_prefix("--profile-wall-limit="))
        elif arg.begins_with("--profile-warmup-seconds="):warmup_seconds=maxf(0,float(arg.trim_prefix("--profile-warmup-seconds=")))
        elif arg=="--no-prewarm":no_prewarm=true
        elif arg=="--hide-timeline":hide_timeline=true
        elif arg=="--no-follow":no_follow=true
        elif arg=="--keep-open":keep_open=true
        elif arg.begins_with("--profile-max-fps="):profile_max_fps=maxi(0,int(arg.trim_prefix("--profile-max-fps=")))
    if directory.is_empty() or DisplayServer.get_name()=="headless":printerr("Requires native renderer and --recording=res://journal");quit(2);return
    root.size=Vector2i(1600,960);root.position=Vector2i(40,40);root.unfocusable=true
    Engine.max_fps=profile_max_fps;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    node_added.connect(observe_node);observe_node(root)
    var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CASE))
    studio=ObservedStudio.new();studio.follow_actor_id=fixture.caster_uuid;studio.follow_tracks=true;studio.initial_view_size=12
    studio.loop_enabled=false;studio.no_prewarm=no_prewarm;root.add_child(studio)
    if not await wait_ready():await finish();return
    var first_publication_ms:float=(Time.get_ticks_usec()-startup_started)/1000.0
    var first_sources:Dictionary=studio.world.media_warmup.preload_selected
    var first_resident:int=0
    for path in first_sources:
        if studio.world.textures.has(path):first_resident+=1
    studio.world.timeline.paused=true
    if start_ms>0:
        studio._seek(start_ms)
        if not await wait_ready():await finish();return
    studio.follow_tracks=not no_follow
    if no_follow:studio.follow_actor_id=""
    if hide_timeline:studio.tracks.hide();studio.tracks.set_process(false)
    var deadline:int=Time.get_ticks_msec()+int(warmup_seconds*1000)
    while Time.get_ticks_msec()<deadline:await process_frame
    end_ms=minf(end_ms,studio.index.presentation_end_ms)
    setup={"recording":directory,"resolution":[1600,960],"paired":false,"follow_actor":studio.follow_actor_id,"follow_tracks":studio.follow_tracks,
        "first_publication_ms":first_publication_ms,"first_selected_sources":first_sources.size(),"first_resident_selected_sources":first_resident,
        "startup_receipt":studio.startup_receipt,
        "view_size":studio.world.camera.size,"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"warmup_seconds":warmup_seconds,
        "start_ms":studio.world.timeline.display_ms,"end_ms":end_ms,"no_prewarm":no_prewarm,"hide_timeline":hide_timeline,"row_count":studio.index.rows.size(),
        "pane_size":[studio.viewport.size.x,studio.viewport.size.y],"peer_pane_size":[]}
    for owner in owners():owner.profile.frames.clear();owner.profile.cursor=0;owner.profile.last_usec=0
    await process_frame;await RenderingServer.frame_post_draw
    started_usec=Time.get_ticks_usec();previous_usec=started_usec;first_display_ms=studio.world.timeline.display_ms;last_display_ms=first_display_ms
    studio._toggle_play()
    print("STUDIO_PROFILE_BEGIN ",label," ",JSON.stringify(setup))
    while studio.world.timeline.display_ms<end_ms and (Time.get_ticks_usec()-started_usec)/1000000.0<max_wall_seconds:
        await process_frame;await RenderingServer.frame_post_draw
        sample(Time.get_ticks_usec())
        if studio.world.timeline.paused:failures.append("Unexpected pause at "+str(studio.world.timeline.display_ms));break
    studio.world.timeline.paused=true
    if studio.world.timeline.display_ms<end_ms:failures.append("Timed window did not reach requested display end")
    await finish()

func finish()->void:
    var wall_ms:float=frames.back().wall_ms if not frames.is_empty() else 0
    var advanced:float=last_display_ms-first_display_ms
    for owner in owners():
        if not owner.media_issue.is_empty():failures.append(owner.media_issue)
        failures.append_array(owner.presentation_errors)
    var report={"label":label,"scope":"Normal real-time Studio/Play process clocks; no manual timeline stepping or pixel readback during measurement.",
        "timing_notes":"Renderer times are last-available per-viewport results and may lag. Per-viewport sums are diagnostic, not a serial GPU critical path. Inclusive Play/Studio phases overlap. Enabled viewport count is distinct from observed draw-call count.",
        "godot":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
        "setup":setup,"samples":frames.size(),"wall_ms":wall_ms,"display_advance_ms":advanced,"display_wall_ratio":advanced/wall_ms if wall_ms>0 else 0,
        "summary":summary(),"failures":failures,"frames":frames}
    var path:String="res://.runtime/studio-profile-"+label+".json"
    FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report))
    print("STUDIO_PROFILE_COMPLETE ",JSON.stringify({"path":path,"samples":frames.size(),"wall_ms":wall_ms,"display_advance_ms":advanced,"display_wall_ratio":report.display_wall_ratio,"frame_ms":report.summary.get("frame_ms",{}),"failures":failures}))
    if keep_open and failures.is_empty():
        studio.observing=false
        node_added.disconnect(observe_node)
        watched.clear();frames.clear()
        studio.loop_start=0.0;studio.loop_end=studio.index.presentation_end_ms
        studio.loop_enabled=true;studio.loop_button.set_pressed_no_signal(true)
        root.unfocusable=false
        studio._toggle_play()
        print("STUDIO_PROFILE_PREVIEW_READY pid=",OS.get_process_id())
        return
    if is_instance_valid(studio):studio.queue_free();await process_frame;await RenderingServer.frame_post_draw;await process_frame
    quit(0 if failures.is_empty() else 1)
