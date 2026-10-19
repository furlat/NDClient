extends Control
## The live player's first frame. Engine start is followed by about 1.5 s of
## player-scene loading (scripts, shaders, preloads) that drew nothing: a black
## window. This scene draws a readable notice at once, loads the player on a
## worker and replaces itself; the player's own startup notice continues it.
const PLAYER = "res://play.tscn"
var label := Label.new()

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var font := SystemFont.new(); font.font_names = PackedStringArray(["Segoe UI","DejaVu Sans"])
    label.add_theme_font_override("font",font)
    label.add_theme_font_size_override("font_size",22)
    label.add_theme_color_override("font_color",Color("e9e9df"))
    label.text = "Loading the encounter…"
    add_child(label)
    var error := ResourceLoader.load_threaded_request(PLAYER)
    if error != OK: _fail(error_string(error))

func _process(_delta: float) -> void:
    var progress: Array = []
    match ResourceLoader.load_threaded_get_status(PLAYER,progress):
        ResourceLoader.THREAD_LOAD_IN_PROGRESS: label.text = "Loading the encounter… %d%%" % int(progress[0]*100)
        ResourceLoader.THREAD_LOAD_LOADED:
            set_process(false)
            get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(PLAYER))
        _: _fail("load failed")

func _fail(reason: String) -> void:
    set_process(false)
    label.text = "Cannot load the player scene (%s): %s" % [PLAYER,reason]
    push_error(label.text)
