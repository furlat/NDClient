extends SceneTree
const Workshop = preload("res://main.tscn")
var world: Node
var results: Array = []
func _initialize() -> void: run.call_deferred()
func measure(label: String, load_ms: float) -> void:
    for i in range(30): await process_frame
    var times: Array[float] = []
    var previous = Time.get_ticks_usec()
    for i in range(120):
        await process_frame
        var now = Time.get_ticks_usec()
        times.append((now-previous)/1000.0)
        previous=now
    times.sort()
    var mean=0.0
    for time in times: mean+=time/times.size()
    var result={"case":label,"placements":world.placements.size(),"visible_draws":world.draw_order.size(),
        "load_ms":load_ms,"mean_frame_ms":mean,"median_frame_ms":times[60],"p95_frame_ms":times[114],
        "textures":world.textures.size(),"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,
        "video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}
    results.append(result)
    print("BENCHMARK ",JSON.stringify(result))
func run() -> void:
    var start=Time.get_ticks_usec()
    world=Workshop.instantiate()
    root.add_child(world)
    await measure("1x catalog idle",(Time.get_ticks_usec()-start)/1000.0)
    for copies in [2,4]:
        start=Time.get_ticks_usec()
        world.resize_catalog(copies)
        await measure(str(copies)+"x catalog idle",(Time.get_ticks_usec()-start)/1000.0)
    world.palette_id="environment.blocker.crate";world.locate_palette();world.bring_character()
    var event=InputEventKey.new();event.physical_keycode=KEY_D;event.pressed=true;Input.parse_input_event(event)
    await measure("4x character walking",0)
    event.pressed=false;Input.parse_input_event(event)
    start=Time.get_ticks_usec()
    world.palette_id="library/generated-timber-stair-flight";world.locate_palette()
    var elapsed=(Time.get_ticks_usec()-start)/1000.0
    world.break_object(world.rows_by_id[world.selected_id])
    await measure("4x distant timber preview",elapsed)
    var file=FileAccess.open("res://generated/performance.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"godot":Engine.get_version_info().string,"renderer":"Compatibility","resolution":[1440,900],"source":"WSL UNC original JSON/PNG","results":results},"  "))
    quit()
