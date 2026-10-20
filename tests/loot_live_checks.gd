extends "res://tests/player_interaction_checks.gd"
# Real five-item authored cache. Commands go through native viewport/UI handlers.
# Frozen 211b battlefield_catalog._create_cache defines these exact five kinds.
const CACHE_ITEM_IDS=["spell_item.scroll_fireball","spell_item.scroll_magic_missile",
    "consumable.acid_flask","consumable.healing_potion","consumable.weapon_coat.fire"]

func contents(id: String) -> Variant:
    return scene.timeline.state.get("objects",{}).get(id,{}).get("contained_items")

func inventory(actor: String) -> Dictionary:
    var result = {}
    # Canonical controlled inventory is UUID membership; item values have one
    # owner in state.items. Container entries remain canonical joined views.
    for identity in scene.timeline.state.actors[actor].controlled_items:
        result[identity] = scene.timeline.state.items[identity]
    return result

func committed(number: int, label: String) -> void:
    var receipt = await request("receipt",{"number":number})
    if not receipt.ok:return
    var value:Dictionary=receipt.value.receipt
    check(value.kind=="committed" and value.command_number==number,label+" has its exact committed native command receipt")
    if value.kind!="committed":return
    check(value.cursor.game_id==scene.session.journal.cursor.game_id and value.cursor.game_epoch==scene.session.journal.cursor.game_epoch \
        and value.cursor.audience_id==scene.session.journal.cursor.audience_id,label+" receipt belongs to the actual current game/seat")
    check(scene.timeline.sequence>=int(value.cursor.sequence),label+" displayed authoritative cursor includes its command receipt")
    if not evidence.has("loot_receipts"):evidence.loot_receipts=[]
    evidence.loot_receipts.append({"label":label,"command_number":number,"cursor":value.cursor})

func _run() -> void:
    scene = Player.instantiate(); root.add_child(scene)
    if not await until(ready,"Authored cache receives native choices"): await finish(); return
    var actor: String = scene.available_actions.entity_uuid
    var id = ""
    for identity in scene.timeline.state.objects:
        if scene.timeline.state.objects[identity].item.name == "Validation Field Cache": id = identity; break
    check(not id.is_empty(),"Existing field-cache fixture is disclosed")
    if id.is_empty(): await finish(); return
    check(scene.timeline.state.objects[id].item.is_open==false and contents(id)==null,"Never-opened closed storage has unknown contents, not an invented empty list")
    check(scene.timeline.state.actors[actor].controlled_items!=null,"Current controlled actor discloses UUID inventory membership")
    var initial = inventory(actor)
    capture("initial-state",scene.timeline.state); capture("initial-discovery",scene.available_actions)
    var pixel = await screen_pixel(id)
    check(pixel!=Vector2.INF,"Authored chest has an ordinary clickable pixel")
    if pixel==Vector2.INF: await finish(); return
    var command: int = scene.session.status.next_command_number
    click_at(pixel)
    if not await until(func():return ready() and contents(id)!=null and scene.hud.loot_panel.visible,"Native approach/open exposes its committed storage popup"): await finish(); return
    check(scene.session.status.next_command_number==command+2,"Distant chest click spends exactly approach and Open")
    await committed(command,"Approach"); await committed(command+1,"Open")
    if not await until(func():return scene.hud.loot_panel.item_buttons.size()==5,"Popup paints all five actual authored items"): await finish(); return
    var original: Dictionary = {}
    for item in contents(id): original[item.item_uuid] = item
    check(original.size()==5,"Current player state discloses five distinct item identities")
    var kinds:Array=original.values().map(func(item):return item.item_id);kinds.sort()
    var expected:Array=CACHE_ITEM_IDS.duplicate();expected.sort()
    check(kinds==expected,"Opened cache contains the exact five authored item kinds")
    check(original.keys().all(func(identity):return not initial.has(identity)),"Source storage has five original identities distinct from the initial carried items")
    await process_frame
    var selected = ""
    for identity in original:
        if original[identity].item_id == "spell_item.scroll_fireball": selected = identity; break
    check(not selected.is_empty(),"Fixture offers its authored Fireball scroll for individual transfer")
    if selected.is_empty(): await finish(); return
    var panel = scene.hud.loot_panel
    command = scene.session.status.next_command_number
    click_at(panel.item_buttons[selected].get_global_rect().get_center())
    check(panel.selected_item==selected and not panel.take_button.disabled,"Item icon selects its exact native Loot choice")
    check(scene.session.status.next_command_number==command,"Selecting loot icon does not spend a world action")
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(scene.game_config.test_result.get_base_dir().path_join("storage-popup.png"))
    click_at(panel.take_button.get_global_rect().get_center())
    check(scene.command_busy,"Take enters native preview/receipt wait")
    click_at(panel.take_button.get_global_rect().get_center())
    click_at(panel.close_button.get_global_rect().get_center())
    check(not panel.visible,"Popup may be dismissed while transfer is pending")
    if not await until(func():return ready() and contents(id)!=null and contents(id).size()==4,"Take selected waits for one authoritative transfer"): await finish(); return
    await committed(command,"Take selected")
    check(scene.session.status.next_command_number==command+1,"Rapid repeated Take submits exactly one command")
    check(not panel.visible and scene.loot_object_uuid.is_empty(),"Transfer completion preserves manual dismissal")
    check(inventory(actor).has(selected),"Selected exact item identity is now in controlled inventory")
    check(scene.timeline.state.items[selected].look.item_id=="spell_item.scroll_fireball","Selected canonical ItemRecord retains the original Fireball-scroll kind")
    check(not contents(id).any(func(item):return item.item_uuid==selected),"Selected identity is removed from source storage")
    check(initial.keys().all(func(identity):return inventory(actor).has(identity)),"Single transfer retains every previously carried identity")
    check(inventory(actor).size()==initial.size()+1,"Taking one preserves other carried items")
    capture("single-state",scene.timeline.state)
    command = scene.session.status.next_command_number
    click_at(await screen_pixel(id))
    if not await until(func():return panel.visible and panel.item_buttons.size()==4,"Manual reopen sees the pending transfer's committed remainder"): await finish(); return
    check(scene.session.status.next_command_number==command,"Manual reopen after pending dismissal does not spend")
    click_at(panel.close_button.get_global_rect().get_center())
    check(not panel.visible and scene.loot_object_uuid.is_empty(),"Close button dismisses popup")
    check(scene.session.status.next_command_number==command,"Popup dismissal submits no native command")
    pixel = await screen_pixel(id)
    check(pixel!=Vector2.INF,"Open chest remains ordinarily clickable")
    if pixel==Vector2.INF: await finish(); return
    click_at(pixel)
    if not await until(func():return panel.visible and panel.item_buttons.size()==4,"Clicking an already open chest reopens its current contents"): await finish(); return
    check(scene.session.status.next_command_number==command,"Reopening popup does not repeat Open or transfer")
    check(not panel.loot_all_button.disabled,"Remaining items offer native Loot All")
    click_at(panel.loot_all_button.get_global_rect().get_center())
    if not await until(func():return ready() and contents(id)!=null and contents(id).is_empty(),"Loot All receives an observed-empty storage after-value"): await finish(); return
    await committed(command,"Loot All")
    for identity in original:
        check(inventory(actor).has(identity),"Loot All preserves exact authored identity "+identity)
        check(scene.timeline.state.items[identity].look.item_id==original[identity].item_id,"Loot All retains the exact original ItemRecord kind "+identity)
    check(inventory(actor).size()==initial.size()+5 and initial.keys().all(func(identity):return inventory(actor).has(identity)),"Loot All transfers exactly five originals once while preserving carried items")
    check(scene.session.status.next_command_number==command+1,"Loot All spends exactly one authoritative command")
    if not await until(func():return panel.item_buttons.is_empty(),"Empty storage clears all item buttons"): await finish(); return
    check(panel.visible and panel.loot_all_button.disabled and panel.take_button.disabled,"Observed empty popup stays open with transfer controls disabled")
    command = scene.session.status.next_command_number
    key(KEY_ESCAPE)
    check(not panel.visible,"Escape closes storage")
    click_at(await screen_pixel(id))
    if not await until(func():return panel.visible,"Empty open storage can be reopened"): await finish(); return
    check(scene.session.status.next_command_number==command,"Empty reopen is local UI only")
    key(KEY_ESCAPE)
    # The exact native Close remains available separately from dismissing UI.
    click_at(await screen_pixel(id),MOUSE_BUTTON_RIGHT)
    check(scene.context_menu.visible,"Right click retains native storage alternatives")
    var close_index = -1
    for index in range(scene.context_menu.item_count):
        if scene.context_menu.get_item_text(index).begins_with("Close"): close_index = index; break
    check(close_index>=0,"Context offers native Close Chest")
    if close_index<0: await finish(); return
    scene.context_menu.id_pressed.emit(scene.context_menu.get_item_id(close_index)); scene.context_menu.hide()
    if not await until(func():return ready() and contents(id)!=null and contents(id).is_empty() and scene.timeline.state.objects[id].item.is_open==false,"Native Close retains the last observed empty contents with a closed authoritative item state"): await finish(); return
    await committed(command,"Close Chest")
    check(scene.session.status.next_command_number==command+1,"Native Close spends one command, separately from local popup dismissal")
    command=scene.session.status.next_command_number
    click_at(await screen_pixel(id))
    if not await until(func():return ready() and contents(id)!=null and contents(id).is_empty() and panel.visible and scene.timeline.state.objects[id].item.is_open==true,"Native reopening a known closed chest commits Open and preserves observed empty contents"): await finish(); return
    check(scene.session.status.next_command_number==command+1,"Remembered contents never bypass a real native Open command")
    await committed(command,"Reopen Chest")
    check(inventory(actor).size()==initial.size()+5 and original.keys().all(func(identity):return inventory(actor).has(identity)),"Close/reopen cannot duplicate or remove the already transferred originals")
    capture("final-state",scene.timeline.state); capture("final-discovery",scene.available_actions)
    evidence.storage = {"object_uuid":id,"actor_uuid":actor,"original_items":original.keys(),"single_item":selected,
        "final_contents":contents(id),"final_inventory":inventory(actor).keys(),"expected_item_ids":CACHE_ITEM_IDS}
    click_at(panel.close_button.get_global_rect().get_center())
    check(not panel.visible and scene.loot_object_uuid.is_empty(),"Final Close control dismisses the empty popup without another world command")
    check(scene.session.status.next_command_number==command+1,"Final local Close preserves the exact last native command number")
    await finish()
