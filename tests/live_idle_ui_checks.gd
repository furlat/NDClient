extends SceneTree
## Real connected player, passive native idle interval. Never issues game actions.
const Player = preload("res://play.tscn")
var scene: Node
func _initialize() -> void: run.call_deferred()
func run() -> void:
    root.size = Vector2i(1600,960)
    root.unfocusable = true
    root.position = Vector2i(-16000,-16000)
    scene = Player.instantiate(); root.add_child(scene)
    var deadline = Time.get_ticks_msec()+90000
    while not scene.command_ready() and Time.get_ticks_msec()<deadline:
        if not scene.session.issue.is_empty(): break
        await process_frame
    if not scene.command_ready():
        print("IDLE_CHECK_FAILED ",scene.error_report(scene.notice_text)); quit(1); return
    var started = Time.get_ticks_msec()
    var notices = []
    var last_notice = "unobserved"
    scene.profile.recording = true
    scene.profile.recorded.clear()
    while Time.get_ticks_msec()-started<20000:
        await process_frame
        if scene.notice_text!=last_notice:
            last_notice=scene.notice_text
            notices.append({"elapsed_ms":Time.get_ticks_msec()-started,"message":last_notice,
                "status_issue":scene.session.status_issue,"media_metadata":scene.media_metadata_ready,
                "boot":scene.MediaWarmup.boot_ready(scene.media_warmup),"native":scene.native_startup.ready,
                "sequence":scene.timeline.sequence,"groups":scene.timeline.queue.size()})
    var path = scene.FrameProfile.save(scene.profile,root,"live_idle_ui")
    var report = {"profile":path,"notices":notices,"errors":scene.presentation_errors,
        "sequence":scene.timeline.sequence,"received":scene.session.latest_sequence,
        "scope":"20-second real connected native idle player; zero issued commands."}
    FileAccess.open("res://generated/live_idle_ui_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIVE_IDLE_UI_CHECKS ",JSON.stringify(report))
    scene.queue_free(); await process_frame
    quit(0 if report.errors.is_empty() else 1)
