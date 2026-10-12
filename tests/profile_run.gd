extends SceneTree
const FrameProfile = preload("res://frame_profile.gd")
var world: Node
func _initialize() -> void: run.call_deferred()
func sample(label: String, count: int) -> void:
    await process_frame
    world.profile.recorded.clear()
    world.profile.label=label
    world.profile.recording=true
    for i in range(count): await process_frame
    world.profile.recording=false
    FrameProfile.save(world.profile,root,label)
func run() -> void:
    world=load("res://main.tscn").instantiate()
    root.add_child(world)
    world.set_process_unhandled_input(false)
    for i in range(20): await process_frame
    world.camera.size=50
    world.view_pending=true
    world.profile.label="wide-loading"
    world.profile.recorded.clear()
    world.profile.recording=true
    while world.view_pending: await process_frame
    world.profile.recording=false
    FrameProfile.save(world.profile,root,"wide-loading")
    await sample("wide-idle",120)
    var key=InputEventKey.new()
    key.physical_keycode=KEY_D
    key.pressed=true
    Input.parse_input_event(key)
    await sample("wide-walking",120)
    key.pressed=false
    Input.parse_input_event(key)
    print("PROFILE_RUN_COMPLETE")
    quit()
