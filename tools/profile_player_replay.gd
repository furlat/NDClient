extends SceneTree
## Normal-clock Play replay with no Studio controls, thumbnails or second world.
## Uses the same recorded schedule as Studio; live HTTP latency is measured by
## live_gallery_checks separately. No readbacks or disk writes during playback.
const Recording=preload("res://studio/recording.gd")
const Media=preload("res://studio/recording_media.gd")
const Play=preload("res://play.gd")
const Profile=preload("res://frame_profile.gd")
const CASE="res://generated/studio_gallery_spell_case.json"
var world:Node3D
var frames:Array=[]
var failures:Array=[]
var label="gallery"
var start_ms=0.0
var end_ms=INF
var caster=""
var reserve_atlas_height=0
var setup:Dictionary={}

func _initialize()->void:run.call_deferred()

func ready()->bool:
    return not world.rotation_pending() and world.playback_prepared()

func healthy()->bool:
    return world.media_issue.is_empty() and world.presentation_errors.is_empty()

func follow()->void:
    var actor:Dictionary=world.visual_actors.get(caster,{})
    for entry in actor.get("entries",[]):
        if entry.role!="shadow" and entry.node.visible:
            var position:Vector3=Play.Placement.contact(actor.row)
            if world.camera_focus!=position:world.camera_focus=position;world.position_camera()
            return

func run()->void:
    if DisplayServer.get_name()=="headless":printerr("Requires native rendering");quit(2);return
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--profile-label="):label=arg.trim_prefix("--profile-label=")
        elif arg.begins_with("--profile-start="):start_ms=arg.trim_prefix("--profile-start=").to_float()*1000
        elif arg.begins_with("--profile-end="):end_ms=arg.trim_prefix("--profile-end=").to_float()*1000
        elif arg.begins_with("--reserve-atlas-height="):reserve_atlas_height=clampi(arg.trim_prefix("--reserve-atlas-height=").to_int(),1024,Play.NativeLightAtlas.MAX_SIZE)
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    root.size=Vector2i(1600,960);root.position=Vector2i(40,40);root.unfocusable=true
    var setup_started:int=Time.get_ticks_usec()
    var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CASE))
    var selected:Dictionary=spec.perspectives.filter(func(view):return str(view.id)=="amber")[0]
    var index=Recording.read(selected.journal)
    if not index.get("ok",false):printerr(index);quit(2);return
    index.media_preload=Media.plan(index);index.cache.merge(index.media_preload.source_files,false)
    var restored=Recording.restore(index,start_ms)
    end_ms=minf(end_ms,index.presentation_end_ms);caster=spec.caster_uuid
    world=Play.new();world.external_playback=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache)
    world.media_warmup.encounter_override=index.media_preload
    root.add_child(world);world.camera.size=12;world.position_camera()
    if reserve_atlas_height>0:world.native_light_atlas.viewport.size=Vector2i(Play.NativeLightAtlas.MAX_SIZE,reserve_atlas_height)
    world.playback_end_ms=end_ms;world.install_playback(restored)
    var deadline:int=Time.get_ticks_msec()+120000
    while not ready() and healthy() and Time.get_ticks_msec()<deadline:await process_frame
    if not ready() or not healthy():failures.append("Initial player preparation failed");await finish(0,0);return
    print("PLAYER_REPLAY_READY ",label)
    setup={"initial_preparation_ms":(Time.get_ticks_usec()-setup_started)/1000.0,"native_startup":Play.NativeStartup.status(),"paused_warmup_seconds":0,
        "start_ms":start_ms,"end_ms":end_ms,"passes":1,"reserved_atlas_height":reserve_atlas_height,
        "scope":"Initial loading and paused warmup measured separately. First uses during the selected action interval remain included. A nonzero start excludes earlier casts."}
    await RenderingServer.frame_post_draw
    print("PLAYER_REPLAY_BEGIN ",label)
    var started:int=Time.get_ticks_usec();var previous:int=started
    var initial_display:float=world.timeline.display_ms
    world.timeline.paused=false
    while world.timeline.display_ms<end_ms-.01 and healthy() and Time.get_ticks_usec()-started<180000000:
        await process_frame
        follow()
        await RenderingServer.frame_post_draw
        var now:int=Time.get_ticks_usec()
        var record:Dictionary=world.profile.frames[posmod(world.profile.cursor-1,world.profile.frames.size())] if not world.profile.frames.is_empty() else {}
        frames.append({"frame":Engine.get_process_frames(),"frame_ms":(now-previous)/1000.0,
            "player_profile_frame":record.get("frame",-1),"pipeline_compilations":Profile.pipeline_compilations(),
            "wall_ms":(now-started)/1000.0,"display_ms":world.timeline.display_ms,
            "cpu_ms":record.get("cpu_ms",{}),"view":record.get("view",{}),
            "held_media":world.timeline.waiting_for_media,"held_world":world.timeline.waiting_for_world,
            "gpu_ms":record.get("gpu_ms",0),"render_cpu_ms":record.get("render_cpu_ms",0)})
        previous=now
    world.timeline.paused=true
    if world.timeline.display_ms<end_ms-.01:failures.append("Playback did not reach its requested endpoint")
    await finish((previous-started)/1000.0,world.timeline.display_ms-initial_display)

func finish(wall_ms:float,display_ms:float)->void:
    if not world.media_issue.is_empty():failures.append(world.media_issue)
    failures.append_array(world.presentation_errors)
    var phases={};var threshold_counts={"10":0,"16.667":0,"33.333":0,"100":0}
    for frame in frames:
        for phase in frame.cpu_ms:
            if not phases.has(phase):phases[phase]=[]
            phases[phase].append(frame.cpu_ms[phase])
        for threshold in threshold_counts:
            if frame.frame_ms>float(threshold):threshold_counts[threshold]+=1
    var phase_summary={}
    for phase in phases:phase_summary[phase]=Profile.distribution(phases[phase])
    var report={"scope":"Full-resolution ordinary Play renderer, normal clock, same composed real Gallery recording as Studio. No Studio UI. This is replay, not live HTTP.",
        "godot":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
        "resolution":[root.size.x,root.size.y],"camera_size":12,"setup":setup,"wall_ms":wall_ms,"display_ms":display_ms,
        "display_wall_ratio":display_ms/wall_ms if wall_ms>0 else 0,"frame_ms":Profile.distribution(frames.map(func(frame):return frame.frame_ms)),
        "frames_over_ms":threshold_counts,"cpu_ms":phase_summary,"failures":failures,"frames":frames}
    var path="res://.runtime/player-replay-profile-"+label+".json"
    FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report))
    print("PLAYER_REPLAY_PROFILE ",JSON.stringify({"path":path,"frame_ms":report.frame_ms,"frames_over_ms":threshold_counts,"failures":failures}))
    world.queue_free();await process_frame;await RenderingServer.frame_post_draw;await process_frame
    quit(0 if failures.is_empty() else 1)
