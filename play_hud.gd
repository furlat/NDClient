extends Control
# Native controls own their pointer/focus. Their data is the displayed SDK state.
const Placement = preload("res://placement.gd")
const UI = preload("res://presentation/ui_catalog.gd")
const StoragePanel = preload("res://ui/storage_panel.gd")
const HistoryPanel = preload("res://ui/history_panel.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const ICON = 48
const GAP = 4
var world: Node3D
var cache: Dictionary = {}
var pages = {"Base":0,"Class":0,"Spells":0,"Items":0}
var painted_discovery: Dictionary = {}
var painted_actor = ""
var groups: Dictionary = {}
var shortcuts: Dictionary = {}
var action_buttons: Array = []
var slot_buttons: Dictionary = {}
var inventory_buttons: Dictionary = {}
var selected_item = ""
var selected_slot = ""
var hovered_item = ""
var last_revision = -1
var last_discovery = ""
var last_ready = false
var last_selection = ""
var last_preference = ""
var last_viewport_size = Vector2(-1,-1)
var top = HBoxContainer.new()
var portrait = TextureRect.new()
var actor_label = Label.new()
var resources = Label.new()
var notice = Label.new()
var metrics = Label.new()
var bar = HBoxContainer.new()
var end_button: Button
var inventory_button: Button
var history_button = Button.new()
var grid_button = Button.new()
var normals_button = Button.new()
var loot_panel = StoragePanel.new()
var history_panel = HistoryPanel.new()
var settings_panel = SettingsPanel.new()
var confirm_button = Button.new()
var cancel_button = Button.new()
var panel = PanelContainer.new()
var panel_body = HBoxContainer.new()
var equipment = VBoxContainer.new()
var inventory_grid = GridContainer.new()
var inventory_summary = Label.new()
var search = LineEdit.new()
var item_details = RichTextLabel.new()
var item_commands = HFlowContainer.new()
var popup = PanelContainer.new()
var popup_origin: Control
var popup_family = ""
var popup_bridge = Rect2()
var popup_close_delay = 0.0
var missing_icons: Dictionary = {}
var world_label_buttons: Dictionary = {}
var hover_info = Label.new()

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _install_theme()
    top.position = Vector2(20,18)
    top.add_theme_constant_override("separation",12)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(top)
    portrait.custom_minimum_size = Vector2(54,72)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_child(portrait)
    var stats = VBoxContainer.new()
    stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_child(stats)
    actor_label.add_theme_font_size_override("font_size",19)
    stats.add_child(actor_label)
    stats.add_child(resources)
    stats.add_child(notice)
    notice.add_theme_color_override("font_color",Color("afc1c8"))
    notice.custom_minimum_size.x = 280
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    for label in [actor_label,resources,notice,metrics]:
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.add_theme_color_override("font_shadow_color",Color("080c12"))
        label.add_theme_constant_override("shadow_offset_x",1)
        label.add_theme_constant_override("shadow_offset_y",2)
    metrics.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    add_child(metrics)
    bar.add_theme_constant_override("separation",12)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bar)
    inventory_button = _icon_button(UI.common_key("inventory",cache),"Inventory & equipment · I")
    inventory_button.pressed.connect(toggle_inventory)
    add_child(inventory_button)
    end_button = _icon_button(UI.common_key("end_turn",cache),"End turn · Space")
    end_button.pressed.connect(func():
        if world.command_ready(): world.end_turn())
    add_child(end_button)
    confirm_button.text = "Confirm"
    confirm_button.focus_mode = Control.FOCUS_NONE
    confirm_button.pressed.connect(func():
        if world.command_ready(): world.confirm_selection())
    add_child(confirm_button)
    cancel_button.text = "Cancel"
    cancel_button.focus_mode = Control.FOCUS_NONE
    cancel_button.pressed.connect(world.cancel_selection)
    add_child(cancel_button)
    hover_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hover_info.add_theme_color_override("font_shadow_color",Color.BLACK)
    hover_info.add_theme_constant_override("shadow_offset_x",1)
    hover_info.add_theme_constant_override("shadow_offset_y",2)
    add_child(hover_info)
    _build_inventory_panel()
    loot_panel.hud = self
    add_child(loot_panel)
    history_panel.hud = self
    add_child(history_panel)
    history_button.text = "Log / Events"
    history_button.tooltip_text = "Combat log & event stream · L"
    history_button.focus_mode = Control.FOCUS_NONE
    history_button.pressed.connect(toggle_history)
    add_child(history_button)
    grid_button.text = "Grid · G"
    grid_button.tooltip_text = "Show or hide the isometric grid · G"
    grid_button.toggle_mode = true
    grid_button.focus_mode = Control.FOCUS_NONE
    grid_button.set_pressed_no_signal(world.grid_visible)
    grid_button.toggled.connect(func(enabled: bool): world.grid_visible = enabled)
    add_child(grid_button)
    normals_button.text = "Normals"
    normals_button.tooltip_text = "Preview the receiving surface normals"
    normals_button.toggle_mode = true
    normals_button.focus_mode = Control.FOCUS_NONE
    normals_button.set_pressed_no_signal(world.normals_visible)
    normals_button.toggled.connect(world.set_normals_visible)
    add_child(normals_button)
    popup.visible = false
    popup.mouse_filter = Control.MOUSE_FILTER_STOP
    popup.mouse_force_pass_scroll_events = false
    popup.z_index = 20
    add_child(popup)
    settings_panel.hud = self
    add_child(settings_panel)
    _layout()

func _style(colour: Color, border: Color = Color("5f665e")) -> StyleBoxFlat:
    var value = StyleBoxFlat.new()
    value.bg_color = colour
    value.border_color = border
    value.set_border_width_all(1)
    value.set_corner_radius_all(4)
    value.content_margin_left = 5
    value.content_margin_right = 5
    value.content_margin_top = 4
    value.content_margin_bottom = 4
    return value

func _install_theme() -> void:
    var value = Theme.new()
    value.default_font_size = 14
    var system_font = SystemFont.new()
    system_font.font_names = PackedStringArray(["Segoe UI","DejaVu Sans"])
    value.default_font = system_font
    value.set_stylebox("normal","Button",_style(Color("14212899"),Color("70807880")))
    value.set_stylebox("hover","Button",_style(Color("34423ecb"),Color("d6c394")))
    value.set_stylebox("pressed","Button",_style(Color("35463edb"),Color("f4d795")))
    value.set_stylebox("disabled","Button",_style(Color("10171d88"),Color("53615b66")))
    value.set_stylebox("focus","Button",_style(Color.TRANSPARENT,Color("e8ca85")))
    value.set_stylebox("panel","PanelContainer",_style(Color("111b22e0"),Color("84918a99")))
    value.set_stylebox("normal","LineEdit",_style(Color("0e171dc9"),Color("75867a")))
    value.set_color("font_color","Button",Color("e8e6d9"))
    value.set_color("font_disabled_color","Button",Color("8d9591"))
    value.set_color("font_color","Label",Color("e9e9df"))
    value.set_color("default_color","RichTextLabel",Color("dddcd1"))
    value.set_stylebox("panel","Tree",_style(Color("0c161b88"),Color("596a6666")))
    value.set_stylebox("selected","Tree",_style(Color("3a554ea8"),Color("7b958899")))
    value.set_stylebox("selected_focus","Tree",_style(Color("3a554ed0"),Color("b7c49c")))
    value.set_color("font_color","Tree",Color("dddcd1"))
    value.set_color("icon_disabled_color","Button",Color(0.70,0.70,0.70,0.60))
    theme = value

func _icon_button(key: String, help: String, fallback: String = "") -> Button:
    var button = Button.new()
    button.custom_minimum_size = Vector2(ICON+GAP,ICON+GAP)
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.icon = UI.texture(key,cache)
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.expand_icon = true
    button.add_theme_constant_override("icon_max_width",ICON)
    button.tooltip_text = help
    if button.icon == null:
        button.text = fallback.left(3) if not fallback.is_empty() else "—"
        if not fallback.is_empty() and not missing_icons.has(help):
            missing_icons[help] = true
            push_warning("No authored icon for " + help.get_slice("\n",0))
    return button

func _clear(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _layout() -> void:
    var viewport_size = get_viewport_rect().size
    bar.position = Vector2(maxf(20,(viewport_size.x-bar.get_combined_minimum_size().x)/2),viewport_size.y-146)
    metrics.position = Vector2(viewport_size.x-250,18)
    metrics.size = Vector2(230,40)
    inventory_button.position = Vector2(20,viewport_size.y-74)
    history_button.position = Vector2(84,viewport_size.y-60)
    grid_button.position = history_button.position+Vector2(history_button.get_combined_minimum_size().x+8,0)
    normals_button.position = grid_button.position+Vector2(grid_button.get_combined_minimum_size().x+8,0)
    end_button.position = Vector2(viewport_size.x-74,viewport_size.y-74)
    confirm_button.position = Vector2(viewport_size.x/2-94,viewport_size.y-188)
    cancel_button.position = Vector2(viewport_size.x/2+6,viewport_size.y-188)
    panel.position = Vector2(20,112)
    panel.size = Vector2(minf(790,viewport_size.x-40),minf(480,maxf(260,viewport_size.y-325)))
    loot_panel.position = Vector2(maxf(20,viewport_size.x-410),112)
    loot_panel.size = Vector2(minf(390,viewport_size.x-40),minf(365,maxf(260,viewport_size.y-285)))
    history_panel.size = Vector2(minf(550,viewport_size.x-40),minf(500,maxf(330,viewport_size.y-285)))
    history_panel.position = Vector2(viewport_size.x-history_panel.size.x-20,112)
    last_viewport_size = viewport_size

func _current_actor() -> Dictionary:
    return world.timeline.state.get("actors",{}).get(world.timeline.state.get("current_actor_uuid"),{})

func _inspect_actor() -> Dictionary:
    var current = _current_actor()
    if not current.is_empty() and current.get("controlled_items") != null: return current
    return world.timeline.state.get("actors",{}).get(world.timeline.state.get("observer_uuid"),{})

func _process(delta: float) -> void:
    if world == null: return
    var phase = Time.get_ticks_usec()
    UI.poll_images(cache)
    var ready: bool = world.command_ready()
    var state: Dictionary = world.timeline.state
    var actor = _current_actor()
    var id = str(actor.get("uuid",""))
    var changed = int(world.timeline.revision) != last_revision
    var generation = str(world.available_actions.get("discovery_generation",""))
    var selection = "" if world.selected_action.is_empty() else str(world.selected_action.get("discovery_generation"))+":"+str(world.selected_action.get("discovery_index"))
    var viewport_size = get_viewport_rect().size
    var resized = viewport_size != last_viewport_size
    var bar_changed = viewport_size.x != last_viewport_size.x
    # Discovery is adopted only at an admitted/displayed command boundary.
    if id != painted_actor:
        changed = true
        bar_changed = true
        painted_actor = id
        world.session.retire_record(painted_discovery)
        painted_discovery = {}
        pages = {"Base":0,"Class":0,"Spells":0,"Items":0}
        selected_item = ""
        selected_slot = ""
        _close_popup()
    if ready and world.available_actions.get("entity_uuid") == id and (generation != last_discovery or painted_discovery.is_empty()):
        world.session.retire_record(painted_discovery)
        # Admitted discoveries are immutable and replaced as a whole. Keep the
        # displayed generation without copying every movement/attack target.
        painted_discovery = world.available_actions
        last_discovery = generation
        changed = true
        bar_changed = true
    bar_changed = bar_changed or ready != last_ready or selection != last_selection or str(world.attack_preference) != last_preference
    if changed or bar_changed:
        _refresh_status(actor)
        if panel.visible: _refresh_inventory()
        if not world.loot_object_uuid.is_empty(): loot_panel.refresh()
    if bar_changed: _rebuild_bar()
    if resized or bar_changed: _layout()
    last_revision = int(world.timeline.revision)
    last_ready = ready
    last_selection = selection
    last_preference = str(world.attack_preference)
    history_panel.refresh()
    notice.text = world.notice_text
    metrics.text = "%d FPS" % Engine.get_frames_per_second()
    if world.timeline.paused: metrics.text += " · Paused"
    elif world.timeline.waiting_for_media: metrics.text += " · Loading…"
    metrics.text += " · Walls: %s [Z]" % world.wall_mode
    var cursor = world.pick_cell(get_viewport().get_mouse_position())
    if not cursor.is_empty(): metrics.text += "\n%d, %d · Z %s" % [cursor.position[0],cursor.position[1],cursor.height]
    if grid_button.button_pressed != world.grid_visible:
        grid_button.set_pressed_no_signal(world.grid_visible)
    if normals_button.button_pressed != world.normals_visible:
        normals_button.set_pressed_no_signal(world.normals_visible)
    end_button.disabled = not ready
    confirm_button.visible = not world.selected_action.is_empty() and world.selected_action.get("target_type") != "self"
    cancel_button.visible = confirm_button.visible
    confirm_button.disabled = not ready or not world.selection_preview.get("can_confirm",false)
    if popup.visible:
        if popup_bridge.has_point(get_global_mouse_position()): popup_close_delay = 0.0
        else:
            popup_close_delay += delta
            if popup_close_delay > 0.25: _close_popup()
    _refresh_world_labels()
    queue_redraw()
    world.FrameProfile.end_phase(world.profile,"hud_process",phase)

func _refresh_status(actor: Dictionary) -> void:
    var state: Dictionary = world.timeline.state
    var sheet = UI.sheet(state,str(actor.get("uuid","")))
    actor_label.text = str(actor.get("name",state.get("world",{}).get("battlefield_name","")))
    if not actor.is_empty(): actor_label.text += "   %d / %d HP" % [actor.get("normal_hp",0),actor.get("maximum_hp",0)]
    var values: Array[String] = []
    for resource in sheet.get("resources",[]):
        if resource.key in ["actions","bonus_actions","reactions","movement"]:
            values.append("%s %d/%d" % [resource.label,resource.current,resource.maximum])
    resources.text = "   ·   ".join(values)
    portrait.texture = UI.texture(UI.portrait_key(actor,sheet,state),cache,true)
    portrait.visible = portrait.texture != null

func _rebuild_bar() -> void:
    _close_popup()
    _clear(bar)
    shortcuts.clear()
    action_buttons.clear()
    groups = UI.families(painted_discovery,_current_actor())
    var columns = {}
    var total = 0
    var target = mini(12,maxi(4,int((get_viewport_rect().size.x-200)/(ICON+GAP+5))))
    for group in UI.GROUPS:
        if not groups[group].is_empty(): columns[group] = 1; total += 1
    while total < target:
        var best = ""
        var backlog = 0.0
        for group in columns:
            var score = float(groups[group].size())/float(columns[group])
            if columns[group] < groups[group].size() and score > backlog: best = group; backlog = score
        if best.is_empty(): break
        columns[best] += 1
        total += 1
    var global_column = 0
    var headers: Array[Control] = []
    for group in UI.GROUPS:
        if not columns.has(group): continue
        var block = VBoxContainer.new()
        block.add_theme_constant_override("separation",3)
        block.mouse_filter = Control.MOUSE_FILTER_STOP
        block.mouse_force_pass_scroll_events = false
        block.gui_input.connect(func(event):
            if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
                _page(group,-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
                block.accept_event())
        bar.add_child(block)
        var header = HBoxContainer.new()
        headers.append(header)
        header.mouse_filter = Control.MOUSE_FILTER_IGNORE
        block.add_child(header)
        var label = Label.new()
        label.text = group
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.add_theme_color_override("font_color",Color("c4c8b6"))
        header.add_child(label)
        if group == "Base":
            var mode = Button.new()
            mode.text = "Melee · X" if world.attack_preference == "MELEE_MAIN" else "Ranged · X"
            mode.name = "AttackPreference"
            mode.tooltip_text = "Ordinary creature click uses this weapon set. X switches the preference."
            mode.focus_mode = Control.FOCUS_NONE
            mode.disabled = not world.command_ready()
            mode.add_theme_font_size_override("font_size",12)
            mode.pressed.connect(func():
                if world.command_ready(): world.toggle_attack_preference())
            header.add_child(mode)
        var capacity: int = columns[group]*2
        var page_count = maxi(1,int(ceil(float(groups[group].size())/capacity)))
        pages[group] = clampi(int(pages[group]),0,page_count-1)
        if page_count > 1:
            for sign_value in [-1,1]:
                var step = Button.new()
                step.text = "‹" if sign_value < 0 else "›"
                step.focus_mode = Control.FOCUS_NONE
                step.tooltip_text = "%s page %d / %d" % [group,pages[group]+1,page_count]
                step.pressed.connect(func():_page(group,sign_value))
                header.add_child(step)
        var grid = GridContainer.new()
        grid.columns = columns[group]
        grid.add_theme_constant_override("h_separation",GAP)
        grid.add_theme_constant_override("v_separation",GAP)
        block.add_child(grid)
        var first: int = pages[group]*capacity
        for i in range(first,mini(first+capacity,groups[group].size())):
            var family: Dictionary = groups[group][i]
            var chosen = _preferred(family.rows)
            var button = _icon_button(UI.action_key(chosen,world.timeline.state,cache),UI.action_text(chosen),family.label)
            button.set_meta("native_row",chosen)
            button.set_meta("family",family)
            button.set_meta("group",group)
            button.gui_input.connect(func(event):
                if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
                    _page(group,-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
                    button.accept_event())
            button.disabled = not world.command_ready() or not UI.available(chosen)
            button.pressed.connect(func():_activate_family(family,button))
            button.mouse_entered.connect(func():
                if _choices(family.rows).size() > 1: _open_choices(family,button))
            if not world.selected_action.is_empty() and UI.family_key(world.selected_action) == family.key:
                button.add_theme_stylebox_override("normal",_style(Color("3b493dcb"),Color("ebcb85")))
            grid.add_child(button)
            action_buttons.append(button)
            var local_index = i-first
            var shortcut_index = global_column + local_index%int(columns[group]) + 12*int(local_index/int(columns[group]))
            shortcuts[shortcut_index] = button
            _badge(button,_shortcut_label(shortcut_index),false)
            if chosen.get("weapon_slot") != null: _badge(button,"M" if str(chosen.weapon_slot).begins_with("MELEE") else "R",true)
            elif _choices(family.rows).size()>1: _badge(button,"▴",true)
        global_column += columns[group]
    # Controls beside some titles must not shift their icon rows below others.
    var header_height = 0.0
    for header in headers:
        header_height = maxf(header_height,header.get_combined_minimum_size().y)
    for header in headers:
        header.custom_minimum_size.y = header_height

func _shortcut_label(index: int) -> String:
    var keys = ["1","2","3","4","5","6","7","8","9","0","−","="]
    return ("⇧" if index>=12 else "")+keys[index%12]

func _badge(button: Control, text: String, bottom: bool) -> void:
    var label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size",11)
    label.add_theme_color_override("font_shadow_color",Color.BLACK)
    label.add_theme_constant_override("shadow_offset_x",1)
    label.add_theme_constant_override("shadow_offset_y",1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(label)
    if bottom:
        label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
        label.offset_left = -18
        label.offset_top = -18
        label.offset_right = -2
        label.offset_bottom = -2
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    else: label.position = Vector2(3,0)

func _preferred(rows: Array) -> Dictionary:
    for row in rows:
        if UI.available(row) and row.get("restricted_action_budget") != null: return row
    for row in rows:
        if UI.available(row): return row
    return rows[0]

func _choices(rows: Array) -> Array:
    # Native resource alternatives of one gameplay choice remain one verb.
    var unique = {}
    for row in rows:
        var key = JSON.stringify([row.get("cast_at_level"),row.get("variant_facets",[]),row.get("target_type")])
        if not unique.has(key): unique[key] = []
        unique[key].append(row)
    var result: Array = []
    for values in unique.values():
        var ordinary = values.filter(func(row):return row.get("restricted_action_budget") == null)
        if ordinary.size() > 1: result.append_array(values)
        else: result.append(_preferred(values))
    return result

func _activate_family(family: Dictionary, origin: Control) -> void:
    if not world.command_ready(): return
    var choices = _choices(family.rows)
    if choices.size() > 1: _open_choices(family,origin)
    else: _select_row(choices[0])

func _select_row(row: Dictionary) -> void:
    if not world.command_ready() or not UI.available(row): return
    # Reject controls left from a different actor/discovery even before next redraw.
    if row.get("discovery_generation") != world.available_actions.get("discovery_generation") or row.get("discovery_actor_uuid") != world.timeline.state.get("current_actor_uuid"): return
    _close_popup()
    world.select_action(row)

func _page(group: String, direction: int) -> void:
    pages[group] = maxi(0,int(pages[group])+direction)
    _rebuild_bar()
    _layout()

func _open_choices(family: Dictionary, origin: Control) -> void:
    if popup.visible and popup_family == family.key: return
    _clear(popup)
    popup_family = family.key
    popup_origin = origin
    var stack = VBoxContainer.new()
    popup.add_child(stack)
    var title = Label.new()
    title.text = family.label
    stack.add_child(title)
    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(300,60)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    stack.add_child(scroll)
    var grid = GridContainer.new()
    grid.columns = 5
    scroll.add_child(grid)
    for row in _choices(family.rows):
        var button = _icon_button(UI.action_key(row,world.timeline.state,cache,true),UI.action_text(row),str(row.get("display_name","")))
        button.set_meta("native_row",row)
        button.disabled = not world.command_ready() or not UI.available(row)
        button.pressed.connect(func():_select_row(row))
        grid.add_child(button)
        if row.get("cast_at_level") != null: _badge(button,str(row.cast_at_level),true)
    var rows_count = int(ceil(float(grid.get_child_count())/5))
    scroll.custom_minimum_size.y = minf(230,rows_count*(ICON+GAP+4))
    popup.size = Vector2(310,scroll.custom_minimum_size.y+34)
    popup.position = Vector2(clampf(origin.global_position.x,8,get_viewport_rect().size.x-popup.size.x-8),maxf(8,origin.global_position.y-popup.size.y+2))
    popup.visible = true
    popup_bridge = popup.get_global_rect().merge(origin.get_global_rect())
    popup_close_delay = 0.0

func _close_popup() -> void:
    popup.visible = false
    popup_family = ""
    popup_origin = null

func _build_inventory_panel() -> void:
    panel.visible = false
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.mouse_force_pass_scroll_events = false
    panel.z_index = 10
    add_child(panel)
    var stack = VBoxContainer.new()
    panel.add_child(stack)
    var header = HBoxContainer.new()
    stack.add_child(header)
    var title = Label.new()
    title.text = "Equipment & inventory"
    title.add_theme_font_size_override("font_size",18)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close = Button.new()
    close.text = "×"
    close.tooltip_text = "Close · I / Escape"
    close.focus_mode = Control.FOCUS_NONE
    close.pressed.connect(toggle_inventory)
    header.add_child(close)
    panel_body.add_theme_constant_override("separation",18)
    panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(panel_body)
    equipment.custom_minimum_size.x = 240
    panel_body.add_child(equipment)
    var bag = VBoxContainer.new()
    bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel_body.add_child(bag)
    search.placeholder_text = "Search carried items…"
    search.clear_button_enabled = true
    search.text_changed.connect(func(_value):_refresh_bag())
    bag.add_child(search)
    bag.add_child(inventory_summary)
    var scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 64
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    bag.add_child(scroll)
    inventory_grid.columns = 6
    inventory_grid.add_theme_constant_override("h_separation",GAP)
    inventory_grid.add_theme_constant_override("v_separation",GAP)
    scroll.add_child(inventory_grid)
    item_details.bbcode_enabled = false
    item_details.selection_enabled = true
    item_details.custom_minimum_size = Vector2(0,100)
    item_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
    bag.add_child(item_details)
    bag.add_child(item_commands)

func settings_open() -> bool:
    return settings_panel.visible

func open_settings() -> void:
    _close_popup()
    panel.hide()
    if search.has_focus(): search.release_focus()
    history_panel.hide_panel()
    world.close_storage()
    settings_panel.show_panel()

func close_settings() -> void:
    settings_panel.hide_panel()

func toggle_inventory() -> void:
    if settings_open(): return
    panel.visible = not panel.visible
    if panel.visible:
        history_panel.hide_panel()
        if get_viewport_rect().size.x < 1260: world.close_storage()
    _close_popup()
    if panel.visible: _refresh_inventory()
    else:
        if search.has_focus(): search.release_focus()
    _layout()

func toggle_history() -> void:
    if settings_open(): return
    if history_panel.visible: history_panel.hide_panel()
    else:
        panel.hide()
        if search.has_focus(): search.release_focus()
        _close_popup()
        if get_viewport_rect().size.x < 990: world.close_storage()
        history_panel.show_panel()
    _layout()

func open_loot() -> void:
    if get_viewport_rect().size.x < 1260:
        panel.hide()
        if search.has_focus(): search.release_focus()
    if get_viewport_rect().size.x < 990: history_panel.hide_panel()
    _close_popup()
    loot_panel.refresh()
    _layout()

func _refresh_inventory() -> void:
    var actor = _inspect_actor()
    _clear(equipment)
    slot_buttons.clear()
    var state: Dictionary = world.timeline.state
    var sheet = UI.sheet(state,str(actor.get("uuid","")))
    var title = Label.new()
    title.text = str(actor.get("name","No controlled inventory disclosed"))
    equipment.add_child(title)
    var body = HBoxContainer.new()
    body.add_theme_constant_override("separation",8)
    equipment.add_child(body)
    var left = VBoxContainer.new()
    body.add_child(left)
    var centre = VBoxContainer.new()
    body.add_child(centre)
    var picture = TextureRect.new()
    picture.texture = UI.texture(UI.portrait_key(actor,sheet,state),cache,true)
    picture.custom_minimum_size = Vector2(108,144)
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    centre.add_child(picture)
    var statistics = Label.new()
    statistics.text = "HP %d / %d\nAC %d" % [actor.get("normal_hp",0),actor.get("maximum_hp",0),actor.get("armor_class",0)]
    statistics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    centre.add_child(statistics)
    var right = VBoxContainer.new()
    body.add_child(right)
    var equipped = UI.equipped(actor)
    for i in range(10):
        var slot: String = UI.SLOTS[i]
        var button = _slot_button(slot,equipped.get(slot,{}),state)
        (left if i%2 == 0 else right).add_child(button)
    var weapons = GridContainer.new()
    weapons.columns = 4
    equipment.add_child(weapons)
    for slot in UI.SLOTS.slice(10): weapons.add_child(_slot_button(slot,equipped.get(slot,{}),state))
    _refresh_bag()
    _refresh_details()

func _slot_button(slot: String, item: Dictionary, state: Dictionary) -> Button:
    var help = UI.slot_label(slot)
    if not item.is_empty(): help += "\n"+UI.item_name(item,state,cache)
    var button = _icon_button(UI.item_key(item,state,cache),help)
    button.set_meta("slot",slot)
    button.pressed.connect(func():
        selected_slot = slot
        selected_item = str(item.get("item_uuid",""))
        _refresh_bag()
        _refresh_details())
    button.mouse_entered.connect(func():_highlight_compatible("",slot))
    button.mouse_exited.connect(func():_highlight_compatible(selected_item,selected_slot))
    slot_buttons[slot] = button
    return button

func _refresh_bag() -> void:
    _clear(inventory_grid)
    inventory_buttons.clear()
    var actor = _inspect_actor()
    var items = UI.inventory(actor,search.text)
    var equipped = UI.equipped(actor)
    var equipped_ids = {}
    for layer in equipped.values(): equipped_ids[layer.item_uuid] = true
    inventory_summary.text = "%d carried item%s" % [items.size(),"" if items.size()==1 else "s"] if actor.get("controlled_items") != null else "Inventory has not been disclosed."
    for item in items:
        var help = UI.item_name(item,world.timeline.state,cache)
        if item.get("description") != null: help += "\n"+str(item.description)
        var button = _icon_button(UI.item_key(item,world.timeline.state,cache),help,UI.item_name(item,world.timeline.state,cache))
        button.set_meta("item_uuid",item.item_uuid)
        button.pressed.connect(func():
            selected_item = item.item_uuid
            selected_slot = ""
            _refresh_details())
        button.mouse_entered.connect(func():_highlight_compatible(item.item_uuid,""))
        button.mouse_exited.connect(func():_highlight_compatible(selected_item,selected_slot))
        inventory_grid.add_child(button)
        inventory_buttons[item.item_uuid] = button
        if int(item.get("stack_count",1)) > 1: _badge(button,str(item.stack_count),true)
        if equipped_ids.has(item.item_uuid): _badge(button,"E",false)
        elif item.get("charges") != null: _badge(button,"∞" if item.charges == -1 else str(item.charges),false)
    _highlight_compatible(selected_item,selected_slot)

func _highlight_compatible(item_uuid: String, slot: String) -> void:
    var actor = _inspect_actor()
    var sheet = UI.sheet(world.timeline.state,str(actor.get("uuid","")))
    var compatible = UI.compatible_slots(sheet,item_uuid)
    for key in slot_buttons:
        var button: Button = slot_buttons[key]
        button.remove_theme_stylebox_override("normal")
        if key in compatible or key == slot: button.add_theme_stylebox_override("normal",_style(Color("355748bd"),Color("a8d4ae")))
    for key in inventory_buttons:
        var button: Button = inventory_buttons[key]
        button.remove_theme_stylebox_override("normal")
        if key == item_uuid or (not slot.is_empty() and slot in UI.compatible_slots(sheet,key)):
            button.add_theme_stylebox_override("normal",_style(Color("355748bd"),Color("a8d4ae")))

func _refresh_details() -> void:
    _clear(item_commands)
    var actor = _inspect_actor()
    var item = {}
    for candidate in UI.inventory(actor):
        if candidate.item_uuid == selected_item: item = candidate; break
    if item.is_empty():
        for candidate in UI.equipped(actor).values():
            if candidate.item_uuid == selected_item: item = candidate; break
    if item.is_empty():
        item_details.text = "Select an item to inspect its disclosed details.\nHover an item or equipment slot to see native compatibility."
        _highlight_compatible(selected_item,selected_slot)
        return
    var lines: Array[String] = [UI.item_name(item,world.timeline.state,cache)]
    if item.get("description") != null: lines.append(str(item.description))
    if item.has("rarity"): lines.append(str(item.rarity).capitalize()+" · Quantity "+str(int(item.get("stack_count",1))))
    if item.get("charges") != null: lines.append("Charges %s / %s" % ["∞" if item.charges == -1 else str(item.charges),"∞" if item.get("max_charges") == -1 else str(item.get("max_charges","?"))])
    if item.get("damage_dice") != null: lines.append("Damage %s %s" % [item.damage_dice,item.get("damage_type","")])
    if item.get("armor_ac") != null: lines.append("Armor class %s" % item.armor_ac)
    if item.get("shield_ac_bonus") != null: lines.append("Armor class +%s" % item.shield_ac_bonus)
    if not item.get("weapon_properties",[]).is_empty(): lines.append(", ".join(item.weapon_properties))
    for effect in item.get("item_effects",[]):
        if effect.get("display_name") != null:
            lines.append(str(effect.display_name)+( " (suppressed)" if not effect.get("suppression_provider_uuids",[]).is_empty() else ""))
        if not str(effect.get("description","")).is_empty(): lines.append(str(effect.description))
    item_details.text = "\n".join(lines)
    var item_uuid: String = selected_item
    var sheet = UI.sheet(world.timeline.state,str(actor.get("uuid","")))
    var equipped = UI.equipped(actor)
    for slot in UI.compatible_slots(sheet,selected_item):
        if equipped.get(slot,{}).get("item_uuid") == selected_item: continue
        _item_command("Equip · "+UI.slot_label(slot),func():world.inventory_intent(UI.equip_intent(item_uuid,slot)))
    for slot in equipped:
        if equipped[slot].item_uuid == selected_item: _item_command("Unequip · "+UI.slot_label(slot),func():world.inventory_intent(UI.unequip_intent(slot)))
    # Use/drop are existing discovered choices; no locally invented item action.
    var seen = {}
    for row in UI.rows(painted_discovery):
        if row.get("source_item_uuid") != selected_item or row.get("behavior_id") == "action.attack": continue
        var key = UI.family_key(row)
        if seen.has(key): continue
        seen[key] = true
        var button = _item_command(str(row.display_name),func():_select_row(row))
        button.disabled = button.disabled or not UI.available(row)
        button.tooltip_text = UI.action_text(row)
    _highlight_compatible(selected_item,selected_slot)

func _item_command(label: String, callback: Callable) -> Button:
    var button = Button.new()
    button.text = label
    button.focus_mode = Control.FOCUS_NONE
    button.disabled = not world.command_ready() or _inspect_actor().get("uuid") != world.timeline.state.get("current_actor_uuid")
    var actor_id = str(_inspect_actor().get("uuid",""))
    var generation = painted_discovery.get("discovery_generation")
    button.pressed.connect(func():
        if world.command_ready() and world.timeline.state.get("current_actor_uuid") == actor_id and world.available_actions.get("discovery_generation") == generation: callback.call())
    item_commands.add_child(button)
    return button

func _input(event: InputEvent) -> void:
    if settings_open():
        if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
            settings_panel.escape()
            get_viewport().set_input_as_handled()
        return
    if history_panel.visible and event is InputEventMouseButton and event.pressed:
        if history_panel.tree.get_global_rect().has_point(event.position):
            history_panel.follow.set_pressed_no_signal(false)
        elif not history_panel.get_global_rect().has_point(event.position):
            var old_focus = get_viewport().gui_get_focus_owner()
            if old_focus != null and history_panel.is_ancestor_of(old_focus): old_focus.release_focus()
    if event is InputEventMouseButton and event.pressed and search.has_focus() and not panel.get_global_rect().has_point(event.position):
        search.release_focus()
        get_viewport().set_input_as_handled()
        return
    if not event is InputEventKey or not event.pressed or event.echo: return
    if event.keycode == KEY_ESCAPE:
        if popup.visible: _close_popup()
        elif loot_panel.visible: world.close_storage()
        elif history_panel.visible: history_panel.hide_panel()
        elif panel.visible: toggle_inventory()
        elif not world.selected_action.is_empty(): world.cancel_selection()
        else: open_settings()
        get_viewport().set_input_as_handled()
        return
    var focus = get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit: return
    if event.keycode == KEY_L and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
        toggle_history()
        get_viewport().set_input_as_handled()
        return
    if focus != null and history_panel.visible and history_panel.is_ancestor_of(focus):
        if event.ctrl_pressed and event.keycode==KEY_C and focus==history_panel.tree:
            history_panel._copy(true)
            get_viewport().set_input_as_handled()
        return
    if event.keycode == KEY_I:
        toggle_inventory()
        get_viewport().set_input_as_handled()
        return
    if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
    var keys = [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0,KEY_MINUS,KEY_EQUAL]
    var index = keys.find(event.keycode)
    if index < 0 or panel.visible or loot_panel.visible: return
    if event.shift_pressed: index += 12
    if shortcuts.has(index):
        var button: Button = shortcuts[index]
        if is_instance_valid(button) and not button.disabled: _activate_family(button.get_meta("family"),button)
        get_viewport().set_input_as_handled()

func _refresh_world_labels() -> void:
    var focus = get_viewport().gui_get_focus_owner()
    var alt = not settings_open() and Input.is_key_pressed(KEY_ALT) and not (focus is LineEdit or focus is TextEdit)
    var live = {}
    if alt:
        for row in world.world_labels():
            live[row.id] = true
            if not world_label_buttons.has(row.id):
                var button = Button.new()
                button.focus_mode = Control.FOCUS_NONE
                button.mouse_filter = Control.MOUSE_FILTER_STOP
                button.add_theme_font_size_override("font_size",12)
                button.pressed.connect(func():
                    if world.command_ready(): world.activate_world_label(row.id))
                add_child(button)
                world_label_buttons[row.id] = button
            var button: Button = world_label_buttons[row.id]
            button.text = row.label
            button.position = row.screen - Vector2(button.get_combined_minimum_size().x/2,24)
            button.disabled = not world.command_ready()
    for id in world_label_buttons.keys():
        if not live.has(id):
            var button: Button = world_label_buttons[id]
            remove_child(button); button.queue_free()
            world_label_buttons.erase(id)
    hover_info.visible = not alt and not world.hover_hit.is_empty() and not pointer_over_controls()
    if hover_info.visible:
        hover_info.text = str(world.hover_hit.get("label",""))
        var route = world.hover_preview.get("selected_route")
        if route != null:
            hover_info.text += "\n%s ft" % str(route.get("cost_feet",0))
            if route.get("is_hazardous",false): hover_info.text += " · Hazardous"
            if not route.get("opportunity_attack_exposures",[]).is_empty(): hover_info.text += " · Opportunity attack"
        hover_info.position = get_global_mouse_position()+Vector2(18,20)

func pointer_over_controls(point: Vector2 = Vector2.INF) -> bool:
    if settings_open(): return true
    if point == Vector2.INF: point = get_global_mouse_position()
    if panel.visible and panel.get_global_rect().has_point(point): return true
    if loot_panel.visible and loot_panel.get_global_rect().has_point(point): return true
    if history_panel.visible and history_panel.get_global_rect().has_point(point): return true
    if popup.visible and popup_bridge.has_point(point): return true
    for control in [bar,inventory_button,history_button,grid_button,normals_button,end_button,confirm_button,cancel_button]:
        if control.visible and control.get_global_rect().has_point(point): return true
    for control in world_label_buttons.values():
        if control.get_global_rect().has_point(point): return true
    return false

func owns_keyboard_focus() -> bool:
    if settings_open(): return true
    var focus = get_viewport().gui_get_focus_owner()
    return focus != null and history_panel.visible and history_panel.is_ancestor_of(focus)

func outline(position: Array,height: float,colour: Color,width: float = 1.0) -> void:
    var points = PackedVector2Array()
    for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5),Vector2(-0.5,-0.5)]:
        points.append(world.camera.unproject_position(Vector3(position[0]+offset.x,height*Placement.HEIGHT_UNIT,position[1]+offset.y)))
    draw_polyline(points,colour,width,true)

var grid_cache_key: Array = []
var grid_cache_lines = PackedVector2Array()
var grid_cache_geometry = PackedVector3Array()

func _update_grid_lines() -> void:
    var key = [world.timeline.world_revision,world.camera.global_transform,world.camera.size,get_viewport_rect()]
    if key == grid_cache_key: return
    var camera_changed = grid_cache_key.is_empty() or key.slice(1) != grid_cache_key.slice(1)
    grid_cache_key = key
    var previous_count = grid_cache_geometry.size()
    var count: int = world.timeline.state.tiles.size()
    grid_cache_geometry.resize(count)
    grid_cache_lines.resize(count*8)
    var index = 0
    for tile in world.timeline.state.tiles.values():
        var position = Vector3(tile.position[0],tile.elevation_steps*Placement.HEIGHT_UNIT,tile.position[1])
        # Sight, fixture and object updates also advance world_revision. Retain
        # existing projected edges when this tile's geometry has not changed.
        if camera_changed or index >= previous_count or position != grid_cache_geometry[index]:
            grid_cache_geometry[index] = position
            var corners = PackedVector2Array()
            for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
                corners.append(world.camera.unproject_position(position+Vector3(offset.x,0,offset.y)))
            for i in range(4):
                grid_cache_lines[index*8+i*2] = corners[i]
                grid_cache_lines[index*8+i*2+1] = corners[(i+1)%4]
        index += 1

func _draw() -> void:
    if not is_instance_valid(world.camera) or world.timeline.state.is_empty(): return
    var phase = Time.get_ticks_usec()
    if world.grid_visible:
        _update_grid_lines()
        if not grid_cache_lines.is_empty(): draw_multiline(grid_cache_lines,Color(0.56,0.70,0.85,0.12),1,false)
    var cursor = world.pick_cell(get_viewport().get_mouse_position())
    if not cursor.is_empty(): outline(cursor.position,cursor.height,Color("70d6be"),2)
    for actor in world.visual_actors.values():
        if actor.row.id == world.timeline.state.current_actor_uuid:
            outline(actor.row.position,actor.row.base_height_steps,Color("e9c87e"),2)
    var preview: Dictionary = world.hover_preview if world.selected_action.is_empty() else world.selection_preview
    for target in preview.get("next_targets",[]):
        if target.get("position") != null: _target_outline(target.position,Color(0.45,0.83,0.76,0.45))
    for position in preview.get("next_positions",[]): _target_outline(position,Color(0.45,0.83,0.76,0.65))
    for position in preview.get("affected_positions",[]): _target_outline(position,Color(0.92,0.73,0.36,0.8))
    var route = preview.get("selected_route")
    if route != null:
        var colour = Color("eb8a6d") if route.get("is_hazardous",false) or not route.get("opportunity_attack_exposures",[]).is_empty() else Color("70d6be")
        var points = PackedVector2Array()
        for position in route.path:
            var tile: Dictionary = world.timeline.state.tiles.get("%d,%d" % [position[0],position[1]],{})
            if tile.is_empty():
                if points.size()>1: draw_polyline(points,colour,2,true)
                points.clear()
                continue
            points.append(world.camera.unproject_position(Vector3(position[0],tile.elevation_steps*Placement.HEIGHT_UNIT+0.03,position[1])))
        if points.size()>1: draw_polyline(points,colour,2,true)
    world.FrameProfile.end_phase(world.profile,"hud_draw",phase)

func _target_outline(position: Array,colour: Color) -> void:
    var tile: Dictionary = world.timeline.state.tiles.get("%d,%d" % [position[0],position[1]],{})
    if not tile.is_empty(): outline(position,tile.elevation_steps,colour,2)

func _exit_tree() -> void:
    UI.close_images(cache)
