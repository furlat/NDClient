extends Control
# Native controls own their pointer/focus. Their data is the displayed SDK state.
const UI = preload("res://presentation/ui_catalog.gd")
const Choices = preload("res://sdk/choices.gd")
const Interaction = preload("res://presentation/interaction.gd")
const StoragePanel = preload("res://ui/storage_panel.gd")
const HistoryPanel = preload("res://ui/history_panel.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const ActorHUD = preload("res://ui/actor_hud.gd")
const Placement = preload("res://placement.gd")
const HoverOutline = preload("res://presentation/condition_outline.gd")
const ICON = 48
const GAP = 4
const BAR_BUILD_UNITS = 2
const BAR_BUILD_USEC = 1000
const BAR_RETIRE_UNITS = 8
var world: Node3D
var cache: Dictionary = {}
var pages = {"Base":0,"Class":0,"Spells":0,"Items":0}
var painted_discovery: Dictionary = {}
var painted_actor = ""
var groups: Dictionary = {}
var shortcuts: Dictionary = {}
var action_buttons: Array = []
var bar_topology: Array = []
var bar_build: Dictionary = {}
var retired_bars: Array[Control] = []
var bar_build_units = 0
var preference_button: Button
var popup_rows: Array[Button] = []
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
var notice = Label.new()
var notice_row = HBoxContainer.new()
var copy_notice = Button.new()
var copied_notice = ""
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
var actor_hud = ActorHUD.new()
var inspected_actor_id = ""
var hover_outline = HoverOutline.new()
var hover_feedback_dismissed = false
var hover_object_materials: Dictionary = {}
var hover_object_key: Array = []
var hover_object_discovery: Dictionary = {}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _install_theme()
    add_child(actor_hud)
    actor_hud.inspected.connect(_inspect_portrait)
    actor_hud.focused.connect(_focus_portrait)
    top.position = Vector2(20,18)
    top.add_theme_constant_override("separation",12)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(top)
    top.add_child(notice_row)
    notice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    notice_row.add_child(notice)
    notice_row.add_child(copy_notice)
    copy_notice.text = "Copy"
    copy_notice.tooltip_text = "Copy this message and playback diagnostics"
    copy_notice.focus_mode = Control.FOCUS_NONE
    copy_notice.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    copy_notice.pressed.connect(_copy_notice)
    notice_row.hide()
    notice.add_theme_color_override("font_color",Color("afc1c8"))
    notice.custom_minimum_size.x = 280
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    for label in [notice,metrics]:
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.add_theme_color_override("font_shadow_color",Color("080c12"))
        label.add_theme_constant_override("shadow_offset_x",1)
        label.add_theme_constant_override("shadow_offset_y",2)
    metrics.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
    history_button.text = "Log"
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
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.expand_icon = true
    button.add_theme_constant_override("icon_max_width",ICON)
    _set_button_icon(button,key,help,fallback)
    return button

func _set_button_icon(button: Button, key: String, help: String, fallback: String) -> void:
    var icon = UI.texture(key,cache)
    if button.icon != icon: button.icon = icon
    button.tooltip_text = help
    button.text = ""
    if button.icon == null:
        button.text = fallback.left(3) if not fallback.is_empty() else "—"
        if not fallback.is_empty() and not missing_icons.has(help):
            missing_icons[help] = true
            push_warning("No authored icon for " + help.get_slice("\n",0))

func _clear(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _layout() -> void:
    var phase = Time.get_ticks_usec()
    var viewport_size = get_viewport_rect().size
    bar.position = Vector2(maxf(20,(viewport_size.x-bar.get_combined_minimum_size().x)/2),viewport_size.y-146)
    metrics.position = Vector2(20,18)
    metrics.size = Vector2(160,40)
    inventory_button.position = Vector2(20,viewport_size.y-74)
    history_button.position = Vector2(viewport_size.x-90-history_button.get_combined_minimum_size().x,viewport_size.y-60)
    grid_button.position = Vector2(84,viewport_size.y-60)
    normals_button.position = grid_button.position+Vector2(grid_button.get_combined_minimum_size().x+8,0)
    end_button.position = Vector2(viewport_size.x-74,viewport_size.y-74)
    confirm_button.position = Vector2(viewport_size.x/2-94,viewport_size.y-220)
    cancel_button.position = Vector2(viewport_size.x/2+6,viewport_size.y-220)
    panel.position = Vector2(20,112)
    panel.size = Vector2(minf(790,viewport_size.x-40),minf(480,maxf(260,viewport_size.y-325)))
    loot_panel.position = Vector2(maxf(20,viewport_size.x-410),112)
    loot_panel.size = Vector2(minf(390,viewport_size.x-40),minf(365,maxf(260,viewport_size.y-285)))
    history_panel.layout_in(viewport_size,end_button.position.y-12)
    last_viewport_size = viewport_size
    world.FrameProfile.end_phase(world.profile,"hud_layout",phase)

func _current_actor() -> Dictionary:
    return world.timeline.state.get("actors",{}).get(world.timeline.state.get("current_actor_uuid"),{})

func _inspect_actor() -> Dictionary:
    var inspected: Dictionary = world.timeline.state.get("actors",{}).get(inspected_actor_id,{})
    if not inspected.is_empty(): return inspected
    var current = _current_actor()
    if not current.is_empty() and current.get("controlled_items") != null: return current
    return world.timeline.state.get("actors",{}).get(world.timeline.state.get("observer_uuid"),{})

func _action_actor() -> Dictionary:
    # Enemy turns disable the retained player's controls; they do not rebuild
    # the player's bar or load an enemy's portrait into the resource header.
    var id = world.available_actions.get("entity_uuid",world.timeline.state.get("observer_uuid",""))
    return world.timeline.state.get("actors",{}).get(id,{})

func _inspect_portrait(id: String) -> void:
    inspected_actor_id = id
    actor_hud.sync(world.timeline.state,_action_actor(),inspected_actor_id,cache)
    if panel.visible: _refresh_inventory()

func _focus_portrait(id: String) -> void:
    _inspect_portrait(id)
    if not world.visual_actors.has(id): return
    world.camera_focus = Placement.contact(world.visual_actors[id].row)
    world.position_camera()

func _process(delta: float) -> void:
    if world == null: return
    var phase = Time.get_ticks_usec()
    UI.poll_images(cache)
    var ready: bool = world.command_ready()
    var state: Dictionary = world.timeline.state
    var actor = _action_actor()
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
    var rebuild_bar = bar_changed or str(world.attack_preference) != last_preference or (resized and not bar_build.is_empty())
    bar_changed = rebuild_bar or ready != last_ready or selection != last_selection
    if changed or bar_changed:
        _refresh_status(actor)
        if panel.visible: _refresh_inventory()
        if not world.loot_object_uuid.is_empty(): loot_panel.refresh()
    if rebuild_bar: _rebuild_bar()
    elif bar_changed:
        var bar_phase = Time.get_ticks_usec()
        _close_popup()
        _refresh_bar_state()
        world.FrameProfile.end_phase(world.profile,"hud_bar_controls",bar_phase)
    if resized or rebuild_bar: _layout()
    _prepare_bar()
    last_revision = int(world.timeline.revision)
    last_ready = ready
    last_selection = selection
    last_preference = str(world.attack_preference)
    history_panel.refresh()
    _refresh_notice()
    var metric_text = "%d FPS" % Engine.get_frames_per_second()
    if world.timeline.paused: metric_text += " · Paused"
    elif world.timeline.waiting_for_media: metric_text += " · Loading…"
    var cursor = world.pick_cell(get_viewport().get_mouse_position())
    if not cursor.is_empty(): metric_text += "\n%d, %d · Z %s" % [cursor.position[0],cursor.position[1],cursor.height]
    if metrics.text != metric_text: metrics.text = metric_text
    if grid_button.button_pressed != world.grid_visible:
        grid_button.set_pressed_no_signal(world.grid_visible)
    if normals_button.button_pressed != world.normals_visible:
        normals_button.set_pressed_no_signal(world.normals_visible)
    end_button.disabled = not ready
    confirm_button.visible = not world.selected_action.is_empty() and world.selected_action.get("target_type") != "self"
    cancel_button.visible = confirm_button.visible
    confirm_button.disabled = not ready or not world.selection_preview.get("can_confirm",false)
    actor_hud.layout_in(viewport_size,bar.position.y,history_panel.get_global_rect() if history_panel.visible else Rect2(),confirm_button.get_global_rect().merge(cancel_button.get_global_rect()) if confirm_button.visible else Rect2())
    metrics.position = Vector2(20,18)
    if actor_hud.initiative.get_child_count()>0 and metrics.get_rect().intersects(actor_hud.initiative.get_global_rect()):
        metrics.position.y = actor_hud.initiative.get_rect().end.y+10
    if actor_hud.party.get_child_count()>0 and metrics.get_rect().intersects(actor_hud.party.get_global_rect()):
        metrics.position.x = actor_hud.party.get_rect().end.x+12
    top.position = Vector2(20,metrics.get_rect().end.y+8)
    if notice_row.visible and actor_hud.party.get_child_count()>0 and top.get_rect().intersects(actor_hud.party.get_global_rect()):
        top.position.y = actor_hud.party.get_rect().end.y+8
    if popup.visible:
        if popup_bridge.has_point(get_global_mouse_position()): popup_close_delay = 0.0
        else:
            popup_close_delay += delta
            if popup_close_delay > 0.25: _close_popup()
    var hover_phase = Time.get_ticks_usec()
    _refresh_world_labels()
    _refresh_hover_feedback()
    world.FrameProfile.end_phase(world.profile,"hud_hover_feedback",hover_phase)
    hover_phase = Time.get_ticks_usec()
    _update_ground_preview()
    world.FrameProfile.end_phase(world.profile,"hud_ground_preview",hover_phase)
    world.FrameProfile.end_phase(world.profile,"hud_process",phase)

func _refresh_status(actor: Dictionary) -> void:
    var state: Dictionary = world.timeline.state
    if inspected_actor_id.is_empty(): inspected_actor_id=str(actor.get("uuid",""))
    actor_hud.sync(state,actor,inspected_actor_id,cache)

func _rebuild_bar() -> void:
    var phase = Time.get_ticks_usec()
    _close_popup()
    world.FrameProfile.end_phase(world.profile,"hud_bar_controls",phase)
    phase = Time.get_ticks_usec()
    # Keep the previous passive owner until retained metadata is rebound.
    # Replaced bars transfer their remaining row owners when they retire.
    var prior_groups = groups
    groups = UI.families(painted_discovery,_action_actor())
    world.FrameProfile.end_phase(world.profile,"hud_families",phase)
    phase = Time.get_ticks_usec()
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
    # Only scalar layout values are retained here, never target payloads.
    # Preserve the existing columns/page calculation and visible family order.
    var topology: Array = []
    var visible: Array = []
    for group in UI.GROUPS:
        if not columns.has(group): continue
        var capacity: int = columns[group]*2
        var page_count = maxi(1,int(ceil(float(groups[group].size())/capacity)))
        pages[group] = clampi(int(pages[group]),0,page_count-1)
        var keys: Array = []
        var first: int = pages[group]*capacity
        for i in range(first,mini(first+capacity,groups[group].size())):
            var family: Dictionary = groups[group][i]
            var chosen = _preferred(family.rows)
            keys.append([family.key,_action_badge(chosen,family)])
            visible.append({"family":family,"chosen":chosen})
        topology.append([group,columns[group],pages[group],page_count,keys,
            str(world.attack_preference) if group == "Base" else ""])
    if topology == bar_topology and visible.size() == action_buttons.size():
        _cancel_bar_build()
        for i in range(visible.size()):
            _bind_action_button(action_buttons[i],visible[i].family,visible[i].chosen)
        _refresh_bar_state()
        world.session.retire_record(prior_groups)
        world.FrameProfile.end_phase(world.profile,"hud_bar_controls",phase)
        return
    _cancel_bar_build()
    var replacement = HBoxContainer.new()
    replacement.add_theme_constant_override("separation",12)
    replacement.mouse_filter = Control.MOUSE_FILTER_IGNORE
    replacement.hide()
    add_child(replacement)
    bar_build = {"key":_bar_request_key(),"root":replacement,"topology":topology,
        "visible":visible,"group_index":0,"row_index":0,"column":0,"grids":{},
        "headers":[],"buttons":[],"shortcuts":{},"preference":null,"settle_frame":-1}
    world.session.retire_record(prior_groups)
    _refresh_bar_state()
    world.FrameProfile.end_phase(world.profile,"hud_bar_controls",phase)

func bar_pending() -> bool:
    return not bar_build.is_empty()

func _bar_request_key() -> Array:
    return [world.timeline.state.get("current_actor_uuid"),
        world.available_actions.get("entity_uuid"),world.available_actions.get("discovery_generation"),
        get_viewport_rect().size,pages.values(),str(world.attack_preference)]

func _cancel_bar_build() -> void:
    if bar_build.is_empty(): return
    _retire_bar(bar_build.root,bar_build.buttons)
    world.session.retire_record({"rows":bar_build.visible})
    bar_build = {}

func _retire_bar(old: Control, buttons: Array) -> void:
    old.hide()
    old.process_mode = Node.PROCESS_MODE_DISABLED
    var families: Array = []
    for button in buttons:
        families.append(button.get_meta("family",{}))
        button.remove_meta("family")
        button.remove_meta("native_row")
    # Callbacks own their button, never a discovery payload. Transfer passive
    # rows before bounded scene-thread disposal of the native hierarchy.
    world.session.retire_record({"families":families})
    retired_bars.append(old)

func _retire_bar_slice() -> void:
    for _unit in range(BAR_RETIRE_UNITS):
        if retired_bars.is_empty(): break
        var node: Node = retired_bars[0]
        while node.get_child_count() > 0: node = node.get_child(0)
        if node == retired_bars[0]: retired_bars.pop_front()
        node.free()

func _build_bar_group(plan: Array) -> void:
    var group: String = plan[0]
    var block = VBoxContainer.new()
    block.add_theme_constant_override("separation",3)
    block.mouse_filter = Control.MOUSE_FILTER_STOP
    block.mouse_force_pass_scroll_events = false
    block.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            _page(group,-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
            block.accept_event())
    bar_build.root.add_child(block)
    var header = HBoxContainer.new()
    bar_build.headers.append(header)
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
        bar_build.preference = mode
        mode.tooltip_text = "Ordinary creature click uses this weapon set. X switches the preference."
        mode.focus_mode = Control.FOCUS_NONE
        mode.disabled = not world.command_ready()
        mode.add_theme_font_size_override("font_size",12)
        mode.pressed.connect(func():
            if bar_build.is_empty() and world.command_ready(): world.toggle_attack_preference())
        header.add_child(mode)
    var page_count: int = plan[3]
    if page_count > 1:
        for sign_value in [-1,1]:
            var step = Button.new()
            step.text = "‹" if sign_value < 0 else "›"
            step.focus_mode = Control.FOCUS_NONE
            step.tooltip_text = "%s page %d / %d" % [group,plan[2]+1,page_count]
            step.pressed.connect(func():_page(group,sign_value))
            header.add_child(step)
    var grid = GridContainer.new()
    grid.columns = plan[1]
    grid.add_theme_constant_override("h_separation",GAP)
    grid.add_theme_constant_override("v_separation",GAP)
    block.add_child(grid)
    bar_build.grids[group] = grid

func _build_bar_button(index: int, plan: Array, local_index: int) -> void:
    var family: Dictionary = bar_build.visible[index].family
    var chosen: Dictionary = bar_build.visible[index].chosen
    var group: String = plan[0]
    var button = _icon_button(UI.action_key(chosen,world.timeline.state,cache),UI.action_text(chosen),family.label)
    _bind_action_button(button,family,chosen)
    button.set_meta("group",group)
    button.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            _page(group,-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
            button.accept_event())
    button.pressed.connect(func():
        var current: Dictionary = button.get_meta("family",{})
        if not current.is_empty(): _activate_family(current,button))
    button.mouse_entered.connect(func():
        var current: Dictionary = button.get_meta("family",{})
        if not current.is_empty() and _choices(current.rows).size() > 1: _open_choices(current,button))
    bar_build.grids[group].add_child(button)
    bar_build.buttons.append(button)
    var shortcut_index = bar_build.column + local_index%int(plan[1]) + 12*int(local_index/int(plan[1]))
    bar_build.shortcuts[shortcut_index] = button
    _badge(button,_shortcut_label(shortcut_index),false)
    var badge = _action_badge(chosen,family)
    if not badge.is_empty(): _badge(button,badge,true)

func _prepare_bar() -> void:
    var phase = Time.get_ticks_usec()
    bar_build_units = 0
    _retire_bar_slice()
    if not bar_build.is_empty() and bar_build.key != _bar_request_key(): _cancel_bar_build()
    while not bar_build.is_empty() and bar_build_units < BAR_BUILD_UNITS:
        if bar_build.settle_frame >= 0:
            if Engine.get_process_frames() > bar_build.settle_frame: _publish_bar()
            break
        if bar_build.group_index == bar_build.topology.size():
            # Let native containers finish deferred layout while hidden.
            var header_height = 0.0
            for header in bar_build.headers: header_height = maxf(header_height,header.get_combined_minimum_size().y)
            for header in bar_build.headers: header.custom_minimum_size.y = header_height
            bar_build.settle_frame = Engine.get_process_frames()
            break
        var plan: Array = bar_build.topology[bar_build.group_index]
        if not bar_build.grids.has(plan[0]):
            _build_bar_group(plan)
        else:
            _build_bar_button(bar_build.buttons.size(),plan,bar_build.row_index)
            bar_build.row_index += 1
            if bar_build.row_index == plan[4].size():
                bar_build.column += plan[1]
                bar_build.row_index = 0
                bar_build.group_index += 1
        bar_build_units += 1
        if Time.get_ticks_usec()-phase >= BAR_BUILD_USEC: break
    world.FrameProfile.end_phase(world.profile,"hud_bar_build",phase)

func _publish_bar() -> void:
    if bar_build.key != _bar_request_key():
        _cancel_bar_build()
        return
    _retire_bar(bar,action_buttons)
    bar = bar_build.root
    action_buttons = bar_build.buttons
    shortcuts = bar_build.shortcuts
    preference_button = bar_build.preference
    bar_topology = bar_build.topology
    bar_build = {}
    _refresh_bar_state()
    _layout()
    bar.show()

func _action_badge(row: Dictionary, family: Dictionary) -> String:
    if row.get("weapon_slot") != null: return "M" if str(row.weapon_slot).begins_with("MELEE") else "R"
    return "▴" if _choices(family.rows).size()>1 else ""

func _bind_action_button(button: Button, family: Dictionary, row: Dictionary) -> void:
    button.set_meta("native_row",row)
    button.set_meta("family",family)
    _set_button_icon(button,UI.action_key(row,world.timeline.state,cache),UI.action_text(row),family.label)

func _refresh_bar_state() -> void:
    var ready: bool = world.command_ready() and bar_build.is_empty()
    var selected = "" if world.selected_action.is_empty() else UI.family_key(world.selected_action)
    for button in action_buttons:
        button.disabled = not ready or not _row_current(button.get_meta("native_row")) or not UI.available(button.get_meta("native_row"))
        var active: bool = button.get_meta("family").key == selected
        if active != button.has_theme_stylebox_override("normal"):
            if active: button.add_theme_stylebox_override("normal",_style(Color("3b493dcb"),Color("ebcb85")))
            else: button.remove_theme_stylebox_override("normal")
    if is_instance_valid(preference_button): preference_button.disabled = not ready

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
    if not bar_build.is_empty() or not world.command_ready() or not _row_current(family.rows[0]) or not Interaction.owns_action(world.available_actions,family.rows[0]): return
    var choices = _choices(family.rows)
    if choices.size() > 1: _open_choices(family,origin)
    else: _select_row(choices[0])

func _select_row(row: Dictionary) -> void:
    if not bar_build.is_empty() or not world.command_ready() or not UI.available(row): return
    # Reject controls left from a different actor/discovery even before next redraw.
    if not _row_current(row) or not Interaction.owns_action(world.available_actions,row): return
    _close_popup()
    world.select_action(row)

func _row_current(row: Dictionary) -> bool:
    var actor = world.timeline.state.get("current_actor_uuid")
    return row.get("discovery_generation",0) == world.available_actions.get("discovery_generation") and world.available_actions.get("entity_uuid") == actor and (row.get("discovery_actor_uuid") == null or row.discovery_actor_uuid == actor)

func _page(group: String, direction: int) -> void:
    pages[group] = maxi(0,int(pages[group])+direction)
    _rebuild_bar()
    _layout()

func _open_choices(family: Dictionary, origin: Control) -> void:
    if not bar_build.is_empty() or not world.command_ready() or not _row_current(family.rows[0]) or not Interaction.owns_action(world.available_actions,family.rows[0]): return
    if popup.visible and popup_family == family.key: return
    _close_popup()
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
        popup_rows.append(button)
        button.disabled = not world.command_ready() or not UI.available(row)
        button.pressed.connect(func():_select_row(button.get_meta("native_row",{})))
        grid.add_child(button)
        if row.get("cast_at_level") != null: _badge(button,str(row.cast_at_level),true)
    var rows_count = int(ceil(float(grid.get_child_count())/5))
    scroll.custom_minimum_size.y = minf(230,rows_count*(ICON+GAP+4))
    popup.size = Vector2(310,scroll.custom_minimum_size.y+34)
    popup.position = Vector2(clampf(origin.global_position.x,8,get_viewport_rect().size.x-popup.size.x-8),maxf(8,origin.global_position.y-popup.size.y+2))
    # Native GUI picking follows sibling order, independently of paint z_index.
    # Rebuilt action bars are appended later; keep choices above them for input.
    move_child(popup,get_child_count()-1)
    popup.visible = true
    popup_bridge = popup.get_global_rect().merge(origin.get_global_rect())
    popup_close_delay = 0.0

func _close_popup() -> void:
    var retired: Array = []
    for button in popup_rows:
        if is_instance_valid(button):
            retired.append(button.get_meta("native_row",{}))
            button.remove_meta("native_row")
    if not retired.is_empty(): world.session.retire_record({"rows":retired})
    popup_rows.clear()
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
    world.close_storage()
    settings_panel.show_panel()

func close_settings() -> void:
    settings_panel.hide_panel()

func toggle_inventory() -> void:
    if settings_open(): return
    panel.visible = not panel.visible
    if panel.visible:
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
    if event is InputEventMouseMotion and event.relative != Vector2.ZERO:
        hover_feedback_dismissed = false
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
        elif panel.visible: toggle_inventory()
        elif not world.selected_action.is_empty(): world.cancel_selection()
        else: open_settings()
        get_viewport().set_input_as_handled()
        return
    var focus = get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit: return
    if event.keycode>=KEY_F1 and event.keycode<=KEY_F4:
        var index = event.keycode-KEY_F1
        if index<actor_hud.party_ids.size(): _focus_portrait(actor_hud.party_ids[index])
        get_viewport().set_input_as_handled()
        return
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

# Resolve the same admitted binding used by the click. A body underneath a
# position-target spell does not turn that spell into an entity-target action.
func _hover_target_subject() -> String:
    var intent: Dictionary = world.hover_intent
    if intent.is_empty(): return ""
    if intent.kind == "target":
        var target: Dictionary = intent.get("value",{}).get("target",{})
        if target.is_empty(): return ""
        var domains: Dictionary = world.available_actions if world.selection_preview.is_empty() else world.selection_preview
        var subject: Variant = Choices.binding_subject(domains,target)
        return str(subject.uuid) if subject != null else ""
    if intent.kind in ["attack","storage","interaction","approach","context"]:
        return str(world.hover_hit.get("id",""))
    return ""

func clear_hover_feedback() -> void:
    hover_feedback_dismissed = true
    for id in hover_outline.owners.keys(): hover_outline.erase(world,id)
    _restore_object_highlights()
    hover_object_key = []

func _restore_object_highlights() -> void:
    for material in hover_object_materials:
        material.set_shader_parameter("highlighted",hover_object_materials[material])
    hover_object_materials.clear()

func _refresh_hover_feedback() -> void:
    var focus = get_viewport().gui_get_focus_owner()
    var alt = not settings_open() and Input.is_key_pressed(KEY_ALT) and not (focus is LineEdit or focus is TextEdit)
    var ready: bool = world.command_ready() and not settings_open()
    var subject = _hover_target_subject() if ready and not pointer_over_controls() and not hover_feedback_dismissed else ""
    var actor_id = subject if world.visual_actors.has(subject) else ""
    for id in hover_outline.owners.keys():
        if id != actor_id: hover_outline.erase(world,id)
    if not actor_id.is_empty():
        hover_outline.sample(world,actor_id,{"outline":{"color":0x70d6be,"pulseColor":0x70d6be,"opacity":.9,"pulseOpacity":0.0},"outline_age_ms":0.0,"outline_initial":true,"outline_alpha":1.0})
        if hover_outline.owners.has(actor_id): hover_outline.owners[actor_id].entry.id = actor_id+":hover_outline"
    var key = [alt,subject,ready,world.timeline.world_revision,world.world_generation,world.quarter]
    if key == hover_object_key and is_same(world.available_actions,hover_object_discovery): return
    hover_object_key = key
    hover_object_discovery = world.available_actions
    _restore_object_highlights()
    if not ready or (not alt and subject.is_empty()): return
    var objects = {}
    for row in world.world_labels():
        # Scenery sight is the displayed renderer's native disclosure set;
        # remembered map objects and force-picked hidden walls stay unmarked.
        if not world.scenery_visibility.has(row.id): continue
        if alt or row.id == subject: objects[row.id] = true
    if objects.is_empty(): return
    for entry in world.static_entries:
        if entry.role == "shadow" or not entry.node.visible or not objects.has(entry.placement.id): continue
        var material: ShaderMaterial = entry.material
        hover_object_materials[material] = material.get_shader_parameter("highlighted")
        material.set_shader_parameter("highlighted",true)

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
        var label_text = str(world.hover_hit.get("label",""))
        if not world.selected_action.is_empty():
            label_text = str(world.selected_action.display_name)+(": "+label_text if not label_text.is_empty() else "")
            if world.selected_action.get("target_type")=="multi_entity":
                var count = world.target_selection.get("target_indices",[]).size()
                var total = world.selected_action.get("num_projectiles")
                label_text += "\n"+("%d / %d selected" % [count,total] if total!=null else "%d selected" % count)
        elif not world.hover_intent.is_empty():
            label_text = str(world.hover_intent.label)+(": "+label_text if not label_text.is_empty() else "")
        var shown: Dictionary = world.hover_preview if not world.hover_preview.is_empty() else world.selection_preview
        var affected: Array = shown.get("affected_entity_names",[])
        if not affected.is_empty(): label_text += "\nTargets: "+(", ".join(affected) if affected.size()<=3 else str(affected.size()))
        var counts = {}
        for id in shown.get("effective_target_uuids",[]): counts[id]=int(counts.get(id,0))+1
        if not counts.is_empty():
            var allocations: Array[String] = []
            for id in counts:
                var name: String = world.timeline.state.get("actors",{}).get(id,{}).get("name","Target")
                allocations.append("%s ×%d" % [name,counts[id]])
            label_text += "\nAllocation: "+(", ".join(allocations) if allocations.size()<=3 else "%d recipients · %d applications" % [counts.size(),shown.effective_target_uuids.size()])
        var route = shown.get("selected_route")
        if route != null:
            label_text += "\n%s ft" % str(route.get("cost_feet",0))
            if route.get("is_hazardous",false): label_text += " · Hazardous"
            if not route.get("opportunity_attack_exposures",[]).is_empty(): label_text += " · Opportunity attack"
        if hover_info.text != label_text: hover_info.text = label_text
        hover_info.position = get_global_mouse_position()+Vector2(18,20)
        hover_info.position = hover_info.position.min(get_viewport_rect().size-hover_info.get_combined_minimum_size()-Vector2(8,8)).max(Vector2(8,8))
        if history_panel.visible and Rect2(hover_info.position,hover_info.get_combined_minimum_size()).intersects(history_panel.get_global_rect()):
            hover_info.position.x = maxf(8.0,history_panel.get_global_rect().position.x-hover_info.get_combined_minimum_size().x-8.0)

func _refresh_notice() -> void:
    notice.text = world.notice_text
    notice_row.visible = not notice.text.is_empty()
    copy_notice.text = "Copied" if copied_notice==notice.text else "Copy"

func _copy_notice() -> void:
    if notice.text.is_empty(): return
    DisplayServer.clipboard_set(JSON.stringify(world.error_report(notice.text),"  "))
    copied_notice = notice.text
    copy_notice.text = "Copied"

func pointer_over_controls(point: Vector2 = Vector2.INF) -> bool:
    if settings_open(): return true
    if point == Vector2.INF: point = get_global_mouse_position()
    if actor_hud.contains(point): return true
    if panel.visible and panel.get_global_rect().has_point(point): return true
    if loot_panel.visible and loot_panel.get_global_rect().has_point(point): return true
    if history_panel.visible and history_panel.get_global_rect().has_point(point): return true
    if popup.visible and popup_bridge.has_point(point): return true
    for control in [bar,inventory_button,history_button,grid_button,normals_button,end_button,confirm_button,cancel_button,copy_notice]:
        if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
    for control in world_label_buttons.values():
        if control.get_global_rect().has_point(point): return true
    return false

func owns_keyboard_focus() -> bool:
    if settings_open(): return true
    var focus = get_viewport().gui_get_focus_owner()
    return focus != null and history_panel.visible and history_panel.is_ancestor_of(focus)

var ground_preview_key: Array = []
var ground_preview_source: Dictionary = {}
var ground_preview_choices: Dictionary = {}
var ground_preview_eligibility: Dictionary = {}
var ground_base_key: Array = []
var ground_base_choices: Dictionary = {}
var ground_base_eligibility: Dictionary = {}
var ground_base_marks: Dictionary = {}

func _update_ground_preview() -> void:
    if not is_instance_valid(world.camera) or world.timeline.state.is_empty(): return
    var ready: bool = world.command_ready()
    var over_ui = pointer_over_controls()
    var entity_click = not _hover_target_subject().is_empty()
    var cursor: Dictionary = {} if over_ui or entity_click else world.pick_cell(get_viewport().get_mouse_position())
    # A position spell aimed over elevated artwork uses its admitted target
    # position, not a different floor cell found by projecting below the body.
    var aimed_position: Variant = world.hover_intent.get("value",{}).get("position")
    if not over_ui and not entity_click and aimed_position != null:
        cursor = {"position":aimed_position}
    var preview: Dictionary = (world.hover_preview if not world.hover_preview.is_empty() else world.selection_preview) if ready and not over_ui else {}
    var eligibility: Dictionary = world.selection_preview if ready and not world.selected_action.is_empty() else preview
    var current: Dictionary = world.visual_actors.get(world.timeline.state.get("current_actor_uuid",""),{}).get("row",{})
    var show_reachable: bool = ready and not over_ui and world.selected_action.is_empty() and world.hover_hit.get("kind")=="ground"
    var key = [world.timeline.world_revision,cursor,current.get("position"),show_reachable,ready]
    if key==ground_preview_key and is_same(preview,ground_preview_source) and is_same(eligibility,ground_preview_eligibility) and is_same(world.available_actions,ground_preview_choices): return
    ground_preview_key = key.duplicate(true)
    ground_preview_source = preview
    ground_preview_choices = world.available_actions
    ground_preview_eligibility = eligibility
    # The selected-prefix legal set does not move with the pointer. Reuse its
    # immutable styles while replacing only affected cells, actor and cursor.
    # Disclosed support/choice/prefix changes still invalidate that set.
    var base_key = [world.timeline.world_revision,show_reachable]
    if base_key!=ground_base_key or not is_same(eligibility,ground_base_eligibility) or not is_same(world.available_actions,ground_base_choices):
        ground_base_key = base_key
        ground_base_eligibility = eligibility
        ground_base_choices = world.available_actions
        ground_base_marks = {}
        if show_reachable:
            for action in world.available_actions.get("position_actions",[]):
                if action.behavior_id!="action.move" or action.availability_status!="available": continue
                if not action.get("variant_facets",[]).any(func(f):return f.key=="movement" and f.value=="walking"): continue
                for target in Choices.action_options(world.available_actions,action):
                    var position = Choices.binding_position(world.available_actions,target)
                    if position!=null: _ground_mark(ground_base_marks,position,Color(0.45,0.83,0.76,0.24),1.0)
                break
        if not eligibility.is_empty():
            for target in Choices.next_options(eligibility):
                var position = Choices.binding_position(eligibility,target)
                if position!=null: _ground_mark(ground_base_marks,position,Color(0.45,0.83,0.76,0.45))
        for position in Choices.preview_positions(eligibility): _ground_mark(ground_base_marks,position,Color(0.45,0.83,0.76,0.65))
    var marks = ground_base_marks.duplicate()
    for position in Choices.preview_positions(preview,true):
        _ground_mark(marks,position,Color(0.92,0.73,0.36,0.8))
        var affected_key = "%d,%d" % [position[0],position[1]]
        if preview.get("area_preview")=="computed" and marks.has(affected_key): marks[affected_key].fill_colour=Color(0.92,0.59,0.23,0.2)
    for id in preview.get("affected_entity_uuids",[]):
        var row: Dictionary=world.visual_actors.get(id,{}).get("row",{})
        if not row.is_empty(): _ground_mark(marks,row.position,Color("f0aa69"),3.0)
    if not current.is_empty(): _ground_mark(marks,current.position,Color("e9c87e"))
    if not cursor.is_empty(): _ground_mark(marks,cursor.position,Color("70d6be"))
    var route = preview.get("selected_route")
    var colour = Color("70d6be")
    if route!=null and (route.get("is_hazardous",false) or not route.get("opportunity_attack_exposures",[]).is_empty()): colour=Color("eb8a6d")
    world.ground_overlay.set_preview(marks,route.path if route!=null else [],colour)

func _ground_mark(marks: Dictionary, position: Array, colour: Color, width: float=2.0) -> void:
    var key = "%d,%d" % [position[0],position[1]]
    if world.timeline.state.tiles.has(key):
        var style: Dictionary=marks.get(key,{}).duplicate()
        style.colour=colour; style.width=width
        marks[key]=style

func _exit_tree() -> void:
    if is_instance_valid(world):
        hover_outline.close(world)
        _restore_object_highlights()
    _cancel_bar_build()
    UI.close_images(cache)
