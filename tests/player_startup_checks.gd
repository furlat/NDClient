extends SceneTree
# Real launcher/server and native texture publication. Startup must not wait for
# the optional whole animation family; exact displayed sources still gate input.
const Player = preload("res://play.tscn")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    root.unfocusable = true
    root.position = Vector2i(-16000,-16000)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var started = Time.get_ticks_msec()
    var scene = Player.instantiate()
    root.add_child(scene)
    while not scene.command_ready() and scene.session.issue.is_empty() and scene.presentation_errors.is_empty() and Time.get_ticks_msec()-started<120000:
        await process_frame
    var ready_ms = Time.get_ticks_msec()-started
    check(scene.command_ready(),"Native current choices become playable")
    check(scene.media_initial_ready and scene.MediaWarmup.ready(scene.media_warmup,scene.media_plan.required),"Every exact displayed character source is uploaded before input")
    check(scene._environment_sources_ready(),"Every displayed environment source is uploaded before input")
    check(scene.timeline.state==scene.session.journal.state,"Startup exposes the canonical initial state")
    check(scene.session.issue.is_empty() and scene.presentation_errors.is_empty(),"Startup has no transport or authored presentation error")
    var progress = scene.MediaWarmup.preload_progress(scene.media_warmup)
    var report = {"checks":checks,"failures":failures,"ready_elapsed_ms":ready_ms,
        "renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
        "progress":progress,"characters":scene.MediaWarmup.diagnostics(scene.media_warmup),
        "environment":scene.MediaWarmup.diagnostics(scene.media_warmup,true),
        "notes":"Real live initialization through first playable choices. Engine launch/import excluded; operating-system file-cache warmth is uncontrolled. This is startup evidence, not an isolated gameplay GPU benchmark."}
    scene.set_process(false)
    FileAccess.open(scene.game_config.test_result,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    FileAccess.open("res://generated/player_startup_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PLAYER_STARTUP_CHECKS ",JSON.stringify(report))
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
