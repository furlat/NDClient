extends RefCounted

static func button(parent: Node, label: String, callback: Callable) -> Button:
    var node = Button.new()
    node.text = label
    node.pressed.connect(callback)
    parent.add_child(node)
    return node

static func build(host: Node) -> void:
    var canvas = CanvasLayer.new()
    host.add_child(canvas)
    var panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
    panel.offset_left = -310
    panel.offset_right = -16
    panel.offset_top = 16
    panel.offset_bottom = -16
    canvas.add_child(panel)
    var column = VBoxContainer.new()
    panel.add_child(column)
    var title = Label.new()
    title.text = "  ENVIRONMENT WORKSHOP"
    column.add_child(title)
    var modes = HBoxContainer.new()
    column.add_child(modes)
    button(modes,"Select",func(): host.preview_mode = false; host.editor_tool = "select"; host.editor_notice("Select an object to inspect or move."))
    button(modes,"Place",func(): host.preview_mode = false; host.editor_tool = "place"; host.editor_notice("Click the floor to place the palette asset."))
    button(modes,"Move",func(): host.preview_mode = false; host.editor_tool = "move"; host.editor_notice("Click the destination for the selected assembly."))
    var preview = HBoxContainer.new(); column.add_child(preview)
    button(preview,"Break preview",func(): host.preview_mode = true; host.editor_notice("Click authored breakables. Hold Alt to highlight."))
    button(preview,"Play sequence",func(): host.preview_selected_sequence())
    var search = LineEdit.new()
    search.placeholder_text = "Search all environment assets…"
    column.add_child(search)
    var filter = OptionButton.new()
    for group in ["All", "props", "doors", "traps", "terrain", "walls", "registered", "library"]: filter.add_item(group)
    column.add_child(filter)
    var palette = ItemList.new()
    palette.custom_minimum_size = Vector2(280,160)
    palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(palette)
    host.palette_list = palette
    var refresh = func():
        palette.clear()
        for entry in host.asset_catalog:
            if filter.selected > 0 and entry.group != filter.get_item_text(filter.selected): continue
            if not search.text.is_empty() and not (search.text.to_lower() in (entry.label + " " + entry.id).to_lower()): continue
            var index = palette.add_item(entry.label + (" [registration]" if not entry.placeable else ""))
            palette.set_item_metadata(index,entry.id)
            palette.set_item_tooltip(index,entry.id + "\n" + entry.get("reason", ""))
            if not entry.placeable: palette.set_item_custom_fg_color(index,Color(0.75,0.48,0.32))
    search.text_changed.connect(func(_value): refresh.call())
    filter.item_selected.connect(func(_value): refresh.call())
    palette.item_selected.connect(func(index):
        host.palette_id = palette.get_item_metadata(index)
        var entry = host.catalog_by_id[host.palette_id]
        host.configure_source_choices({"kind":entry.kind,"asset":entry.get("asset","")})
        host.editor_notice(entry.id + "\n" + entry.get("reason", "")))
    refresh.call()
    var source_choice = OptionButton.new()
    source_choice.fit_to_longest_item = false
    source_choice.clip_text = true
    column.add_child(source_choice)
    host.source_choice = source_choice
    var frame_row = HBoxContainer.new(); column.add_child(frame_row)
    var frame_label = Label.new(); frame_label.text = "Source frame"; frame_row.add_child(frame_label)
    var frame_control = SpinBox.new(); frame_control.min_value=0; frame_control.max_value=0; frame_control.step=1; frame_row.add_child(frame_control)
    host.frame_control = frame_control
    source_choice.item_selected.connect(func(_index): host.update_frame_range())
    var dimensions = HBoxContainer.new()
    column.add_child(dimensions)
    var h = Label.new(); h.text = "Height"; dimensions.add_child(h)
    var height = SpinBox.new(); height.min_value = -4; height.max_value = 32; height.step = 0.5; dimensions.add_child(height)
    host.height_control = height
    var angle = OptionButton.new()
    for direction in ["east","north","west","south"]: angle.add_item(direction)
    dimensions.add_child(angle)
    host.orientation_control = angle
    var transforms = HBoxContainer.new(); column.add_child(transforms)
    button(transforms,"Apply changes",func(): host.transform_selected())
    button(transforms,"Delete",func(): host.delete_selected())
    var navigation = HBoxContainer.new(); column.add_child(navigation)
    button(navigation,"Locate asset",func(): host.locate_palette())
    button(navigation,"Bring character",func(): host.bring_character())
    var operations = HBoxContainer.new(); column.add_child(operations)
    button(operations,"Save map",func(): host.save_map())
    button(operations,"Load map",func(): host.load_map())
    button(operations,"Undo",func(): host.undo_edit())
    var resets = HBoxContainer.new(); column.add_child(resets)
    button(resets,"Reset breaks",func(): host.reset_destruction())
    button(resets,"Catalog map",func(): host.load_scene(3))
    var scaling = HBoxContainer.new(); column.add_child(scaling)
    for count in [1,2,4]:
        button(scaling,str(count)+"× map",func(): host.resize_catalog(count))
    var info = Label.new()
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.custom_minimum_size = Vector2(280,86)
    column.add_child(info)
    host.editor_info = info
    host.editor_notice("Middle-drag pans · wheel zooms · Q/E rotates\nSelect, place or preview destruction.\nAlt highlights authored breakables; R restores them.")
