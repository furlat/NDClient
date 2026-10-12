extends SceneTree
# Native reproducible profile of actual recorded packets, including cold actor
# admissions. Fixed presentation steps let before/after runs visit identical states.
const Player = preload("res://play.tscn")
func _initialize() -> void: run.call_deferred()
func run() -> void:
    if "--background-check" in OS.get_cmdline_user_args():
        root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var scene = Player.instantiate()
    # Preserve the earlier profile's translucency setting for comparison.
    scene.wall_mode = "translucent"
    scene.timeline.paused = true
    scene.profile.recording = true
    scene.profile.label = "initialization"
    root.add_child(scene)
    var deadline = Time.get_ticks_msec()+120000
    while not scene.session.recording_ready and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    await scene.presentation_updated
    if not scene.session.issue.is_empty() or scene.timeline.state.is_empty():
        push_error("Profile could not admit recorded state: "+str(scene.session.issue)); quit(1); return
    scene.profile.label = "playback"
    var steps = 0
    var advanced_steps = 0
    var loading_held_frames = 0
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and steps < 20000:
        var previous_time: float = scene.timeline.display_ms
        var advance_started = Time.get_ticks_usec()
        scene.timeline.paused = false
        scene.timeline.advance(1000.0/60.0)
        scene.timeline.paused = true
        scene.FrameProfile.end_phase(scene.profile,"manual_timeline_advance",advance_started)
        steps += 1
        if scene.timeline.display_ms > previous_time: advanced_steps += 1
        elif scene.timeline.waiting_for_media: loading_held_frames += 1
        await scene.presentation_updated
    scene.profile.label = "first_inventory_open"
    var inventory_started = Time.get_ticks_usec()
    scene.hud.toggle_inventory()
    print("FIRST_INVENTORY_OPEN cpu_ms=",(Time.get_ticks_usec()-inventory_started)/1000.0," disclosed_item_count=",scene.hud.inventory_buttons.size())
    for i in range(60): await scene.presentation_updated
    scene.hud.toggle_inventory()
    scene.profile.label = "settled"
    for i in range(300): await scene.presentation_updated
    scene.profile.label = "wide"
    scene.camera.size = 40.0
    for i in range(300): await scene.presentation_updated
    for mode in ["solid","hidden"]:
        scene.profile.label = mode+"_wide"
        scene.wall_mode = mode; scene.update_wall_visibility()
        for i in range(300): await scene.presentation_updated
    var label = "recorded-player"
    var args = OS.get_cmdline_user_args()
    for i in range(args.size()-1):
        if args[i] == "--profile-label": label = args[i+1]
    scene.FrameProfile.save(scene.profile,root,label)
    var matches: bool = scene.timeline.state == scene.session.journal.state
    var complete: bool = not scene.timeline.busy() and scene.timeline.sequence==scene.session.journal.cursor.sequence and scene.timeline.sequence==scene.session.latest_sequence and scene.session.terminal
    var clean: bool = scene.presentation_errors.is_empty() and scene.session.issue.is_empty()
    print("PROFILE_COMPLETE iterations=",steps," advanced_steps=",advanced_steps," loading_held_frames=",loading_held_frames," display_ms=",scene.timeline.display_ms," canonical_match=",matches," drained=",complete," errors=",scene.presentation_errors)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.captures/player/"+label+".png")
    scene.queue_free(); await process_frame
    quit(0 if matches and complete and clean else 1)
