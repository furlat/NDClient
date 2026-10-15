extends Control
# A modal native Control view of the renderer's accepted local settings.
const Settings = preload("res://presentation/render_settings.gd")
var hud: Control
var card = PanelContainer.new()
var profiles = OptionButton.new()
var fire_flicker = CheckBox.new()
var light_cap = CheckBox.new()
var spell_hits = OptionButton.new()
var strength = HSlider.new()
var strength_value = Label.new()
var strength_save = Timer.new()
var description = Label.new()
var resume_button = Button.new()
var close_button = Button.new()
var prior_focus: WeakRef
var stack=VBoxContainer.new()
const DESCRIPTIONS = {
    "original":"Original lighting detail, without normal smoothing.",
    "gentle":"A softer lighting response with light smoothing.",
    "reference":"The smoother lighting used in the character preview."
}

func _ready() -> void:
    visible = false
    z_index = 40
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_force_pass_scroll_events = false
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop = ColorRect.new()
    backdrop.color = Color(0.025,0.035,0.045,0.48)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(card)
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    var border = hud._style(Color("142027f5"),Color("a8a38b99"))
    border.set_corner_radius_all(8)
    border.content_margin_left = 24
    border.content_margin_right = 24
    border.content_margin_top = 20
    border.content_margin_bottom = 22
    card.add_theme_stylebox_override("panel",border)
    var scroll=ScrollContainer.new()
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    card.add_child(scroll)
    stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    stack.add_theme_constant_override("separation",16)
    scroll.add_child(stack)
    var header = HBoxContainer.new()
    stack.add_child(header)
    var title = Label.new()
    title.text = "Settings"
    title.add_theme_font_size_override("font_size",24)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    close_button.text = "×"
    close_button.tooltip_text = "Close · Escape"
    close_button.focus_mode = Control.FOCUS_ALL
    close_button.pressed.connect(hud.close_settings)
    header.add_child(close_button)
    var field = VBoxContainer.new()
    field.add_theme_constant_override("separation",8)
    stack.add_child(field)
    var label = Label.new()
    label.text = "Character light smoothness"
    field.add_child(label)
    profiles.custom_minimum_size.y = 38
    for profile in Settings.PROFILES:
        profiles.add_item(Settings.PROFILES[profile])
        profiles.set_item_metadata(profiles.item_count-1,profile)
    profiles.item_selected.connect(_select_profile)
    field.add_child(profiles)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.custom_minimum_size.y = 42
    description.add_theme_color_override("font_color",Color("b8c4c7"))
    field.add_child(description)
    fire_flicker.text = "Fire light flicker"
    fire_flicker.tooltip_text = "Animate fire brightness and emission height. Off keeps the authored average; flame artwork and character movement continue."
    fire_flicker.toggled.connect(_select_fire_flicker)
    stack.add_child(fire_flicker)
    var lighting = VBoxContainer.new()
    lighting.add_theme_constant_override("separation",4)
    stack.add_child(lighting)
    var strength_header = HBoxContainer.new()
    lighting.add_child(strength_header)
    var strength_label = Label.new()
    strength_label.text = "Light strength"
    strength_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    strength_header.add_child(strength_label)
    strength_header.add_child(strength_value)
    strength.min_value = 0
    strength.max_value = Settings.MAX_LIGHT_STRENGTH
    strength.step = .01
    strength.custom_minimum_size.y = 28
    strength.tooltip_text = "Adjust scene light brightness."
    strength.value_changed.connect(_select_strength)
    lighting.add_child(strength)
    strength_save.one_shot = true
    strength_save.wait_time = .2
    strength_save.timeout.connect(_save_strength)
    add_child(strength_save)
    light_cap.text = "Limit overlapping lights"
    light_cap.tooltip_text = "Limit combined illumination while preserving the light colour. Dim lighting and source transparency are unchanged."
    light_cap.toggled.connect(_select_light_cap)
    lighting.add_child(light_cap)
    var hit_label=Label.new();hit_label.text="Spell hit appearance";stack.add_child(hit_label)
    spell_hits.add_item("Colour treatment");spell_hits.add_item("Full spell material")
    spell_hits.item_selected.connect(func(index:int):hud.world.set_native_spell_hit_material(index==1))
    stack.add_child(spell_hits)
    var note = Label.new()
    note.text = "The game continues while settings are open."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size",12)
    note.add_theme_color_override("font_color",Color("9caeb2"))
    stack.add_child(note)
    resume_button.text = "Back to game"
    resume_button.custom_minimum_size.y = 38
    resume_button.pressed.connect(hud.close_settings)
    stack.add_child(resume_button)
    card.minimum_size_changed.connect(func(): _layout.call_deferred())
    resized.connect(_layout)
    _layout()

func _layout() -> void:
    if not is_node_ready(): return
    var width = minf(440,maxf(240,size.x-40))
    card.size = Vector2(width,minf(maxf(100,size.y-40),stack.get_combined_minimum_size().y+42))
    card.position = (size-card.size)*0.5

func refresh() -> void:
    strength.set_value_no_signal(hud.world.light_strength)
    strength_value.text = "%d%%" % roundi(hud.world.light_strength*100)
    fire_flicker.set_pressed_no_signal(hud.world.fire_light_flicker)
    light_cap.set_pressed_no_signal(hud.world.light_cap_enabled)
    spell_hits.select(1 if hud.world.native_spell_hit_material else 0)
    var profile: String = hud.world.character_light_profile
    for index in range(profiles.item_count):
        if profiles.get_item_metadata(index)==profile: profiles.select(index);break
    description.text = DESCRIPTIONS.get(profile,"")
    _layout()

func show_panel() -> void:
    var focus = get_viewport().gui_get_focus_owner()
    prior_focus = weakref(focus) if focus != null else null
    if focus != null: focus.release_focus()
    refresh()
    show()
    profiles.grab_focus()

func hide_panel() -> void:
    if not strength_save.is_stopped(): _save_strength()
    profiles.get_popup().hide()
    spell_hits.get_popup().hide()
    var focus = get_viewport().gui_get_focus_owner()
    if focus != null and is_ancestor_of(focus): focus.release_focus()
    hide()
    var previous = prior_focus.get_ref() if prior_focus != null else null
    prior_focus = null
    if previous != null and previous.is_visible_in_tree(): previous.grab_focus()

func escape() -> void:
    if profiles.get_popup().visible: profiles.get_popup().hide()
    elif spell_hits.get_popup().visible: spell_hits.get_popup().hide()
    else: hud.close_settings()

func _select_profile(index: int) -> void:
    var profile: String = profiles.get_item_metadata(index)
    if profile != hud.world.character_light_profile:
        hud.world.set_character_light_profile(profile)
    refresh()

func _select_fire_flicker(enabled: bool) -> void:
    hud.world.set_fire_light_flicker(enabled)

func _select_light_cap(enabled: bool) -> void:
    hud.world.set_light_cap_enabled(enabled)

func _select_strength(value: float) -> void:
    hud.world.set_light_strength(value,false)
    strength_value.text = "%d%%" % roundi(value*100)
    strength_save.start() # Native response is immediate; avoid disk writes per drag sample.

func _save_strength() -> void:
    strength_save.stop()
    hud.world.set_light_strength(strength.value)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouse: accept_event()
