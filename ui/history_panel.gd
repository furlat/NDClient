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
var follow = CheckButton.new()
var copy_button = Button.new()
var copy_selected_button = Button.new()
var missing_only = CheckButton.new()
var items: Dictionary = {}
var detail_items: Dictionary = {}
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
var stack = VBoxContainer.new()
var layout_viewport = Vector2.ZERO
var layout_bottom = 0.0
var preferred_width = 360.0
var preferred_height = 0.0
var resize_mode = Vector2.ZERO
var resize_origin = Vector2.ZERO
var resize_size = Vector2.ZERO
var hovered_id = ""
var settling = false
const EDGE = 7.0
const LOG_COLOURS = {"attack":Color("e6c487"),"spell_damage":Color("dcab8b"),
    "spell_save":Color("b2aedb"),"saving_throw":Color("b2aedb"),
    "damage_taken":Color("e2a096"),"heal":Color("95ccac"),"death":Color("e6948e"),
    "condition_applied":Color("abc1dc"),"condition_removed":Color("abc1dc"),
    "movement":Color("a6bdbb"),"turn_start":Color("c5c9ba"),"turn_end":Color("c5c9ba")}
func _ready() -> void:
    rich_tag.compile("\\{(?:(?:bold|dim|italic|underline|strike|red|green|yellow|blue|magenta|cyan|white|black|bright_[a-z]+) ?)+:([^{}]*)\\}")
    visible = false
    resized.connect(_queue_layout)
    gui_input.connect(_resize_input)
    var glass = StyleBoxFlat.new()
    glass.bg_color = Color(0.035,0.055,0.07,0.74)
    glass.border_color = Color(0.42,0.47,0.44,0.8)
    glass.set_border_width_all(1)
    glass.set_corner_radius_all(6)
    glass.content_margin_left = 10; glass.content_margin_right = 10
    glass.content_margin_top = 8; glass.content_margin_bottom = 8
    add_theme_stylebox_override("panel",glass)
    z_index = 11
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_force_pass_scroll_events = false
    stack.add_theme_constant_override("separation",5)
    add_child(stack)
    var header = HBoxContainer.new()
    stack.add_child(header)
    title.text = "History"
    title.add_theme_font_size_override("font_size",14)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    close_button.text = "×"
    close_button.tooltip_text = "Close history · L"
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
    tree.columns = 1
    tree.hide_root = true
    tree.hide_folding = false
    tree.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    tree.add_theme_constant_override("indent",18)
    tree.add_theme_constant_override("v_separation",6)
    tree.add_theme_constant_override("h_separation",5)
    tree.add_theme_constant_override("draw_guides",1)
    tree.add_theme_color_override("guide_color",Color("71877b44"))
    tree.add_theme_color_override("drop_position_color",Color("d7c495"))
    tree.add_theme_stylebox_override("selected",_row_style(Color("405a4c88")))
    tree.add_theme_stylebox_override("selected_focus",_row_style(Color("405a4cbb")))
    tree.item_collapsed.connect(func(_item):_queue_layout())
    tree.item_activated.connect(func():
        var item = tree.get_selected()
        if item != null and item.get_child_count()>0: item.collapsed = not item.collapsed)
    tree.select_mode = Tree.SELECT_ROW
    tree.allow_reselect = true
    tree.allow_search = false
    tree.scroll_horizontal_enabled = false
    tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tree.custom_minimum_size.y = 46
    tree.set_column_expand(0,true)
    tree.set_column_clip_content(0,false)
    tree.item_selected.connect(_selected)
    tree.gui_input.connect(_tree_input)
    tree.mouse_exited.connect(func():_hover_row(""))
    stack.add_child(tree)
    var options = HBoxContainer.new()
    stack.add_child(options)
    follow.text = "Follow"
    follow.tooltip_text = "Follow latest entries"
    follow.button_pressed = true
    follow.focus_mode = Control.FOCUS_NONE
    follow.toggled.connect(func(_value):revision = -1; refresh())
    options.add_child(follow)
    missing_only.text = "Missing only"
    missing_only.focus_mode = Control.FOCUS_NONE
    missing_only.toggled.connect(func(_value):revision = -1; refresh())
    options.add_child(missing_only)
    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    options.add_child(spacer)
    var buttons = HBoxContainer.new()
    options.add_child(buttons)
    copy_button.text = "Copy"
    copy_selected_button.text = "Copy selected"
    for button in [copy_button,copy_selected_button]:
        button.focus_mode = Control.FOCUS_NONE
        buttons.add_child(button)
    copy_button.pressed.connect(func():_copy(false))
    copy_selected_button.pressed.connect(func():_copy(true))
    copy_selected_button.visible = false
    tree.create_item()

func show_panel() -> void:
    visible = true
    revision = -1
    refresh()
    _queue_layout()

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
        tree.clear(); tree.create_item(); items.clear(); detail_items.clear(); rows.clear(); topology.clear()
    snapshot = world.timeline.event_trace(LIMIT,selected_id,"missing" if missing_only.button_pressed else "") if events else world.timeline.event_log(LIMIT)
    var source: Array = snapshot.get("events",[]) if events else _log_rows(snapshot.get("entries",[]))
    missing_only.visible = events
    copy_button.text = "Copy"
    title.text = "History"
    if changed_tab:
        tree.columns = 2 if events else 1
        tree.set_column_expand(0,not events)
        tree.set_column_custom_minimum_width(0,82 if events else 0)
        tree.set_column_clip_content(0,false)
        if events:
            tree.set_column_expand(1,true)
            tree.set_column_clip_content(1,false)
    copy_button.tooltip_text = "Copy the latest %d displayed entries, diagnostics and selected event" % LIMIT if events else "Copy the same recorded combat text shown here"
    if events:
        var counts: Dictionary = snapshot.get("counts",{})
        summary.text = "%d rendered · %d missing · %d queued" % [counts.get("presented",0),counts.get("missing",0),snapshot.get("queued_events",0)]
    else: summary.text = ""
    var evicted: int = snapshot.get("evicted_events",0) if events else snapshot.get("evicted_entries",0)
    if evicted>0: summary.text += ("\n" if not summary.text.is_empty() else "")+"%d older entries" % evicted
    if not issue.is_empty(): summary.text += ("\n" if not summary.text.is_empty() else "")+issue
    summary.visible = not summary.text.is_empty()
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
                item.collapsed = true
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
        for id in removed:
            items[id].free(); items.erase(id); detail_items.erase(id)
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
            item.set_custom_color(0,LOG_COLOURS.get(str(row.entry.get("entry_type","")),Color("dedfd2")))
        var column = 1 if events else 0
        item.set_text(column,label)
        item.set_autowrap_mode(column,TextServer.AUTOWRAP_WORD_SMART)
        item.set_autowrap_trim_flags(column,0)
        item.set_tooltip_text(column,label)
        item.set_custom_minimum_height(25)
        if not events:
            var own = row.entry.duplicate()
            own.sub_entries = []
            var authored = _combat_text(own)
            if authored != label: _inline_details(row.id,authored)
        last = item
    if not selected_id.is_empty() and not rows.has(selected_id) and not (events and not snapshot.get("selected",{}).is_empty()): selected_id = ""
    if items.has(selected_id): items[selected_id].select(0)
    updating = false
    _details()
    copy_button.disabled = source.is_empty()
    _queue_layout()

func _selected() -> void:
    if updating: return
    var previous = selected_id
    var item = tree.get_selected()
    selected_id = str(item.get_metadata(0)) if item != null else ""
    follow.set_pressed_no_signal(false)
    if selected_id!=previous and items.has(selected_id) and item==items[selected_id]:
        _expand_selection.call_deferred(selected_id,false)
    _details()

func _expand_selection(id: String, collapsed: bool) -> void:
    if id!=selected_id or not items.has(id): return
    updating = true
    items[id].collapsed = collapsed
    updating = false
    if not collapsed and detail_items.has(id): _reveal_expansion(id)
    _queue_layout()

func _reveal_expansion(id: String) -> void:
    # Wrapping is measured by the native Tree layout. Reveal after that layout
    # so expanding a row at the lower edge does not leave its math below view.
    await get_tree().process_frame
    if id==selected_id and items.has(id) and detail_items.has(id) and not items[id].collapsed:
        tree.scroll_to_item(detail_items[id])

func _inline_details(id: String, text: String) -> void:
    if not items.has(id): return
    var parent: TreeItem = items[id]
    var item: TreeItem = detail_items.get(id)
    if item == null:
        item = tree.create_item(parent,0)
        item.set_metadata(0,id)
        item.set_meta("authored_detail",true)
        detail_items[id] = item
    if parent.get_first_child()!=item: item.move_before(parent.get_first_child())
    var column = 1 if tabs.current_tab==1 else 0
    item.set_text(column,text)
    item.set_autowrap_mode(column,TextServer.AUTOWRAP_WORD_SMART)
    item.set_autowrap_trim_flags(column,0)
    item.set_custom_color(column,Color("c9d5ce"))
    item.set_custom_minimum_height(25)
    item.set_tooltip_text(column,text)

func _details() -> void:
    copy_selected_button.visible = not selected_id.is_empty()
    copy_selected_button.disabled = selected_id.is_empty()
    if selected_id.is_empty(): _queue_layout(); return
    var row: Dictionary = rows.get(selected_id,{})
    if row.is_empty() and tabs.current_tab==1: row = hud.world.timeline.event_trace(1,selected_id).selected
    if row.is_empty():
        selected_id = ""
        copy_selected_button.hide()
        _queue_layout()
        return
    if tabs.current_tab==0:
        _queue_layout()
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
    _inline_details(selected_id,"\n".join(lines))
    _expand_selection.call_deferred(selected_id,false)
    _queue_layout()

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

func _row_style(colour: Color) -> StyleBoxFlat:
    var value = StyleBoxFlat.new()
    value.bg_color = colour
    value.set_corner_radius_all(3)
    value.content_margin_left = 3
    value.content_margin_right = 3
    return value

func _tree_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var item = tree.get_item_at_position(event.position)
        _hover_row(str(item.get_metadata(0)) if item != null else "")
    if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
        follow.set_pressed_no_signal(false)

func _hover_row(id: String) -> void:
    if id == hovered_id: return
    if items.has(hovered_id):
        for column in range(tree.columns): items[hovered_id].clear_custom_bg_color(column)
    hovered_id = id
    if items.has(id):
        for column in range(tree.columns): items[id].set_custom_bg_color(column,Color("57726136"))

func layout_in(viewport_size: Vector2, bottom_y: float) -> void:
    layout_viewport = viewport_size
    layout_bottom = bottom_y
    if not is_node_ready(): return
    var margin = minf(18,viewport_size.x*0.04)
    var available_width = maxf(1,viewport_size.x-margin*2)
    var maximum_height = maxf(1,minf(bottom_y,viewport_size.y-margin)-margin)
    var width = clampf(preferred_width,minf(270,available_width),available_width)
    # The log occupies the available right side from the upper edge down to
    # End Turn. Content length never changes its geometry; resize is explicit.
    var height = maximum_height if preferred_height<=0 else clampf(preferred_height,minf(160,maximum_height),maximum_height)
    tree.custom_minimum_size.y = minf(46,maxf(0,height-115))
    size = Vector2(width,height)
    position = Vector2(viewport_size.x-margin-size.x,minf(bottom_y,viewport_size.y-margin)-size.y)
    queue_redraw()

func _queue_layout() -> void:
    if settling: return
    settling = true
    _settle_layout.call_deferred()

func _settle_layout() -> void:
    settling = false
    if not layout_viewport.is_zero_approx(): layout_in(layout_viewport,layout_bottom)
    if follow.button_pressed and tree.get_root()!=null:
        var root_item = tree.get_root()
        var last = root_item.get_child(root_item.get_child_count()-1) if root_item.get_child_count()>0 else null
        while last != null and not last.collapsed and last.get_child_count()>0: last = last.get_child(last.get_child_count()-1)
        if last != null: tree.scroll_to_item(last)

func _resize_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if event.pressed:
            resize_mode = Vector2(-1 if event.position.x<=EDGE else 0,-1 if event.position.y<=EDGE else 0)
            if resize_mode.is_zero_approx(): return
            resize_origin = get_global_transform()*event.position
            resize_size = size
        else: resize_mode = Vector2.ZERO
        accept_event()

func _input(event: InputEvent) -> void:
    if not visible: return
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
        resize_mode = Vector2.ZERO
    if event is InputEventMouseMotion and not resize_mode.is_zero_approx():
        var change = event.position-resize_origin
        if resize_mode.x!=0: preferred_width = resize_size.x-change.x
        if resize_mode.y!=0: preferred_height = resize_size.y-change.y
        layout_in(layout_viewport,layout_bottom)
        get_viewport().set_input_as_handled()
    if event is InputEventMouseMotion:
        var local = get_global_transform().affine_inverse()*event.position
        var inside = Rect2(Vector2.ZERO,size).has_point(local)
        var horizontal = inside and local.x<=EDGE
        var vertical = inside and local.y<=EDGE
        mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if horizontal and vertical else Control.CURSOR_HSIZE if horizontal else Control.CURSOR_VSIZE if vertical else Control.CURSOR_ARROW

func _draw() -> void:
    # A discreet grip marks the anchored panel's movable upper-left corner.
    for offset in [0,4,8]:
        draw_line(Vector2(3,11+offset),Vector2(11+offset,3),Color("a7b8a78c"),1,true)
