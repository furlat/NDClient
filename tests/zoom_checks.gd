extends SceneTree
const Catalog = preload("res://source_catalog.gd")
const Workshop = preload("res://main.tscn")
var world: Node
var results: Array = []
var failures = 0
func _initialize() -> void: run.call_deferred()
func wheel(button: int) -> void:
    var event = InputEventMouseButton.new()
    event.button_index = button
    event.position = Vector2(850,600)
    event.pressed = true
    root.push_input(event)
func zoom(target: float, label: String) -> void:
    var started = Time.get_ticks_usec()
    var previous = started
    var outwards: bool = world.camera.size < target
    for i in range(40):
        if (outwards and world.camera.size >= target) or (not outwards and world.camera.size <= target): break
        wheel(MOUSE_BUTTON_WHEEL_DOWN if outwards else MOUSE_BUTTON_WHEEL_UP)
    var input_ms = (Time.get_ticks_usec()-started)/1000.0
    var frames: Array[float] = []
    var updates: Array[float] = []
    for i in range(1000):
        await process_frame
        var now = Time.get_ticks_usec()
        frames.append((now-previous)/1000.0)
        previous = now
        updates.append(world.view_update_ms)
        if i>30 and not world.view_pending: break
    var elapsed_ms = (Time.get_ticks_usec()-started)/1000.0
    frames.sort()
    updates.sort()
    var result = {"case":label,"elapsed_ms":elapsed_ms,"zoom":world.camera.size,"input_ms":input_ms,"max_frame_ms":frames.back(),"median_ms":frames[frames.size()/2],"max_view_ms":updates.back(),"frames":frames.size(),"draws":world.draw_order.size(),"pending":world.pending_rows}
    results.append(result)
    print("ZOOM_RESULT ",JSON.stringify(result))
    if world.view_pending or not world.unresolved.is_empty() or input_ms>100 or frames.back()>250:
        failures += 1
        push_error("Zoom must remain responsive: "+label)
func run() -> void:
    world = Workshop.instantiate()
    root.add_child(world)
    for i in range(20): await process_frame
    await zoom(50,"cold-out")
    await zoom(12,"back-in")
    await zoom(50,"warm-out")
    world.player.base_height_steps = -2
    world.update_actor_frames()
    world.compose()
    await zoom(12,"underground-in")
    await zoom(50,"underground-out")
    var event = InputEventKey.new()
    event.physical_keycode = KEY_ALT
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    if not world.entries.any(func(e): return e.material.get_shader_parameter("highlighted")==true):
        failures += 1; push_error("Alt remains usable after zoom")
    event.pressed = false
    Input.parse_input_event(event)
    await process_frame
    var breakable = world.loaded_rows.values().filter(func(row): return Catalog.break_duration(row,world.catalog_cache)>0)
    if breakable.is_empty() or not world.break_object(breakable[0]):
        failures += 1; push_error("Break preview remains usable after zoom")
    await world.save_capture("zoom-performance")
    var file = FileAccess.open("res://generated/zoom_performance.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(results,"  "))
    print("ZOOM_CHECKS ",failures," failures")
    quit(1 if failures else 0)
