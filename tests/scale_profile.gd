extends SceneTree
# Same raw backend traversal, fixed causal playback, then four views at two
# scales. Run against both preserved baseline and current source project.
const Player = preload("res://play.tscn")
func _initialize() -> void: run.call_deferred()
func run() -> void:
    if "--background-check" in OS.get_cmdline_user_args():
        root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var scene = Player.instantiate()
    scene.wall_mode = "translucent"
    scene.timeline.paused = true
    scene.profile.recording = true
    scene.profile.label = "initialization"
    root.add_child(scene)
    var deadline = Time.get_ticks_msec()+600000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        await scene.presentation_updated
    if not scene.session.issue.is_empty() or scene.timeline.state.is_empty():
        print("SCALE_PROFILE_FAILED admission ",scene.session.issue); quit(1); return
    scene.profile.label = "traversal"
    var steps = 0
    var advanced_steps = 0
    var exercise_cache = "--exercise-cache-invalidation" in OS.get_cmdline_user_args()
    var cache_prepared = false
    var cache_generation = -1
    var cached_change_seen = false
    var retirement_frames = 0
    var retirement_started = 0
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence or scene.retiring_node_count>0 or retirement_frames>0) and steps<100000 and Time.get_ticks_msec()<deadline:
        if exercise_cache and not cache_prepared and scene.timeline.sequence>=75:
            for view in [1,2,3,0]:
                scene.profile.label = "midroute_prepare_q%d" % view
                scene.request_view(view)
                while scene.rotation_pending() and Time.get_ticks_msec()<deadline: await scene.presentation_updated
                if scene.rotation_pending() or scene.quarter!=view:
                    print("SCALE_PROFILE_FAILED midroute view ",view); scene.queue_free(); await process_frame; quit(1); return
            cache_prepared = true
            cache_generation = scene.world_generation
            scene.profile.label = "traversal_cached_views"
            print("MIDROUTE_CACHE_READY sequence=",scene.timeline.sequence," tiles=",scene.timeline.state.tiles.size()," cached_quarters=",scene.static_views.size())
            if scene.static_views.size()!=3:
                print("SCALE_PROFILE_FAILED missing inactive quarters"); scene.queue_free(); await process_frame; quit(1); return
        if cache_prepared and not cached_change_seen and scene.world_generation!=cache_generation:
            cached_change_seen = true
            retirement_started = Time.get_ticks_usec()
            retirement_frames = 2
            # The invalidating frame was just recorded under cached_views.
            # Include the entire native retirement backlog and two later frames.
            print("MIDROUTE_CACHE_INVALIDATED sequence=",scene.timeline.sequence," cached_quarters=",scene.static_views.size())
        if cached_change_seen and scene.retiring_node_count>0:
            scene.profile.label = "traversal_cached_invalidation"
            retirement_frames = 2
        elif retirement_frames>0:
            scene.profile.label = "traversal_cached_invalidation"
            retirement_frames -= 1
            if retirement_frames==0:
                print("MIDROUTE_RETIREMENT_COMPLETE wall_ms=",(Time.get_ticks_usec()-retirement_started)/1000.0)
        elif cached_change_seen:
            scene.profile.label = "traversal"
        var previous_time: float = scene.timeline.display_ms
        var advance_started = Time.get_ticks_usec()
        scene.timeline.paused = false
        scene.timeline.advance(1000.0/60.0)
        scene.timeline.paused = true
        scene.FrameProfile.end_phase(scene.profile,"manual_timeline_advance",advance_started)
        # Follow the actual observed controlled actor while it crosses rooms.
        var actor: Dictionary = scene.timeline.state.actors.get(scene.timeline.state.current_actor_uuid,{})
        if actor.get("last_visual_position") != null:
            var p: Array = actor.last_visual_position
            scene.camera_focus = Vector3(p[0],0,p[1]); scene.position_camera()
        steps += 1
        if scene.timeline.display_ms > previous_time: advanced_steps += 1
        await scene.presentation_updated
    scene.camera_focus = Vector3(46,0,20)
    for zoom in [20,70]:
        scene.camera.size = zoom
        for quarter in range(4):
            scene.profile.label = "rotate_z%d_q%d" % [zoom,quarter]
            var rotation_started = Time.get_ticks_usec()
            var preparation_frames = 0
            scene.request_view(quarter)
            while scene.rotation_pending() and Time.get_ticks_msec()<deadline:
                preparation_frames += 1
                await scene.presentation_updated
            if scene.rotation_pending() or scene.quarter != quarter:
                print("SCALE_PROFILE_FAILED unfinished camera view ",quarter)
                scene.queue_free(); await process_frame; quit(1); return
            print("ROTATION_COMPLETE zoom=",zoom," quarter=",quarter," preparation_frames=",preparation_frames," wall_ms=",(Time.get_ticks_usec()-rotation_started)/1000.0)
            for i in range(20): await scene.presentation_updated
            scene.profile.label = "gallery_z%d_q%d" % [zoom,quarter]
            for i in range(180): await scene.presentation_updated
    for mode in ["solid","hidden"]:
        scene.profile.label = mode+"_wide"
        scene.wall_mode = mode; scene.update_wall_visibility()
        for i in range(180): await scene.presentation_updated
    var label = "gallery"
    var args = OS.get_cmdline_user_args()
    for i in range(args.size()-1):
        if args[i]=="--profile-label": label = args[i+1]
    scene.FrameProfile.save(scene.profile,root,label)
    var matches: bool = scene.timeline.state==scene.session.journal.state
    var complete: bool = not scene.timeline.busy() and scene.timeline.sequence==scene.session.journal.cursor.sequence and scene.timeline.sequence==scene.session.latest_sequence and scene.session.terminal
    var clean: bool = scene.presentation_errors.is_empty() and scene.session.issue.is_empty() and (not exercise_cache or (cached_change_seen and retirement_frames==0 and scene.retiring_node_count==0))
    print("SCALE_PROFILE_COMPLETE iterations=",steps," advanced_steps=",advanced_steps," display_ms=",scene.timeline.display_ms," completed_groups=",scene.timeline.completed_group_count," final_group=",scene.timeline.completed_groups.back() if not scene.timeline.completed_groups.is_empty() else {}," canonical_match=",matches," drained=",complete," tiles=",scene.timeline.state.tiles.size()," objects=",scene.timeline.state.objects.size()," cached_world_invalidation=",cached_change_seen," errors=",scene.presentation_errors)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/player/"+label+".png")
    scene.queue_free(); await process_frame
    quit(0 if matches and complete and clean else 1)
