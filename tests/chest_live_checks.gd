extends "res://tests/player_interaction_checks.gd"
func picture(name: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(scene.game_config.test_result.get_base_dir().path_join(name+".png"))

func chest_rows(id: String) -> Array:
    var result: Array = []
    for entry in scene.static_entries:
        if entry.placement.id == id:
            result.append({"state":entry.placement.state,"role":entry.role,"record":entry.record,"position":str(entry.node.position),"rect":str(entry.node.mesh.size)})
    return result

func _run() -> void:
    scene = Player.instantiate(); root.add_child(scene)
    if not await until(ready,"Native chest choices received"): await finish(); return
    evidence.ready_frame = Engine.get_process_frames()
    var option = {}
    for candidate in scene.available_actions.world_interactions:
        if candidate.behavior_id=="action.environment.storage_chest.open": option=candidate; break
    check(not option.is_empty(),"Actual Crypt offers authored storage chest")
    if option.is_empty(): await finish(); return
    var id: String = option.subject_uuid
    var pixel = await screen_pixel(id)
    check(pixel != Vector2.INF,"Closed chest has selectable sprite pixels")
    if pixel == Vector2.INF: await finish(); return
    var closed = chest_rows(id)
    capture("closed-chest",closed)
    await picture("chest-closed")
    click_at(pixel)
    if not await until(func():return ready() and scene.timeline.state.objects[id].item.is_open==true,"Viewport chest click approaches and opens natively"): await finish(); return
    var opened = chest_rows(id)
    capture("opened-chest",opened)
    check(closed.map(func(row):return row.record.path) != opened.map(func(row):return row.record.path),"Open chest selects distinct authored source bank")
    await picture("chest-open")
    pixel = await screen_pixel(id)
    check(pixel != Vector2.INF,"Open chest keeps selectable authored pixels")
    if pixel==Vector2.INF: await finish(); return
    click_at(pixel,MOUSE_BUTTON_RIGHT)
    var index = -1
    for i in range(scene.context_options.size()):
        if scene.context_options[i].get("behavior_id")=="action.environment.storage_chest.close": index=i; break
    check(index>=0,"Context menu offers exact native Close Chest alongside loot")
    if index<0: await finish(); return
    scene.context_menu.id_pressed.emit(index)
    if not await until(func():return ready() and scene.timeline.state.objects[id].item.is_open==false,"Context Close restores authoritative closed chest"): await finish(); return
    var restored = chest_rows(id)
    check(closed.map(func(row):return row.record.path)==restored.map(func(row):return row.record.path),"Closed chest restores original authored source bank")
    evidence.chest = {"id":id,"closed":closed,"opened":opened,"restored":restored}
    await finish()
