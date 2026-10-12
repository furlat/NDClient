extends SceneTree
const Profile = preload("res://frame_profile.gd")
var world: Node
func _initialize() -> void: run.call_deferred()
func sample(label: String, count: int) -> void:
    for i in range(3):await process_frame
    world.profile.recorded.clear()
    world.profile.recording=true
    for i in range(count):await process_frame
    world.profile.recording=false
    Profile.save(world.profile,root,label)
func run() -> void:
    world=load("res://demo.tscn").instantiate()
    root.add_child(world)
    world.set_process_unhandled_input(false)
    world.capturing=true
    while world.view_pending:await process_frame
    for i in range(90):await process_frame
    await sample("unity-close-idle",120)
    world.profile.recorded.clear();world.profile.recording=true
    world.camera.size=50
    world.update_camera(false,true)
    while world.view_pending:await process_frame
    for i in range(60):await process_frame
    world.profile.recording=false
    Profile.save(world.profile,root,"unity-zoom-loading")
    await sample("unity-wide-idle",120)
    world.capturing=false
    var key=InputEventKey.new();key.physical_keycode=KEY_D;key.pressed=true
    world.profile.recorded.clear();world.profile.recording=true
    Input.parse_input_event(key)
    for i in range(60):await process_frame
    world.profile.recording=false
    Profile.save(world.profile,root,"unity-first-walk")
    await sample("unity-wide-walking",240)
    world.follow_player=true
    await sample("unity-wide-follow-walking",240)
    key.pressed=false;Input.parse_input_event(key)
    world.follow_player=false;world.capturing=true
    world.profile.recorded.clear();world.profile.recording=true
    world.quarter=2;world.update_camera(true,true)
    while world.view_pending:await process_frame
    for i in range(60):await process_frame
    world.profile.recording=false
    Profile.save(world.profile,root,"unity-wide-rotation-loading")
    quit()
