extends SceneTree
## Studio's admitted playback host does not create a network/admission owner.
## Exercise actual Play startup, shared processing, diagnostics and teardown.
const Play = preload("res://play.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("STUDIO_SESSION_FAIL ",label)

func run() -> void:
    var live = Play.new()
    check(live.session == null,"Constructing a host does not parse a protocol before its role is chosen")
    root.add_child(live)
    check(live.session != null and live.session.protocol.setup_error.is_empty() and live.session.journal.protocol.setup_error.is_empty(),"Live startup still creates the original validated Session and Journal")
    check(live.timeline.retire_group == live.session.retire_group and live.hud != null,"Live playback retains Session retirement and its input HUD")
    check(not live.command_ready(),"Unconnected live host cannot submit a command")
    var displayed = Play.new()
    displayed.external_playback = true
    displayed.catalog_cache = Play.Catalog.source_snapshot(live.catalog_cache)
    root.add_child(displayed)
    check(displayed.session == null and displayed.hud == null and not displayed.timeline.retire_group.is_valid(),"External startup has no live admission, input HUD or Session retirement owner")
    check(displayed.camera != null and displayed.light_table != null,"External startup still creates the production camera and receiving light table")
    await process_frame
    await process_frame
    check(displayed.session == null and displayed.timeline.state.is_empty() and displayed.timeline.sequence == -1,"Shared frame processing cannot create a live Session or fabricate a received prefix")
    check(displayed.presentation_errors.is_empty(),"External shared processing reports no source or lifecycle error")
    check(displayed.presentation_diagnostics().received == -1,"External diagnostics report no network receipt")
    displayed.media_initial_ready = true
    displayed.available_actions = {"entity_uuid":"stale-input"}
    check(not displayed.command_ready(),"Stale input-looking fields cannot enable commands in Studio")
    live.queue_free(); displayed.queue_free()
    await process_frame
    await process_frame
    check(not is_instance_valid(live) and not is_instance_valid(displayed),"Live and session-free external hosts both complete normal scene teardown")
    var report = {"checks":checks,"failures":failures,"scope":"Actual Play startup/frame/teardown and Studio input isolation; no pixels, media readiness or latency claim."}
    FileAccess.open("res://generated/studio_session_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SESSION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
