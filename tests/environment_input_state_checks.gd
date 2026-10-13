extends SceneTree
# Source/material boundary only: original wall registration, no rendered-pixel
# claim. A tiny texture stands in for already-prepared source image uploads.
const Sources = preload("res://presentation/sprite_sources.gd")
const Workshop = preload("res://main.gd")
const Catalog = preload("res://source_catalog.gd")
class PreparedSources extends Sources:
    var prepared_texture: Texture2D
    func texture(_path: String) -> Texture2D:
        return prepared_texture
class WorkshopSources extends Workshop:
    var prepared_texture: Texture2D
    func _ready() -> void: set_process(false)
    func texture(_path: String) -> Texture2D: return prepared_texture
    func update_status() -> void: pass # No HUD in the material-boundary fixture.

var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("ENVIRONMENT_INPUT_STATE_FAIL ",label)
func alt(pressed: bool) -> void:
    var event = InputEventKey.new()
    event.keycode = KEY_ALT
    event.physical_keycode = KEY_ALT
    event.pressed = pressed
    event.alt_pressed = pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    check(Input.is_physical_key_pressed(KEY_ALT)==pressed,"Test process observes physical Alt state")
func neutral(entries: Array) -> bool:
    return entries.all(func(entry):return not bool(entry.material.get_shader_parameter("highlighted")))
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var scene = PreparedSources.new()
    scene.prepared_texture = ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
    scene.camera = Camera3D.new(); scene.add_child(scene.camera); root.add_child(scene)
    var authored = JSON.parse_string(FileAccess.get_file_as_string("res://scenes.json"))
    var wall: Dictionary = authored.scenes[0].placements.filter(func(row):return row.kind=="wall")[0].duplicate(true)
    check(Catalog.break_duration(wall,scene.catalog_cache)>0,"Original authored wall is breakable and exercised the old Alt branch")
    var retained: Array = []
    for quarter in 4:
        scene.quarter = quarter
        var parent = Node3D.new(); scene.add_child(parent); parent.hide(); scene.sprite_parent = parent
        scene.entries = []
        alt(true)
        scene.add_environment_entries(wall)
        for entry in scene.entries: scene.initialize_entry(entry)
        check(neutral(scene.entries),"q%d private preparation while Alt is down remains neutral" % quarter)
        var identities = scene.entries.map(func(entry):return entry.material.get_instance_id())
        alt(false)
        parent.show()
        check(neutral(scene.entries),"q%d retained prepared view stays neutral after Alt release/adoption" % quarter)
        check(identities==scene.entries.map(func(entry):return entry.material.get_instance_id()),"q%d adoption reused the prepared material owners" % quarter)
        alt(true)
        for entry in scene.entries:
            entry.material.set_shader_parameter("highlighted",true)
            scene.set_environment(entry,Basis(Vector3.UP,quarter*PI*.5))
        check(neutral(scene.entries),"q%d source rebuild clears stale external highlight even while Alt is down" % quarter)
        retained.append_array(scene.entries)
        alt(false)
    var workshop = Workshop.new()
    workshop.entries = retained
    workshop.catalog_cache = scene.catalog_cache
    alt(true); workshop.update_highlight()
    check(retained.all(func(entry):return bool(entry.material.get_shader_parameter("highlighted"))),"Workshop's explicit Alt owner still highlights breakable wall sources")
    alt(false); workshop.update_highlight()
    check(neutral(retained),"Workshop's explicit release still clears highlights")
    workshop.entries = []; workshop.free()
    var camera_workshop = WorkshopSources.new()
    camera_workshop.prepared_texture = scene.prepared_texture
    camera_workshop.catalog_cache = scene.catalog_cache
    camera_workshop.camera = Camera3D.new(); camera_workshop.camera.size = 10
    camera_workshop.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera_workshop.add_child(camera_workshop.camera); root.add_child(camera_workshop)
    for quarter in 4: camera_workshop.placement_buckets[quarter][Vector2i.ZERO] = [wall]
    alt(true)
    for quarter in 4:
        camera_workshop.quarter = quarter
        camera_workshop.update_camera()
        check(not camera_workshop.entries.is_empty(),"Workshop q%d camera retains the authored wall" % quarter)
        check(camera_workshop.entries.all(func(entry):return bool(entry.material.get_shader_parameter("highlighted"))),"Workshop q%d camera rebuild preserves held-Alt highlighting" % quarter)
    alt(false)
    camera_workshop.update_camera()
    check(neutral(camera_workshop.entries),"Workshop camera rebuild observes released Alt")
    camera_workshop.free(); scene.free()
    var report = {"checks":checks,"failures":failures,"scope":"Headless original-wall material state in all four quarters: held Alt during private preparation, retained adoption, source rebuild, explicit workshop Alt/release and workshop camera rebuild while held. No pixel or live input/render claim."}
    FileAccess.open("res://generated/environment_input_state_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ENVIRONMENT_INPUT_STATE ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
