extends SceneTree
const MapData = preload("res://map_data.gd")
var world: Node
var failures = 0
var checks = 0
func expect(value: bool, label: String) -> void:
    checks += 1
    if not value: failures += 1; push_error(label)
func key(code: Key, pressed: bool) -> void:
    var event = InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)
    await process_frame
func click(point: Vector2) -> void:
    var motion = InputEventMouseMotion.new()
    motion.position = point
    root.push_input(motion, true)
    var event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = point
    event.pressed = true
    root.push_input(event, true)
    await process_frame
    event.pressed = false
    root.push_input(event, true)
    await process_frame
func move_frames(code: Key, count: int) -> void:
    await key(code,true)
    for i in range(count): await process_frame
    await key(code,false)
func run() -> void:
    world = load("res://main.tscn").instantiate()
    root.add_child(world)
    await process_frame
    # First terrace's actual catalog stair, including the authored lower and
    # upper contacts. Native WASD must cross the height changes in both ways.
    world.player.position = [5.0,0.0]
    world.player.base_height_steps = 0
    world.player.support_id = "road_0_5_0"
    world.camera_focus = Vector3(3,1,0)
    world.update_camera()
    await key(KEY_A,true)
    for i in range(800):
        await process_frame
        if world.player.position[0] < 1.8: break
    await key(KEY_A,false)
    expect(world.player.position[0] < 1.8 and is_equal_approx(world.player.base_height_steps,2),"WASD climbs actual catalog stairs onto terrace")
    await world.save_capture("stairs-top")
    await key(KEY_D,true)
    for i in range(800):
        await process_frame
        if world.player.position[0] > 4.8: break
    await key(KEY_D,false)
    expect(world.player.position[0] > 4.8 and is_zero_approx(world.player.base_height_steps),"WASD descends actual catalog stairs to road")
    world.player.position = [4.0,0.0]
    world.player.base_height_steps = 0
    var search: LineEdit
    for field in world.find_children("*","LineEdit",true,false):
        if field.is_visible_in_tree() and field.placeholder_text.begins_with("Search all environment"): search = field; break
    await click(search.get_global_rect().get_center())
    expect(root.gui_get_focus_owner()==search,"Click focuses search")
    var before = Vector2(world.player.position[0],world.player.position[1])
    await move_frames(KEY_D,10)
    expect(before==Vector2(world.player.position[0],world.player.position[1]),"Typing in search does not walk")
    await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
    await move_frames(KEY_D,10)
    expect(world.player.position[0]>before.x,"Escape restores walking after search")
    await click(world.height_control.get_line_edit().get_global_rect().get_center())
    expect(root.gui_get_focus_owner()==world.height_control.get_line_edit(),"Click focuses height editor")
    before = Vector2(world.player.position[0],world.player.position[1])
    await click(Vector2(880,650))
    await move_frames(KEY_D,10)
    expect(world.player.position[0]>before.x,"World click restores walking after height edit")
    await click(search.get_global_rect().get_center())
    await key(KEY_ENTER,true); await key(KEY_ENTER,false)
    expect(root.gui_get_focus_owner()!=search,"Enter completes search edit")
    var button: Button
    for control in world.find_children("*","Button",true,false):
        if control.text=="Select": button=control; break
    await click(button.get_global_rect().get_center())
    before = Vector2(world.player.position[0],world.player.position[1])
    await move_frames(KEY_D,10)
    expect(world.player.position[0]>before.x,"Menu button selection preserves walking")
    await click(world.orientation_control.get_global_rect().get_center())
    var popup: PopupMenu = world.orientation_control.get_popup()
    expect(popup.visible,"Click opens orientation menu")
    await click(Vector2(popup.position)+Vector2(30,popup.size.y*1.5/popup.item_count))
    expect(not popup.visible and world.orientation_control.selected==1,"Click selects north and closes menu")
    before = Vector2(world.player.position[0],world.player.position[1])
    await move_frames(KEY_D,10)
    expect(world.player.position[0]>before.x,"Dropdown selection preserves walking")
    world.player.position = [3.0,0.0]
    world.player.base_height_steps = 1
    world.player.support_id = "stairs_0"
    for q in range(4):
        world.quarter = q
        world.update_camera()
        await world.save_capture("stairs-middle-q"+str(q))
    print("INPUT_WALKING_CHECKS ",checks," checks; ",failures," failures")
    quit(1 if failures else 0)
func _initialize() -> void: run.call_deferred()
