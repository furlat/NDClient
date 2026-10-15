extends SceneTree
## Whole production Player/HUD over unchanged real initialization + SDK replies.
## This observer submits no commands and does not contact the user's live game.
const Choices = preload("res://sdk/choices.gd")
const Placement = preload("res://placement.gd")
const UI = preload("res://presentation/ui_catalog.gd")
class RecordedSession extends "res://presentation/session.gd":
    var inspect_queries = false
    var inspection_requests: Dictionary = {}
    var inspection_id = 1000000
    func request(operation: String, arguments: Dictionary = {}) -> int:
        if not inspect_queries: return super.request(operation,arguments)
        assert(operation=="preview","Native observer can only query prospective previews")
        inspection_id += 1
        inspection_requests[inspection_id] = arguments.duplicate(true)
        return inspection_id
class RecordedPlayer extends "res://play.gd":
    var inspection_ready = false
    var inspection_hover = false
    func _init() -> void: session = RecordedSession.new()
    func command_ready() -> bool: return inspection_ready
    func _discover() -> void: pass
    func _update_hover() -> void:
        if inspection_hover: super._update_hover()
    func _submit(_intent: Dictionary) -> void: push_error("Recorded preview capture must never submit a command")
var scene: Node
var viewport: SubViewport
var checks = 0
var failures: Array = []
var shots: Array = []
var aim_pointer = Vector2.ZERO
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); printerr("TARGETING_NATIVE_FAIL ",label)
func action(domain: Dictionary, behavior: String, index: float) -> Dictionary:
    for row in Choices.all_actions(domain):
        if row.behavior_id==behavior and row.get("discovery_index",0)==index: return row
    return {}
func screenshot(name: String) -> void:
    await process_frame
    await process_frame
    for i in range(300):
        if not scene.hud.bar_pending() and not UI.images_pending(scene.hud.cache): break
        await process_frame
    check(not scene.hud.bar_pending() and not UI.images_pending(scene.hud.cache),"Whole action bar and native authored icons publish before screenshot")
    check(viewport.get_mouse_position().distance_to(aim_pointer)<2.0,"Captured pointer remains over actual hovered world target")
    scene.hud._update_ground_preview()
    scene._sort_draws()
    await process_frame
    await RenderingServer.frame_post_draw
    var path = "res://.captures/targeting-native/"+name+".png"
    check(viewport.get_texture().get_image().save_png(path)==OK,"Whole Player/HUD screenshot saved: "+name)
    shots.append(path)
func run() -> void:
    if DisplayServer.get_name()=="headless": quit(2); return
    root.unfocusable = true
    root.position = Vector2i(-16000,-16000)
    root.size = Vector2i(320,200)
    viewport = SubViewport.new()
    viewport.size = Vector2i(1600,960)
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var fixture = ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--case="): fixture=arg.trim_prefix("--case=")
    if fixture.is_empty(): printerr("Pass --case and --recording for the same real preview-only fixture"); quit(2); return
    var evidence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
    var domain: Dictionary = evidence.choices
    var fireballs: Array = evidence.records.filter(func(row):return row.behavior=="spell.fireball")
    var missiles: Array = evidence.records.filter(func(row):return row.behavior=="spell.magic_missile")
    DirAccess.make_dir_recursive_absolute("res://.captures/targeting-native")
    scene = RecordedPlayer.new()
    # Initialization contains no active native spell occurrences; use the same
    # exact-empty source preparation plan as an empty recorded Studio preview.
    scene.native_startup_plan = []
    viewport.add_child(scene)
    var deadline = Time.get_ticks_msec()+120000
    while (not scene.session.recording_ready or not scene.playback_prepared() or scene.visual_actors.is_empty() or scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and scene.session.issue.is_empty() and scene.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    check(scene.session.recording_ready and scene.playback_prepared() and not scene.visual_actors.is_empty() and not scene.timeline.busy() and scene.timeline.sequence==scene.session.latest_sequence,"Actual recorded initialization reaches complete native journal/world/media publication")
    if not failures.is_empty(): await finish(fixture); return
    var original = scene.timeline.state.duplicate(true)
    check(original==scene.session.journal.state,"Displayed canonical state equals unchanged original server journal")
    scene.timeline.paused = true
    scene.available_actions = domain
    scene.action_revision = evidence.before_status.boundary.state_revision
    scene.inspection_ready = true
    scene.notice_text = ""
    scene.camera_focus = Vector3(7,0,7)
    scene.camera.size = 12
    scene.position_camera()
    var fireball = action(domain,"spell.fireball",fireballs[0].selection.action_index)
    scene.selected_action = fireball
    scene.selected_mode = fireball.behavior_id
    scene.target_selection = fireballs[0].selection.duplicate(true)
    scene.selection_preview = fireballs[0].preview
    scene.hover_preview = fireballs[1].preview
    scene.hover_intent = {"kind":"target","label":fireball.display_name}
    var selected = Choices.action_options(domain,fireball).filter(func(row):return row.index==fireballs[1].selection.target_indices[0])[0]
    var aim: Array = Choices.binding_position(domain,selected)
    scene.hover_hit = {"kind":"ground","id":"","position":aim,"label":""}
    var mouse = InputEventMouseMotion.new()
    mouse.position = scene.camera.unproject_position(Vector3(aim[0],0,aim[1])); mouse.global_position=mouse.position
    aim_pointer = mouse.position
    viewport.push_input(mouse,true)
    await screenshot("fireball-hover-before-spending")
    var filled = scene.ground_overlay.marks.values().filter(func(style):return style.get("fill_colour",Color.TRANSPARENT).a>0.0)
    check(filled.size()==Choices.preview_positions(fireballs[1].preview,true).size(),"All49 native affected cells have actual filled ground marks")
    check(scene.target_selection.target_indices.is_empty(),"Hovered Fireball area does not select/spend its candidate")
    check(scene.hud.confirm_button.disabled,"Unselected Fireball prefix cannot be confirmed merely by hovering")
    check(scene.hud.hover_info.text.contains("Targets: 6"),"Whole HUD identifies actual six affected Fireball recipients")
    # Actual hover lifetime over rendered production ground: intercept only
    # read-only queries, then publish the saved SDK replies in controlled order.
    scene.session.status = evidence.before_status.duplicate(true)
    scene.session.inspect_queries = true
    scene.inspection_hover = true
    scene.hover_due=0; scene._update_hover()
    var old_request: int = scene.hover_request
    scene.session.responses[old_request]={"ok":true,"value":{"preview":fireballs[1].preview}}
    scene.hover_due=0; scene._update_hover()
    var alternate = Choices.action_options(domain,fireball).filter(func(row):return row.index==fireballs[3].selection.target_indices[0])[0]
    var alternate_aim: Array=Choices.binding_position(domain,alternate)
    mouse.position=scene.camera.unproject_position(Vector3(alternate_aim[0],0,alternate_aim[1]));mouse.global_position=mouse.position
    aim_pointer=mouse.position;viewport.push_input(mouse,true)
    scene.hover_due=0;scene._update_hover()
    var delayed_request: int=scene.hover_request
    check(scene.session.inspection_requests[delayed_request].selection==fireballs[3].selection,"Rendered moved pointer queries exact saved alternate Fireball aim")
    var retained_marks: Dictionary={}
    var retained_revision=-1
    for frame in range(6):
        await process_frame
        scene.hud._update_ground_preview();scene._sort_draws()
        await RenderingServer.frame_post_draw
        if frame==0:
            retained_marks=scene.ground_overlay.marks.duplicate(true)
            retained_revision=scene.ground_overlay.preview_revision
        check(scene.hover_preview==fireballs[1].preview and scene.ground_overlay.marks==retained_marks and scene.ground_overlay.preview_revision==retained_revision,"Native delayed frame%d retains complete filled footprint and eligibility without rebuilding" % frame)
    await screenshot("fireball-moved-query-pending")
    scene.session.responses[delayed_request]={"ok":true,"value":{"preview":fireballs[3].preview}}
    scene.hover_due=0;scene._update_hover()
    await screenshot("fireball-moved-query-published")
    check(scene.hover_preview==fireballs[3].preview,"Native latest reply replaces retained area atomically")
    scene.inspection_hover=false
    var missile = action(domain,"spell.magic_missile",missiles[0].selection.action_index)
    scene.selected_action = missile
    scene.selected_mode = missile.behavior_id
    scene.target_selection = missiles[2].selection.duplicate(true)
    scene.selection_preview = missiles[2].preview
    scene.hover_preview = {}
    scene.hover_intent = {}
    var recipient = Choices.binding_subject(missiles[0].preview,Choices.next_options(missiles[0].preview)[0])
    scene.hover_hit = scene._identity_hit(recipient.uuid)
    mouse.position = scene.hover_hit.get("screen",mouse.position); mouse.global_position=mouse.position
    aim_pointer = mouse.position
    viewport.push_input(mouse,true)
    await screenshot("magic-missile-ordered-prefix")
    check(scene.target_selection.target_indices==missiles[2].selection.target_indices,"Whole-HUD missile view retains actual orderedA/B prefix")
    check(not scene.hud.confirm_button.disabled,"Actual confirmable missile prefix exposes confirmation")
    check(scene.hud.hover_info.text.contains("2 / 3 selected") and scene.hud.hover_info.text.contains("×2") and scene.hud.hover_info.text.contains("×1"),"Whole HUD shows native selected prefix and effective repeated-recipient allocation")
    scene.hud.toggle_history()
    await screenshot("magic-missile-prefix-log-open")
    check(scene.hud.history_panel.visible,"Native history panel opens over the same recorded world/prefix")
    check(not scene.hud.hover_info.get_global_rect().intersects(scene.hud.history_panel.get_global_rect()),"Allocation tooltip stays legible outside open History panel")
    check(scene.timeline.state==original,"Whole-HUD preview sampling changes no canonical game state")
    check(scene.presentation_errors.is_empty() and scene.media_issue.is_empty(),"Native source/renderer reports no preview error")
    await finish(fixture)
func finish(fixture: String) -> void:
    var report = {"ok":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"fixture":fixture,
        "scope":"1600x960 whole production Player/HUD; unchanged original initialization and actual saved real-serverSDK query replies; read-only observer, no commands, no live session and no performance claim"}
    FileAccess.open("res://.runtime/targeting-native-capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report))
    scene.queue_free()
    await process_frame
    await process_frame
    quit(0 if failures.is_empty() else 1)
