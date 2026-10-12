extends SceneTree
const Profile = preload("res://frame_profile.gd")
const Placement = preload("res://placement.gd")
const Graphs = preload("res://animation/graphs.gd")
var world: Node
var failures = 0
func expect(value: bool, label: String) -> void:
    if not value:failures+=1;push_error(label)
    else:print("OK ",label)
func _initialize() -> void:run.call_deferred()
func key(code: Key, down: bool) -> void:
    var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down
    Input.parse_input_event(event)
    await process_frame
func settled() -> void:
    while world.view_pending:await process_frame
    for i in range(3):await process_frame
func run() -> void:
    world=load("res://demo.tscn").instantiate();root.add_child(world)
    world.capturing=true
    await settled()
    expect(world.find_children("*","Button",true,false).is_empty(),"Exploration contains no editor/menu buttons")
    expect(world.find_children("*","LineEdit",true,false).is_empty(),"Exploration contains no movement-stealing text inputs")
    await key(KEY_G,true);await key(KEY_G,false)
    expect(world.grid_visible,"G enables isometric grid")
    await world.save_capture("exploration-grid")
    await key(KEY_G,true);await key(KEY_G,false)
    for q in range(1,5):
        await key(KEY_E,true);await key(KEY_E,false)
        await settled()
        expect(world.quarter==q%4,"Native E rotates quarter "+str(q%4))
        expect(not world.view_pending,"Quarter change has no static sorting/loading queue")
        expect(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)<200,"Whole map uses fewer than200 native draw calls")
    var chest: Dictionary=world.rows_by_id["unity:878584899:8:5"]
    world.camera_focus=Placement.contact(chest);world.camera.size=8;world.update_camera(false,true)
    await settled()
    await key(KEY_ALT,true)
    expect(world.gpu_grid.views[world.quarter].blocks[0].node.material_override.get_shader_parameter("highlighted")==true,"Static authored breakables receive GPU highlight")
    await world.save_capture("exploration-chest-highlight")
    await key(KEY_ALT,false)
    var clicked=false
    var record=world.Catalog.environment(chest,world.quarter,world.catalog_cache)
    world.texture(record.path)
    var rect: Array=record.rect
    var source: Image=world.source_images[record.path]
    var scale=root.get_visible_rect().size.y/world.camera.size/Placement.PIXELS_PER_UNIT*record.scale
    for y in range(0,int(record.native_size[1]),3):
        for x in range(0,int(record.native_size[0]),3):
            if source.get_pixel(int(rect[0]+x),int(rect[1]+y)).a<0.9:continue
            var point=world.camera.unproject_position(Placement.contact(chest))+(Vector2(x+0.5,y+0.5)-world.v2(record.pivot))*scale
            var hit: Dictionary=world.pick_object(point)
            if hit.get("id","")!=chest.id:continue
            var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=true
            root.push_input(event,true);await process_frame
            event.pressed=false;root.push_input(event,true);await process_frame
            clicked=true;break
        if clicked:break
    expect(clicked and world.destruction.has(chest.id),"Native source-pixel click starts imported chest destruction")
    if world.destruction.has(chest.id):
        var playback: Node=world.destruction[chest.id]
        Graphs.advance(playback,0.3);world.update_environment(chest)
        expect(world.record_for(chest).has("bank"),"Imported break samples existing owner bank")
        await world.save_capture("exploration-chest-breaking")
        Graphs.advance(playback,10);Graphs.advance(playback,0);world.update_environment(chest)
        expect(playback.phase==2,"Native animation settles imported chest")
        await key(KEY_E,true);await key(KEY_E,false)
        expect(world.destruction[chest.id].phase==2,"Quarter change preserves settled destruction")
        await key(KEY_R,true);await key(KEY_R,false)
        expect(not world.destruction.has(chest.id),"Native R restores intact source placement")
        var slot: int=world.gpu_grid.row_slots[chest.id]
        expect(world.gpu_grid.state_image.get_pixel(slot%256,slot/256).r==0,"Reset restores the shared placement state for all four views")
    # After a stopped recording, F9 must include subsequent frames from the
    # rolling history, not reuse the older recorded segment.
    await key(KEY_F8,true);await key(KEY_F8,false)
    for i in range(12):await process_frame
    await key(KEY_F8,true);await key(KEY_F8,false)
    var last_recorded: int=world.profile.recorded.back().frame
    for i in range(8):await process_frame
    var path=Profile.save(world.profile,root,"ring-check",false)
    var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    expect(saved.frames.back().frame>last_recorded,"Recent dump includes frames after stopped recording")
    expect(root.gui_get_focus_owner()==null,"Navigation/overlay clicks leave keyboard focus free")
    print("EXPLORATION_CHECKS failures=",failures)
    quit(1 if failures else 0)
