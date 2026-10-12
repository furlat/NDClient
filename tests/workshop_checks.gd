extends SceneTree
const Graphs = preload("res://animation/graphs.gd")
const Placement = preload("res://placement.gd")
var failures = 0
var checks = 0
var world: Node
func expect(value: bool, label: String) -> void:
    checks += 1
    if not value: failures += 1; push_error(label)
func _initialize() -> void: run.call_deferred()
func click(point: Vector2) -> void:
    var event = InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = point
    event.pressed = true
    root.push_input(event)
    await process_frame
    event.pressed = false
    root.push_input(event)
    await process_frame
func key(code: Key, down: bool) -> void:
    var event = InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = down
    Input.parse_input_event(event)
    await process_frame
func target(id: String) -> Dictionary:
    world.palette_id = id
    world.locate_palette()
    return world.rows_by_id[world.selected_id]
func visible_point(identity: String) -> Vector2:
    # Find a visible source-colour pixel in the viewport's usable centre.
    for entry in world.draw_order:
        if entry.placement.id != identity or entry.role == "shadow" or entry.source_role==2: continue
        var record: Dictionary = entry.record
        var rect: Array = record.get("rect",[0,0,entry.cell.x,entry.cell.y])
        var image: Image = world.source_images[record.path]
        for y in range(int(entry.cell.y/2),int(entry.cell.y)):
            for x in range(int(entry.cell.x/4),int(entry.cell.x*3/4)):
                if image.get_pixel(int(rect[0]+x),int(rect[1]+y)).a<0.9: continue
                if record.has("hit_mask"):
                    var mask: Dictionary=record.hit_mask
                    if world.source_images[mask.path].get_pixel(int(mask.rect[0]+x),int(mask.rect[1]+y)).r<0.5: continue
                var scale = root.get_visible_rect().size.y/world.camera.size/Placement.PIXELS_PER_UNIT*entry.scale
                var point = world.camera.unproject_position(entry.node.position)+(Vector2(x+0.5,y+0.5)-entry.pivot)*scale
                if point.x>900 or point.y<270: continue
                return point
    return Vector2(-1,-1)
func run() -> void:
    world = load("res://main.tscn").instantiate()
    world.capturing = true
    root.add_child(world)
    await process_frame
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures"))
    var crate = target("environment.blocker.crate")
    await key(KEY_ALT,true)
    expect(world.entries.any(func(e): return e.placement.id==crate.id and e.material.get_shader_parameter("highlighted")==true),"Alt highlights authored breakable")
    await world.save_capture("acceptance-alt-highlight")
    await key(KEY_ALT,false)
    var point = visible_point(crate.id)
    expect(point.x>=0,"Crate has visible clickable source pixels")
    await click(point)
    expect(world.destruction.has(crate.id),"Viewport click starts crate destruction")
    if world.destruction.has(crate.id):
        var playback: Node = world.destruction[crate.id]
        Graphs.advance(playback,0.5)
        world.update_environment(crate)
        var before = world.record_for(crate).frame
        world.quarter = 2; world.update_camera()
        expect(world.record_for(crate).frame==before,"Camera turn keeps destruction sample time")
        await world.save_capture("acceptance-crate-mid-rotated")
    world.reset_destruction()
    var wall = target("environment.window.fantasy_g8.wall")
    var insert: Dictionary = world.rows_by_id[wall.id+"_insert"]
    world.preview_mode = true
    await click(visible_point(insert.id))
    expect(world.destruction.has(insert.id),"Window aperture click breaks its insert independently")
    expect(not world.destruction.has(wall.id),"Insert click leaves parent intact")
    if world.destruction.has(insert.id):
        Graphs.advance(world.destruction[insert.id],10.0); Graphs.advance(world.destruction[insert.id],0.0)
        world.update_environment(insert)
    await world.save_capture("acceptance-window-insert-broken")
    await click(visible_point(wall.id))
    expect(world.destruction.has(wall.id),"Wall click starts parent destruction")
    expect(world.record_for(wall).get("bank","").ends_with("after_insert"),"Parent uses authored after-insert destruction")
    expect(world.record_for(insert).get("hidden",false),"Parent animation omits incorporated insert")
    world.reset_destruction()
    # Exercise real modular frames with several equipment/effect layers.
    world.load_scene(0)
    world.camera.size = 4.5
    world.player.position=[-1,1]
    world.camera_focus=Placement.contact(world.player)+Vector3(0,0.7,0)
    world.equipment_choices={"body_armor":"Plate Armor","weapon":"Flaming Scimitar","offhand":"Shield","helmet":"Iron Helmet"}
    world.effect_choices={"effect":"Effect1","effect2":"Magic1","effect3":"Magic2"}
    world.refresh_modular()
    var actor: Node=world.playbacks[world.player.id]
    Graphs.request(actor,"Attack1"); Graphs.advance(actor,0.5)
    world.update_actor_frames()
    for q in range(4):
        world.quarter=q
        world.update_camera()
        expect(actor.clip=="Attack1" and absf(actor.sample_seconds-0.5)<0.001,"Actor camera q%s preserves action time"%q)
        for facing in world.rig_config.FACING_CYCLE:
            world.player.facing=facing
            world.update_actor_frames()
            var uv_x=-1.0
            for entry in world.entries:
                if entry.placement.id!=world.player.id or not entry.node.visible: continue
                var uv: Vector4=entry.material.get_shader_parameter("frame_uv")
                if uv_x<0: uv_x=uv.x
                expect(is_equal_approx(uv.x,uv_x),"Modular layers share frame q%s facing%s"%[q,facing])
                expect(entry in world.draw_order,"Visible effect participates in composition")
        await world.save_capture("acceptance-modular-attack-q"+str(q))
    Graphs.advance(actor,0.8); Graphs.advance(actor,0.01); world.update_actor_frames()
    expect(actor.clip=="Idle","Attack returns through Idle")
    await world.save_capture("acceptance-modular-idle")
    # Editor gestures place, move, elevate, rotate, remove and undo real data.
    world.preview_mode=false;world.editor_tool="place"
    world.palette_id="environment.blocker.crate"
    world.configure_source_choices({"kind":"prop","asset":world.palette_id})
    world.height_control.value=2
    var total=world.placements.size()
    await click(Vector2(900,600))
    expect(world.placements.size()==total+1,"Place gesture adds one crate")
    var placed=world.selected_id
    var original: Array=world.rows_by_id[placed].position.duplicate()
    world.editor_tool="move"
    await click(Vector2(500,700))
    expect(world.rows_by_id[placed].position!=original,"Move gesture changes cell")
    world.height_control.value=32
    world.orientation_control.select(2)
    world.transform_selected()
    world.camera_focus=Placement.contact(world.rows_by_id[placed]);world.update_camera()
    expect(world.loaded_rows.has(placed),"Height32 remains active when in view")
    expect(world.rows_by_id[placed].orientation=="west","Editor turn persists")
    world.delete_selected()
    expect(not world.rows_by_id.has(placed),"Delete removes placement")
    world.undo_edit()
    expect(world.rows_by_id.has(placed),"Undo restores deleted placement")
    var saved_path=ProjectSettings.globalize_path("user://workshop-map.json")
    var prior=FileAccess.get_file_as_bytes(saved_path) if FileAccess.file_exists(saved_path) else PackedByteArray()
    world.save_map()
    var saved_equipment: Array=world.player.equipment.duplicate()
    world.equipment_choices.body_armor="Leather Armor"
    world.refresh_modular()
    world.load_map()
    expect(world.rows_by_id.has(placed) and world.rows_by_id[placed].base_height_steps==32,"Saved map reloads transformed placement")
    expect(world.player.equipment==saved_equipment,"Load restores saved modular equipment")
    world.undo_history.append({"before":null,"after":{"id":"unrelated"}})
    world.load_scene(0)
    expect(world.undo_history.is_empty() and world.selected_id.is_empty(),"Changing maps clears stale selection and undo")
    if prior.is_empty(): DirAccess.remove_absolute(saved_path)
    else:
        var file=FileAccess.open(saved_path,FileAccess.WRITE);file.store_buffer(prior)
    print("WORKSHOP_CHECKS ",checks," checks; ",failures," failures")
    quit(1 if failures else 0)
