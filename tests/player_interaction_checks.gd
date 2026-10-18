extends "res://tests/player_live_checks.gd"
const ViewPublication=preload("res://tests/view_publication.gd")
# Real Crypt choices and rendered clicks; no injected actor/object state.
const Interaction = preload("res://presentation/interaction.gd")
const UI = preload("res://presentation/ui_catalog.gd")

func capture(name: String, value: Variant) -> void:
    var file = FileAccess.open(scene.game_config.test_result.get_base_dir().path_join(name+".json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(value,"  ")); file.close()

func click_at(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
    var event = InputEventMouseButton.new()
    event.position = point; event.global_position = point
    event.button_index = button; event.pressed = true
    root.push_input(event,true)
    event = event.duplicate(); event.pressed = false
    root.push_input(event,true)

func key(code: int, pressed: bool = true) -> void:
    var event = InputEventKey.new()
    event.keycode = code; event.physical_keycode = code; event.pressed = pressed
    root.push_input(event,true)

func screen_pixel(id: String) -> Vector2:
    for rotation in range(4):
        for entry in scene.draw_order:
            if entry.placement.id != id or entry.role == "shadow": continue
            var mesh: QuadMesh = entry.node.mesh
            for y in range(2,30):
                for x in range(2,30):
                    var local = Vector3((float(x)/32-.5)*mesh.size.x,(.5-float(y)/32)*mesh.size.y,0)+mesh.center_offset
                    var screen: Vector2 = scene.camera.unproject_position(entry.node.global_transform*local)
                    if root.get_visible_rect().has_point(screen) and not scene.hud.pointer_over_controls(screen) and scene.pick_world(screen).get("id")==id: return screen
        check(await ViewPublication.finish(scene,posmod(scene.quarter+1,4)),"Requested camera quarter publishes")
    return Vector2.INF

func _run() -> void:
    scene = Player.instantiate(); root.add_child(scene)
    if not await until(ready,"Native contextual choices received"): await finish(); return
    evidence.ready_frame = Engine.get_process_frames()
    capture("discovery",scene.available_actions); capture("state",scene.timeline.state)
    var command: int = scene.session.status.next_command_number
    # GUI focus cannot latch force attack; releasing Ctrl in search must clear it.
    key(KEY_CTRL)
    scene.hud.toggle_inventory()
    scene.hud.search.grab_focus()
    key(KEY_CTRL,false)
    check(not scene.force_attack,"Ctrl released in focused search disarms forced attack")
    key(KEY_Q)
    key(KEY_SPACE)
    check(scene.session.status.next_command_number==command,"Typing shortcuts in search does not spend")
    key(KEY_ESCAPE)
    if not await until(ready,"Fresh non-forced choices after GUI focus transfer"): await finish(); return
    # Equip/unequip uses HUD controls and waits for authoritative after-values.
    var actor: String = scene.available_actions.entity_uuid
    var equipped: Dictionary = UI.equipped(scene.timeline.state.actors[actor])
    if equipped.has("MELEE_MAIN"):
        var item: String = equipped.MELEE_MAIN.item_uuid
        scene.inventory_intent({"kind":"unequip","item":{"slot":"MELEE_MAIN"}})
        if not await until(func():return ready() and not UI.equipped(scene.timeline.state.actors[actor]).has("MELEE_MAIN"),"Unequip appears only after native publication"): await finish(); return
        scene.inventory_intent({"kind":"equip","item":{"item_uuid":item,"slot":"MELEE_MAIN"}})
        if not await until(func():return ready() and UI.equipped(scene.timeline.state.actors[actor]).get("MELEE_MAIN",{}).get("item_uuid")==item,"Equip restores exact item through native command"): await finish(); return
    else: check(false,"Crypt controlled actor has equipped melee weapon")
    var option = {}
    for candidate in scene.available_actions.world_interactions:
        var object: Dictionary = scene.timeline.state.objects.get(candidate.subject_uuid,{})
        if object.is_empty() or object.item.get("is_open") != false or object.item.get("door_mechanism") == null: continue
        if not candidate.behavior_id.contains("open"): continue
        if Interaction.admitted(scene.available_actions,candidate).is_empty() and not Interaction.approach(scene.available_actions,candidate).is_empty(): option = candidate; break
    check(not option.is_empty(),"Crypt offers a distant closed door with an affordable native approach")
    if option.is_empty(): capture("no-door-choices",scene.available_actions); await finish(); return
    var id: String = option.subject_uuid
    var pixel = await screen_pixel(id)
    check(pixel != Vector2.INF,"Door has a visible authored pixel in a camera view")
    if pixel == Vector2.INF: await finish(); return
    command = scene.session.status.next_command_number
    click_at(pixel,MOUSE_BUTTON_RIGHT)
    check(scene.context_menu.visible,"Right click opens door alternatives without spending")
    check(scene.session.status.next_command_number==command,"Context menu alone submits no command")
    scene.context_menu.hide()
    click_at(pixel)
    check(not scene.pending_approach.is_empty(),"Viewport door click starts an exact native approach")
    if not await until(func():return ready() and scene.timeline.state.objects.get(id,{}).get("item",{}).get("is_open")==true,"Distant door approaches then opens after rediscovery"): await finish(); return
    check(scene.session.status.next_command_number==command+2,"Approach and open issue exactly two commands")
    var close_options = Interaction.world_options(scene.available_actions,id)
    capture("after-open-state",scene.timeline.state)
    capture("after-open-discovery",scene.available_actions)
    if close_options.is_empty():
        var door_position: Array = scene.timeline.state.objects[id].placement.position
        var standing: Array = scene.timeline.state.actors[actor].last_visual_position
        check(standing==door_position,"Native Close is withheld while actor occupies doorway")
        # Walk through the open boundary to its other incident support. Moving
        # sideways would require approaching again and reoccupy the doorway.
        var side: String = scene.timeline.state.objects[id].placement.boundary_direction
        var offset: Array = {"north":[0,1],"south":[0,-1],"east":[1,0],"west":[-1,0]}[side]
        var across: Array = [door_position[0]+offset[0],door_position[1]+offset[1]]
        var step = {}
        for row in scene.available_actions.get("position_actions",[]):
            if row.behavior_id != "action.move" or not row.can_afford: continue
            for target in Choices.action_options(scene.available_actions,row):
                var position: Variant = Choices.binding_position(scene.available_actions,target)
                if position == null or Interaction.same_position(position,standing): continue
                if Interaction.same_position(position,across): step = {"action":row,"target":target,"position":position}; break
            if not step.is_empty(): break
        check(not step.is_empty(),"Native movement offers a step clear of doorway")
        if step.is_empty(): await finish(); return
        command = scene.session.status.next_command_number
        scene.choose_target(step.position)
        if not await until(func():return ready() and scene.session.status.next_command_number>command,"Native actor clears doorway"): await finish(); return
        close_options = Interaction.world_options(scene.available_actions,id)
    check(close_options.any(func(value):return value.behavior_id.contains("close")),"Native door state offers Close after Open")
    if close_options.is_empty(): await finish(); return
    pixel = await screen_pixel(id)
    if pixel != Vector2.INF:
        click_at(pixel)
        if not await until(func():return ready() and scene.timeline.state.objects[id].item.is_open==false,"Second viewport door click closes it"): await finish(); return
    else: check(false,"Open door remains pixel selectable")
    evidence.door = {"id":id,"approach_and_open_commands":2,"closed":scene.timeline.state.objects[id].item.is_open==false}
    evidence.light_sources = scene.source_lighting.sources.size()
    check(scene.source_lighting.sources.size()>0,"Crypt has disclosed active GPU light sources")
    await process_frame
    await process_frame
    var dodge_button: Button
    for button in scene.hud.action_buttons:
        if button.get_meta("native_row").behavior_id == "action.dodge": dodge_button = button; break
    check(dodge_button != null,"Grouped authored icon bar contains native Dodge")
    evidence.painted_actions = scene.hud.action_buttons.map(func(button):return button.get_meta("native_row").behavior_id)
    if dodge_button != null:
        command = scene.session.status.next_command_number
        click_at(dodge_button.get_global_rect().get_center())
        if not await until(func():return ready() and scene.session.status.next_command_number>command,"Dodge icon executes its native self action"): await finish(); return
        var receipt = await request("receipt",{"number":command})
        if receipt.ok: check(receipt.value.receipt.kind=="committed","Dodge icon has committed receipt")
    scene.hud.toggle_inventory()
    await scene.presentation_updated
    check(scene.hud.inventory_buttons.size()==scene.timeline.state.actors[actor].controlled_items.size(),"Live searchable bag matches exact disclosed carried collection")
    scene.hud.search.text = "dagger"
    scene.hud.search.text_changed.emit("dagger")
    check(scene.hud.inventory_buttons.size()>0,"Live inventory search finds authored Dagger")
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(scene.game_config.test_result.get_base_dir().path_join("inventory.png"))
    scene.hud.toggle_inventory()
    # Keep finish's common cold-replay and actual movement-fact checks.
    capture("final-discovery",scene.available_actions)
    await finish()
