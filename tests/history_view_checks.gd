extends SceneTree
# Production scene, recorded native packets, real GPU frame witnesses and Control input.
const Player = preload("res://play.tscn")
var scene: Node
var checks = 0
var failures: Array = []
var report: Dictionary = {}
func check(value: bool, message: String) -> void:
    checks += 1
    if not value: failures.append(message); print("HISTORY_VIEW_FAIL ",message)
func _initialize() -> void: run.call_deferred()
func key(code: int, ctrl: bool = false) -> void:
    var event = InputEventKey.new()
    event.keycode = code; event.physical_keycode = code; event.pressed = true; event.ctrl_pressed = ctrl
    root.push_input(event,true)
    event = event.duplicate(); event.pressed = false; root.push_input(event,true)
func frame() -> void:
    await process_frame
    await RenderingServer.frame_post_draw
func measure_hud() -> Dictionary:
    var result = {}
    for shown in [false,true]:
        if shown: scene.hud.history_panel.show_panel()
        else: scene.hud.history_panel.hide_panel()
        await frame(); await frame()
        var samples: Array=[]
        for _index in range(90):
            await frame()
            var profile: Dictionary=scene.profile
            var sample: Dictionary=profile.frames[posmod(profile.cursor-1,profile.frames.size())]
            samples.append({"frame_ms":sample.frame_ms,"hud_ms":sample.cpu_ms.get("hud_process",0.0),"player_ms":sample.cpu_ms.get("player_process",0.0)})
        result["open" if shown else "closed"]={"samples":samples.size(),
            "frame_ms":scene.FrameProfile.distribution(samples.map(func(row):return row.frame_ms)),
            "hud_ms":scene.FrameProfile.distribution(samples.map(func(row):return row.hud_ms)),
            "player_ms":scene.FrameProfile.distribution(samples.map(func(row):return row.player_ms))}
    return result
func tree_ids(parent: TreeItem) -> Array:
    var result: Array = []
    var item = parent.get_first_child()
    while item != null:
        # Expanded authored text is a visual child, not another native event.
        if not item.get_meta("authored_detail",false): result.append(item.get_metadata(0))
        result.append_array(tree_ids(item))
        item = item.get_next()
    return result

func run() -> void:
    root.size = Vector2i(1280,720)
    DirAccess.make_dir_recursive_absolute("res://.runtime/ui")
    scene = Player.instantiate(); scene.timeline.paused = true; root.add_child(scene)
    var deadline = Time.get_ticks_msec()+120000
    while (not scene.session.recording_ready or not scene.media_initial_ready) and scene.session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        scene._media_ready({})
        await process_frame
    check(scene.session.issue.is_empty() and scene.session.recording_ready,"Native recording initialization prepares without connection error")
    check(scene.media_initial_ready,"Exact initial actor media prepares")
    check(scene.timeline.sequence==0,"Paused intake leaves displayed state at initialization")
    var initial = scene.timeline.event_trace()
    check(initial.counts.get("presented",0)==0 and initial.queued_events>0,"Queued/initialization rows do not claim rendered animations")
    var iterations = 0
    while (scene.timeline.busy() or scene.timeline.sequence<scene.session.latest_sequence) and iterations<2500 and Time.get_ticks_msec()<deadline:
        scene.timeline.paused = false; scene.timeline.advance(50); scene.timeline.paused = true
        await frame()
        iterations += 1
    check(not scene.timeline.busy() and scene.timeline.sequence==scene.session.latest_sequence,"Recorded actions finish through native frame samples")
    check(scene.timeline.state==scene.session.journal.state,"Displayed reducer converges to canonical recording")
    check(scene.presentation_errors.is_empty(),"No body/media rendering failures: "+str(scene.presentation_errors))
    var trace = scene.timeline.event_trace(2000)
    var body_only: Array = trace.events.filter(func(event):return not event.components.is_empty() and event.components.all(func(component):return component.kind=="body" and not component.trace_track_id.is_empty()))
    check(trace.events.any(func(event):return event.components.any(func(component):return component.kind=="body" and component.sample_count>0)),"Actual body animations have native frame witnesses")
    for event in body_only:
        check(event.status in ["presented","not_visible"],"Completed authored body-only occurrence is witnessed or explicitly not visible: "+event.id)
    report.body_only_events = body_only.size()
    check(trace.counts.get("missing",0)>0,"Partial/missing authored effects stay red")
    var green: Dictionary = {}
    var partial: Dictionary = {}
    for event in trace.events:
        if event.status=="presented":
            green = event
            for component in event.components:
                check(component.sample_count>0 and component.status=="presented","Every green component has a native frame witness")
        if event.status=="missing" and event.components.any(func(component):return component.sample_count>0): partial=event
    check(not partial.is_empty(),"A sampled attack with missing feedback remains explicitly partial")
    key(KEY_L); await frame()
    var panel = scene.hud.history_panel
    check(panel.visible and panel.tabs.current_tab==0,"L opens displayed combat log")
    await frame()
    report.first_open={"rect":str(panel.get_global_rect()),"minimum":str(panel.get_combined_minimum_size())}
    check(root.get_visible_rect().encloses(panel.get_global_rect()),"History fits viewport on its first opening before any resize")
    check(panel.size.x<=380,"History opens as a narrow side panel")
    check(panel.find_children("*","RichTextLabel",true,false).is_empty(),"Combat details remain inline rather than reserving a bottom pane")
    check(not panel.tree.hide_folding,"Native history exposes expandable event/subevent hierarchy")
    var log_snapshot: Array = scene.timeline.event_log(200).entries
    var lethal = {}
    for row in log_snapshot:
        if row.entry.entry_type=="death": lethal = row
        if not row.parent_id.is_empty():
            check(panel.items.has(row.parent_id) and panel.items[row.id].get_parent()==panel.items[row.parent_id],"Native Tree attaches a log beneath its recorded parent")
    if not lethal.is_empty():
        panel.follow.button_pressed=false
        panel.selected_id=lethal.id; panel._details()
        var damage_item: TreeItem=panel.items[lethal.id].get_parent()
        var attack_item: TreeItem=damage_item.get_parent()
        panel.tree.scroll_to_item(attack_item)
        await frame()
        root.get_texture().get_image().save_png("res://.runtime/ui/combat-hierarchy.png")
    var glass: StyleBoxFlat = panel.get_theme_stylebox("panel")
    check(glass.bg_color.a>0.4 and glass.bg_color.a<0.9,"History backdrop is partially transparent while text remains opaque")
    var log_text: String = panel.copy_text()
    check(not log_text.is_empty() and not "{bold" in log_text and not "{cyan:" in log_text,"Combat log displays readable recorded text")
    check(panel.plain_text("Damage: {bold red:7} = 1d6({red:5}) +2 {plain:unchanged}")=="Damage: 7 = 1d6(5) +2 {plain:unchanged}","Native style decoding preserves recorded maths and ordinary braces")
    panel.copy_button.emit_signal("pressed")
    var clipboard_text = DisplayServer.clipboard_get()
    report.clipboard = {"expected_length":log_text.length(),"actual_length":clipboard_text.length(),"cr_count":clipboard_text.count("\r"),"lf_count":clipboard_text.count("\n")}
    check(clipboard_text.replace("\r\n","\n")==log_text,"Copy log reaches native clipboard with Windows newline normalization")
    panel.tabs.current_tab=1; await frame()
    panel.selected_id=partial.get("id",green.get("id","")); panel.revision=-1; panel.refresh()
    var copied: Variant = JSON.parse_string(panel.copy_text())
    check(copied!=null and copied.kind=="ndclient_presentation_trace" and copied.trace.selected.id==panel.selected_id,"Trace copy contains selected native event and coverage")
    check(not panel.copy_text().contains('"token"') and not panel.copy_text().contains('"canonical"'),"Trace clipboard excludes credentials and future canonical state")
    panel.copy_button.emit_signal("pressed")
    check(JSON.parse_string(DisplayServer.clipboard_get())!=null,"Copy trace reaches native clipboard")
    var zoom: float = scene.camera.size
    var wheel = InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true
    wheel.position=panel.tree.get_global_rect().get_center(); root.push_input(wheel,true)
    await frame()
    check(scene.camera.size==zoom and not panel.follow.button_pressed,"Scrolling history owns the wheel and disables follow")
    panel.tree.grab_focus(); var quarter: int=scene.quarter
    key(KEY_Q); await frame()
    check(scene.quarter==quarter and not scene.rotation_pending(),"History keyboard focus does not request world rotation")
    key(KEY_ESCAPE); await frame()
    check(panel.visible,"Escape leaves the combat log open")
    if scene.hud.settings_open(): key(KEY_ESCAPE); await frame()
    key(KEY_L); await frame()
    check(not panel.visible and not scene.hud.owns_keyboard_focus(),"Explicit log toggle closes history and releases focus")
    key(KEY_Q); await frame()
    while scene.rotation_pending() and Time.get_ticks_msec()<deadline: await frame()
    check(not scene.rotation_pending() and scene.quarter!=quarter,"World keyboard navigation resumes after closing history and publishes its quarter")
    key(KEY_L); panel.tabs.current_tab=1; await frame()
    # Named GUI ordering boundary: a retained earlier row becomes missing later.
    var retained: Array=scene.timeline.event_trace(panel.LIMIT).events.map(func(row):return row.id)
    var changed: Array=[]
    for id in retained:
        var row: Dictionary=scene.timeline.trace.rows[id]
        if row.get("_admitted",false): changed.append([id,row.status]); row.status="missing"
    if changed.size()>2:
        scene.timeline.trace.rows[changed[0][0]].status="playing"
        panel.missing_only.button_pressed=true; panel.revision=-1; panel.refresh()
        check(not panel.items.has(changed[0][0]) or panel.rows[changed[0][0]].get("context",false),"Nonmatching ancestor is absent or explicitly neutral filter context")
        scene.timeline.trace.rows[changed[0][0]].status="missing"
        panel.revision=-1; panel.refresh()
        check(panel.items.has(changed[0][0]),"Earlier newly missing row is reinserted into the visible window")
        var displayed: Array=tree_ids(panel.tree.get_root())
        var expected: Array=scene.timeline.event_trace(panel.LIMIT,"","missing").events.map(func(row):return row.id)
        check(displayed==expected,"Missing filter retains causal hierarchy when an earlier row changes status")
    for value in changed: scene.timeline.trace.rows[value[0]].status=value[1]
    panel.missing_only.button_pressed=false; panel.revision=-1; panel.refresh()
    # GUI-only admission fixture: hide and readmit an actual recorded leaf.
    # Gameplay state and native event content are unchanged by this view check.
    var shown: Array = scene.timeline.event_trace(panel.LIMIT).events
    var newest: Dictionary = scene.timeline.trace.rows[shown[-1].id]
    newest._admitted=false
    panel.follow.set_pressed_no_signal(false); panel.selected_id=""; panel.revision=-1; panel.refresh()
    var current_ids: Array = tree_ids(panel.tree.get_root())
    var anchor_id: String = current_ids[current_ids.size()/2]
    var anchor_item: TreeItem = panel.items[anchor_id]
    panel.tree.scroll_to_item(anchor_item)
    await frame()
    var manual_scroll: Vector2 = panel.tree.get_scroll()
    newest._admitted=true
    panel.revision=-1; panel.refresh(); await frame()
    check(panel.items[anchor_id]==anchor_item,"New admission preserves existing native Tree items")
    check(panel.tree.get_scroll().is_equal_approx(manual_scroll),"New admission preserves manual scroll while Follow latest is off")
    check(panel.items.has(newest.id),"Newly admitted event still appears without resetting reading position")
    for dimensions in [Vector2i(960,720),Vector2i(1280,720)]:
        root.size=dimensions; await frame(); await frame()
        check(root.get_visible_rect().encloses(panel.get_global_rect()),"History fits viewport "+str(dimensions))
        var right_gap: float = float(dimensions.x)-panel.get_global_rect().end.x
        check(right_gap>=0 and right_gap<=32,"History remains docked near the right edge at "+str(dimensions))
        check(absf(panel.get_global_rect().end.y-(scene.hud.end_button.position.y-12))<1,"Tall history stays above End Turn at "+str(dimensions))
        var click = InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
        click.position=panel.summary.get_global_rect().get_center()
        var prior_sequence: int=scene.timeline.sequence
        root.push_input(click,true); click=click.duplicate(); click.pressed=false; root.push_input(click,true)
        await frame()
        check(scene.timeline.sequence==prior_sequence and not scene.command_busy,"Right history panel consumes clicks without world commands")
        check(panel.tree.size.y>=40,"History retains a usable list within the available height at "+str(dimensions))
        check(panel.find_children("*","RichTextLabel",true,false).is_empty(),"History keeps roll details inline at "+str(dimensions))
    panel.selected_id=partial.get("id",green.get("id","")); panel.revision=-1; panel.refresh()
    DirAccess.make_dir_recursive_absolute("res://.runtime/ui")
    await frame(); root.get_texture().get_image().save_png("res://.runtime/ui/event-stream.png")
    panel.tabs.current_tab=0; await frame()
    var log_rows: Array=scene.timeline.event_log().entries
    if not log_rows.is_empty(): panel.selected_id=log_rows[-1].id; panel._details()
    await frame(); root.get_texture().get_image().save_png("res://.runtime/ui/combat-log.png")
    report.hud_profile = await measure_hud()
    report.merge({"checks":checks,"failures":failures,"counts":trace.counts,"queued_events":trace.queued_events,
        "logs":log_rows.size(),"iterations":iterations,"renderer":RenderingServer.get_current_rendering_method(),"ok":failures.is_empty()})
    var file=FileAccess.open("res://generated/history_view_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report))
    scene.queue_free(); await process_frame; await process_frame
    quit(0 if failures.is_empty() else 1)
