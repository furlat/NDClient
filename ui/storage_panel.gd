extends PanelContainer
# A view of disclosed storage; commands and inventory remain backend-owned.
var hud: Control
var title = Label.new()
var close_button = Button.new()
var grid = GridContainer.new()
var summary = Label.new()
var details = RichTextLabel.new()
var take_button = Button.new()
var loot_all_button = Button.new()
var item_buttons: Dictionary = {}
var selected_item = ""
var painted_items: Array = []
var painted_object = ""

func _ready() -> void:
    visible = false
    z_index = 12
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_force_pass_scroll_events = false
    var stack = VBoxContainer.new()
    stack.add_theme_constant_override("separation",8)
    add_child(stack)
    var header = HBoxContainer.new()
    stack.add_child(header)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size",18)
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    header.add_child(title)
    close_button.text = "×"
    close_button.tooltip_text = "Close loot window · Escape"
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.pressed.connect(func():hud.world.close_storage())
    header.add_child(close_button)
    stack.add_child(summary)
    var scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 70
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    scroll.mouse_force_pass_scroll_events = false
    stack.add_child(scroll)
    grid.columns = 6
    grid.add_theme_constant_override("h_separation",4)
    grid.add_theme_constant_override("v_separation",4)
    scroll.add_child(grid)
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    details.bbcode_enabled = false
    details.selection_enabled = true
    details.custom_minimum_size.y = 52
    stack.add_child(details)
    var actions = HBoxContainer.new()
    stack.add_child(actions)
    take_button.text = "Take selected"
    loot_all_button.text = "Loot All"
    for button in [take_button,loot_all_button]:
        button.focus_mode = Control.FOCUS_NONE
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        actions.add_child(button)
    take_button.pressed.connect(func():
        if not selected_item.is_empty(): hud.world.loot_storage(selected_item))
    loot_all_button.pressed.connect(func():hud.world.loot_storage())

func refresh() -> void:
    var world = hud.world
    var object: Dictionary = world.storage_view()
    if object.is_empty():
        visible = false
        return
    visible = true
    title.text = str(object.item.get("name","Storage"))
    var items: Array = object.contained_items
    var identity: String = world.loot_object_uuid
    if identity != painted_object:
        selected_item = ""
    if identity != painted_object or items != painted_items:
        hud._clear(grid)
        item_buttons.clear()
        painted_object = identity
        painted_items = items.duplicate(true)
        if not items.any(func(item):return item.item_uuid == selected_item): selected_item = ""
        for item in items:
            var id: String = item.item_uuid
            var name: String = hud.UI.item_name(item,world.timeline.state,hud.cache)
            var button: Button = hud._icon_button(hud.UI.item_key(item,world.timeline.state,hud.cache),name+"\nDouble-click to take",name)
            button.set_meta("item_uuid",id)
            button.pressed.connect(func():selected_item = id; _selection())
            button.gui_input.connect(func(event):
                if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
                    world.loot_storage(id)
                    button.accept_event())
            grid.add_child(button)
            item_buttons[id] = button
            if int(item.get("stack_count",1))>1: hud._badge(button,str(item.stack_count),true)
    summary.text = "Empty" if items.is_empty() else "%d item%s" % [items.size(),"" if items.size()==1 else "s"]
    if not world.command_ready(): summary.text += " · Waiting for the current action…"
    loot_all_button.disabled = world.storage_action().is_empty()
    _selection()

func _selection() -> void:
    var item: Dictionary = {}
    for row in painted_items:
        if row.item_uuid == selected_item: item = row; break
    for id in item_buttons:
        item_buttons[id].remove_theme_stylebox_override("normal")
        if id==selected_item:
            item_buttons[id].add_theme_stylebox_override("normal",hud._style(Color("355748bd"),Color("a8d4ae")))
    take_button.disabled = item.is_empty() or hud.world.storage_action(selected_item).is_empty()
    if item.is_empty(): details.text = "Select an item, or loot everything."
    else:
        details.text = hud.UI.item_name(item,hud.world.timeline.state,hud.cache)
        if int(item.get("stack_count",1))>1: details.text += " × %d" % item.stack_count
        if item.get("description") != null: details.text += "\n"+str(item.description)
