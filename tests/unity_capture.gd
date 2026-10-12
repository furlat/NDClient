extends SceneTree
var world: Node
func _initialize() -> void: run.call_deferred()
func settle() -> void:
    while world.view_pending: await process_frame
    for i in range(3):await process_frame
func run() -> void:
    world=load("res://demo.tscn").instantiate()
    root.add_child(world)
    world.set_process_unhandled_input(false)
    world.capturing=true
    await settle()
    await world.save_capture("unity-godot-start")
    world.camera_focus=Vector3(-15+9.5,0,15+9.5)
    world.update_camera(true,true)
    await settle()
    await world.save_capture("unity-godot-stairs-q0")
    for q in range(1,4):
        world.quarter=q
        world.update_camera(true,true)
        await settle()
        await world.save_capture("unity-godot-stairs-q"+str(q))
    print("UNITY_CAPTURE_COMPLETE")
    quit()
