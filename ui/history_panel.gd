extends PanelContainer
# Read-only displayed combat text and witnessed presentation coverage.
const LIMIT = 200
const COLOURS = {"presented":Color("80d19c"),"missing":Color("f08f89"),
    "playing":Color("e7cc85"),"state_only":Color("a8b5bd"),"not_visible":Color("a8b5bd")}
const LABELS = {"presented":"Rendered","missing":"Missing","playing":"Playing",
    "state_only":"State only","not_visible":"Not visible"}
var hud: Control
var title = Label.new()
var close_button = Button.new()
var tabs = TabBar.new()
var summary = Label.new()
var tree = Tree.new()
var details = RichTextLabel.new()
var follow = CheckButton.new()
var copy_button = Button.new()
var copy_selected_button = Button.new()
var missing_only = CheckButton.new()
var items: Dictionary = {}
var rows: Dictionary = {}
var selected_id = ""
var revision = -1
var painted_tab = -1
var queued = -1
var last_issue = ""
var updating = false
var snapshot: Dictionary = {}
var rich_tag = RegEx.new()
var topology: Array = []

func _ready() -> void:
    rich_tag.compile("\\{(?:(?:bold|dim|italic|underline|strike|red|green|yellow|blue|magenta|cyan|white|black|bright_[a-z]+) ?)+:([^{}]*)\\}")
    visible = false
    # Autowrapped text resolves its minimum after the first container layout.
    # Refit when that minimum settles instead of retaining the oversized first
    # opening until the next viewport resize.
    minimum_size_changed.connect(func():
        if visible: hud._layout.call_deferred())
    var glass = StyleBoxFlat.new()
    glass.bg_color = Color(0.035,0.055,0.07,0.78)
    glass.border_color = Color(0.42,0.47,0.44,0.8)
    glass.set_border_width_all(1)
    glass.set_corner_radius_all(6)
    glass.content_margin_left = 10; glass.content_margin_right = 10
    glass.content_margin_top = 8; glass.content_margin_bottom = 8
    add_theme_stylebox_override("panel",glass)
    z_index = 11
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_force_pass_scroll_events = false
    var stack = VBoxContainer.new()
    stack.add_theme_constant_override("separation",6)
    add_child(stack)
    var header = HBoxContainer.new()
    stack.add_child(header)
    title.text = "History"
    title.add_theme_font_size_override("font_size",18)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    close_button.text = "×"
    close_button.tooltip_text = "Close history · L / Escape"
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.pressed.connect(hide_panel)
    header.add_child(close_button)
    tabs.add_tab("Combat log")
    tabs.add_tab("Event stream")
    tabs.focus_mode = Control.FOCUS_NONE
    tabs.tab_changed.connect(func(_tab):
        selected_id = ""; revision = -1; refresh())
    stack.add_child(tabs)
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary.add_theme_font_size_override("font_size",12)
    stack.add_child(summary)
    tree.columns = 2
    tree.hide_root = true
    tree.hide_folding = false
    tree.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    tree.add_theme_constant_override("indent",16)
    tree.select_mode = Tree.SELECT_ROW
    tree.allow_reselect = true
    tree.allow_search = false
    tree.scroll_horizontal_enabled = false
    tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tree.custom_minimum_size.y = 90
    tree.set_column_expand(0,false)
    tree.set_column_custom_minimum_width(0,144)
    tree.set_column_clip_content(1,true)
    tree.item_selected.connect(_selected)
    tree.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            follow.set_pressed_no_signal(false))
    stack.add_child(tree)
    details.bbcode_enabled = false
    details.selection_enabled = true
    details.custom_minimum_size.y = 105
    details.focus_mode = Control.FOCUS_ALL
    stack.add_child(details)
    var options = HBoxContainer.new()
    stack.add_child(options)
    follow.text = "Follow latest"
    follow.button_pressed = true
    follow.focus_mode = Control.FOCUS_NONE
    follow.toggled.connect(func(_value):revision = -1; refresh())
    options.add_child(follow)
    missing_only.text = "Missing only"
    missing_only.focus_mode = Control.FOCUS_NONE
    missing_only.toggled.connect(func(_value):revision = -1; refresh())
    options.add_child(missing_only)
    var buttons = HBoxContainer.new()
    stack.add_child(buttons)
    copy_button.text = "Copy log"
    copy_selected_button.text = "Copy selected"
    for button in [copy_button,copy_selected_button]:
        button.focus_mode = Control.FOCUS_NONE
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        buttons.add_child(button)
    copy_button.pressed.connect(func():_copy(false))
    copy_selected_button.pressed.connect(func():_copy(true))
    tree.create_item()

func show_panel() -> void:
    visible = true
    revision = -1
    refresh()

func hide_panel() -> void:
    var focus = get_viewport().gui_get_focus_owner()
    if focus != null and is_ancestor_of(focus): focus.release_focus()
    visible = false

func refresh() -> void:
    if not visible or hud.world.timeline.state.is_empty(): return
    var world = hud.world
    var new_queued: int = world.timeline.queue.size()
    var issue: String = world.media_issue if not world.media_issue.is_empty() else str(world.session.issue.get("message",""))
    if revision == world.timeline.trace_revision and painted_tab == tabs.current_tab and queued == new_queued and last_issue == issue: return
    revision = world.timeline.trace_revision
    queued = new_queued
    last_issue = issue
    var events = tabs.current_tab == 1
    var changed_tab = painted_tab != tabs.current_tab
    painted_tab = tabs.current_tab
    if changed_tab:
        tree.clear(); tree.create_item(); items.clear(); rows.clear(); topology.clear()
    snapshot = world.timeline.event_trace(LIMIT,selected_id,"missing" if missing_only.button_pressed else "") if events else world.timeline.event_log(LIMIT)
    var source: Array = snapshot.get("events",[]) if events else _log_rows(snapshot.get("entries",[]))
    missing_only.visible = events
    copy_button.text = "Copy trace" if events else "Copy log"
    copy_button.tooltip_text = "Copy the latest %d displayed entries, diagnostics and selected event" % LIMIT if events else "Copy the same recorded combat text shown here"
    if events:
        var counts: Dictionary = snapshot.get("counts",{})
        summary.text = "%d rendered · %d missing · %d queued\nGreen: renderer witness · Red: missing or partial visual" % [counts.get("presented",0),counts.get("missing",0),snapshot.get("queued_events",0)]
    else: summary.text = "Recorded combat text · Actions with their subevents"
    var evicted: int = snapshot.get("evicted_events",0) if events else snapshot.get("evicted_entries",0)
    if evicted>0: summary.text += "\n%d older entries left this view; full source remains in the recording." % evicted
    if not issue.is_empty(): summary.text += "\n"+issue
    updating = true
    var next_topology: Array = source.map(func(row):return [row.id,row.get("parent_id","")])
    if next_topology != topology:
        var retained = {}
        var previous_sibling = {}
        for row in source:
            retained[row.id] = true
            var parent: TreeItem = items.get(row.get("parent_id",""),tree.get_root())
            var item: TreeItem = items.get(row.id)
            if item == null:
                item = tree.create_item(parent)
                item.set_metadata(0,row.id)
                items[row.id] = item
            elif item.get_parent() != parent:
                item.get_parent().remove_child(item)
                parent.add_child(item)
            var prior: TreeItem = previous_sibling.get(parent)
            if prior != null and item.get_prev() != prior: item.move_after(prior)
            elif prior == null and parent.get_first_child() != item: item.move_before(parent.get_first_child())
            previous_sibling[parent] = item
        var removed: Array = []
        for id in items:
            if not retained.has(id): removed.append(id)
        # Detach every stale item first so deleting an old parent cannot free
        # a separately retained/reparented child or invalidate the removal list.
        for id in removed:
            var item: TreeItem = items[id]
            if item.get_parent() != null: item.get_parent().remove_child(item)
        for id in removed: items[id].free(); items.erase(id)
        topology = next_topology
    rows.clear()
    var last: TreeItem
    for row in source:
        rows[row.id] = row
        var item: TreeItem = items[row.id]
        var label: String
        if events:
            label = "#%s · %s" % [row.sequence,str(row.get("name",row.kind))]
            if row.kind == "undisclosed": label += " · "+str(row.get("phase",""))
            var context: bool = row.get("context",false)
            item.set_text(0,"Context" if context else LABELS.get(row.status,row.status))
            for column in [0,1]: item.set_custom_color(column,COLOURS.state_only if context else COLOURS.get(row.status,Color.WHITE))
            item.set_tooltip_text(0,"Admitted parent context for the filtered event." if context else "Green confirms a submitted native frame sample, not visibility through occluders or every authored frame.\n"+"\n".join(row.get("reasons",[])))
        else:
            label = plain_text(str(row.entry.get("compact",row.entry.get("verbose",""))))
            item.set_text(0,str(row.entry.get("entry_type","event")).replace("_"," ").capitalize())
            for column in [0,1]: item.clear_custom_color(column)
        item.set_text(1,label.replace("\n"," · "))
        item.set_tooltip_text(1,label)
        last = item
    if not selected_id.is_empty() and not rows.has(selected_id) and not (events and not snapshot.get("selected",{}).is_empty()): selected_id = ""
    if follow.button_pressed and last != null:
        tree.scroll_to_item(last)
    if items.has(selected_id): items[selected_id].select(0)
    updating = false
    _details()
    copy_button.disabled = source.is_empty()

func _selected() -> void:
    if updating: return
    var item = tree.get_selected()
    selected_id = str(item.get_metadata(0)) if item != null else ""
    follow.set_pressed_no_signal(false)
    _details()

func _details() -> void:
    copy_selected_button.disabled = selected_id.is_empty()
    if selected_id.is_empty():
        details.text = "Select an event to inspect the rendered components and missing animation reasons." if tabs.current_tab==1 else "Select a combat entry for its recorded roll, modifiers and outcome."
        return
    var row: Dictionary = rows.get(selected_id,{})
    if row.is_empty() and tabs.current_tab==1: row = hud.world.timeline.event_trace(1,selected_id).selected
    if row.is_empty(): details.text = "This entry is no longer retained in the view."; return
    if tabs.current_tab==0:
        details.text = _combat_text(row.entry)
        return
    var selected: Dictionary = hud.world.timeline.event_trace(1,selected_id).get("selected",row)
    if selected.is_empty(): selected = row
    var lines: Array[String] = [str(selected.get("name",selected.kind)),"#%s · %s · %s" % [selected.sequence,selected.kind,LABELS.get(selected.status,selected.status)]]
    for component in selected.get("components",[]):
        var component_name = str(component.get("kind","visual"))
        if not str(component.get("clip","")).is_empty(): component_name += " · "+str(component.clip)
        lines.append(component_name+": "+str(component.get("status","pending"))+(" · "+str(component.reason) if component.get("reason") != null and not str(component.reason).is_empty() else ""))
    for reason in selected.get("reasons",[]): lines.append(str(reason))
    if selected.get("committed_log") != null: lines.append(_combat_text(selected.committed_log))
    details.text = "\n".join(lines)

func plain_text(text: String) -> String:
    # Decode native style spans without altering names, rolls or formula text.
    while rich_tag.search(text) != null: text = rich_tag.sub(text,"$1",true)
    return text

func _combat_text(entry: Dictionary) -> String:
    var text: String = str(entry.get("detailed",entry.get("verbose",entry.get("compact",""))))
    # Preserve recorded child text only when retained by the displayed log feed.
    for child in entry.get("sub_entries",[]): text += "\n"+_combat_text(child)
    return plain_text(text)

func _log_rows(entries: Array) -> Array:
    var result: Array = []
    for row in entries:
        result.append(row)
        _nested_logs(row,result)
    return result

func _nested_logs(parent: Dictionary, result: Array) -> void:
    var children: Array = parent.entry.get("sub_entries",[])
    for index in range(children.size()):
        var row = {"id":parent.id+"/sub:"+str(index),"parent_id":parent.id,"depth":int(parent.get("depth",0))+1,
            "entry":children[index],"sequence":parent.sequence,"source_index":parent.source_index}
        result.append(row)
        _nested_logs(row,result)

func copy_text(selected_only: bool = false) -> String:
    if tabs.current_tab==0:
        if selected_only: return _combat_text(rows[selected_id].entry) if rows.has(selected_id) else ""
        var text: Array[String] = []
        for row in _log_rows(hud.world.timeline.event_log(LIMIT).entries):
            var own: Dictionary = row.entry.duplicate()
            own.sub_entries = []
            text.append("  ".repeat(int(row.get("depth",0)))+_combat_text(own))
        return "\n\n".join(text)
    var world = hud.world
    var trace: Dictionary = world.timeline.event_trace(LIMIT,selected_id,"missing" if missing_only.button_pressed else "")
    if selected_only:
        if trace.get("selected",{}).is_empty(): return ""
        trace = {"selected":trace.selected}
    return JSON.stringify({"kind":"ndclient_presentation_trace","displayed_sequence":world.timeline.sequence,
        "consumed_sequence":world.session.latest_sequence,"display_ms":world.timeline.display_ms,
        "paused":world.timeline.paused,"waiting_for_media":world.timeline.waiting_for_media,
        "media_issue":world.media_issue,"presentation_errors":world.presentation_errors,
        "renderer":RenderingServer.get_current_rendering_method(),"trace":trace},"  ")

func _copy(selected_only: bool) -> void:
    var text = copy_text(selected_only)
    if text.is_empty(): return
    DisplayServer.clipboard_set(text)
    hud.world.notice_text = "Selected entry copied." if selected_only else ("Event trace copied." if tabs.current_tab==1 else "Combat log copied.")
