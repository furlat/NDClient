extends SceneTree
# Actual recorded player snapshot + named UI boundary fixtures. These exercise
# native Control input dispatch, not claimed new backend gameplay outcomes.
const HUD = preload("res://play_hud.gd")
const UI = preload("res://presentation/ui_catalog.gd")
const FixtureWorld = preload("res://tests/ui_fixture_world.gd")
const Journal = preload("res://sdk/journal.gd")
const Fixtures = preload("res://tests/recording_fixtures.gd")
var checks = 0
var failures = 0
var world: Node3D
var hud: Control
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures += 1; print("UI_FAIL ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    if "--background-check" in OS.get_cmdline_user_args():
        root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    root.size = Vector2i(1280,720)
    world = FixtureWorld.new()
    root.add_child(world)
    var journal=Journal.new()
    var opened:Dictionary=journal.open(Fixtures.journal("interaction-media"),true,false)
    check(opened.ok,"Durable original schema16 fighter journal opens")
    if not opened.ok:quit(1);return
    var folded:Dictionary=journal.replay(0)
    check(folded.ok,"Actual fighter initialization folds through the current SDK")
    if not folded.ok:quit(1);return
    var state: Dictionary = journal.state.duplicate(true)
    # Choose the actually disclosed controlled fighter for this UI boundary.
    var actor_id: String = state.observer_uuid
    state.current_actor_uuid = actor_id
    var original_state = state.duplicate(true)
    world.timeline.state = state
    var rows: Array = []
    for i in range(34):
        var row = fixture_row("action.dash",i,actor_id)
        row.behavior_id = "fixture.page.%d" % i
        row.provided_by_id = "action.dash"
        row.configured_action_ref = UI.descriptor(state,"action.dash").get("ref")
        row.display_name = "Page boundary %d" % i
        rows.append(row)
    var melee = fixture_row("action.attack",40,actor_id)
    melee.action_category = "attack"; melee.weapon_slot = "MELEE_MAIN"
    rows.append(melee)
    var ranged = melee.duplicate(true); ranged.discovery_index = 41; ranged.weapon_slot = "RANGED_MAIN"; rows.append(ranged)
    var spell = fixture_row("spell.magic_missile",50,actor_id)
    spell.action_category = "spell"
    spell.configured_action_ref = UI.descriptor(state,"spell.magic_missile").get("ref")
    spell.cast_at_level = 1
    rows.append(spell)
    var upcast = spell.duplicate(true); upcast.discovery_index = 51; upcast.cast_at_level = 2; rows.append(upcast)
    var unavailable = spell.duplicate(true); unavailable.discovery_index = 52; unavailable.cast_at_level = 3; unavailable.availability_status = "source_unaffordable"; unavailable.can_afford = false; rows.append(unavailable)
    var wall = fixture_row("action.open",60,actor_id); wall.interaction_affordance.surface = "world"; rows.append(wall)
    var carried: Dictionary = UI.item(state.actors[actor_id].controlled_items[0],state)
    var item = fixture_row("action.item.use",70,actor_id); item.source_item_uuid = carried.item_uuid; item.action_category = "ability"; rows.append(item)
    var class_row = fixture_row("action.class.fighter.second_wind",80,actor_id); class_row.provided_by_id = "class_feature.fighter.second_wind"; rows.append(class_row)
    world.available_actions = {"discovery_generation":"ui-boundary-a","entity_uuid":actor_id,"self_actions":rows,"target_sets":[[{"kind":"self","index":0}]]}
    var original_discovery: Dictionary = world.available_actions.duplicate(true)
    hud = HUD.new(); hud.world = world; root.add_child(hud)
    await settle_action_bar()
    check(hud.actor_hud.initiative_buttons.keys()==state.hud_snapshot.initiative,"Initiative portraits preserve the actual disclosed server order")
    check(hud.actor_hud.party_ids==state.audience.controlled,"Party portraits use disclosed controlled sheets")
    check(hud.actor_hud.party.position.x==20,"Party stays on the left edge")
    check(hud.actor_hud.party_buttons[actor_id].health==state.actors[actor_id].normal_hp,"Portrait HP comes from displayed actor state")
    check(hud.actor_hud.party_buttons[actor_id].tooltip_text.contains("AC "+str(state.actors[actor_id].armor_class)),"Portrait inspect includes disclosed armor class")
    var image: Texture2D=hud.actor_hud.party_buttons[actor_id].portrait
    if image!=null: check(image.changed.is_connected(hud.actor_hud.party_buttons[actor_id].queue_redraw),"Async portrait image arrival refreshes source crop and redraw")
    var enemy: String=state.hud_snapshot.initiative.filter(func(id):return id not in state.audience.controlled)[0]
    hud.actor_hud.initiative_buttons[enemy].emit_signal("pressed")
    check(hud._inspect_actor().uuid==enemy and hud._action_actor().uuid==actor_id and world.issued.is_empty(),"Enemy portrait inspection cannot change command owner or issue a command")
    hud._inspect_portrait(actor_id)
    for resource in UI.sheet(state,actor_id).resources:
        check(hud.actor_hud.resource_buttons[resource.key].tooltip_text==resource.label+": "+str(resource.current)+" / "+str(resource.maximum),"Resource tooltip retains exact displayed amount: "+resource.key)
    var bar_identity= hud.bar.get_instance_id()
    world.allow_commands=false
    world.timeline.state=state.duplicate(true)
    world.timeline.state.current_actor_uuid=enemy
    world.timeline.revision+=1
    await process_frame; await process_frame
    check(hud.bar.get_instance_id()==bar_identity and hud.painted_actor==actor_id,"Enemy turn disables existing player bar without rebuilding it for the enemy")
    check(hud.actor_hud.initiative_buttons[enemy].current_turn,"Initiative advances to displayed enemy turn independently of inspection")
    world.timeline.state=state; world.timeline.revision+=1; world.allow_commands=true
    await process_frame; await process_frame
    hud.toggle_history(); await process_frame; await process_frame
    check(hud.history_button.position.x>root.size.x*.75 and hud.history_button.get_rect().end.x<hud.end_button.position.x,"Log toggle sits beside End Turn on the right")
    check(hud.history_panel.position.y<100 and absf(hud.history_panel.get_rect().end.y-(hud.end_button.position.y-12))<2,"Log spans from upper-right to just above End Turn")
    key(KEY_ESCAPE); await process_frame
    check(hud.history_panel.visible and hud.settings_open(),"Escape opens settings without hiding the combat log")
    key(KEY_ESCAPE); hud.toggle_history(); await process_frame
    world.notice_text = "Authored media metadata preparation did not complete; inspect the source error log."
    await process_frame; await process_frame; await process_frame
    check(hud.copy_notice.is_visible_in_tree(),"Error exposes Copy directly beside the visible message")
    check(not hud.top.get_global_rect().intersects(hud.actor_hud.party.get_global_rect()),"Multiline error and Copy remain clear of left party portraits")
    var copy_point: Vector2 = hud.copy_notice.get_global_rect().get_center()
    check(hud.pointer_over_controls(copy_point),"Copy consumes its click instead of issuing a world action")
    if DisplayServer.get_name()!="headless":
        var prior_clipboard = DisplayServer.clipboard_get()
        click(copy_point); await process_frame
        var copied = JSON.parse_string(DisplayServer.clipboard_get())
        check(copied!=null and copied.message==world.notice_text,"Click copies the exact error and diagnostic context")
        check(hud.notice.text==world.notice_text and hud.copy_notice.text=="Copied","Copy feedback retains the error on screen")
        DisplayServer.clipboard_set(prior_clipboard)
    world.notice_text = ""
    await process_frame
    check(not hud.copy_notice.is_visible_in_tree(),"Copy and message row disappear when no notice is present")
    var observed_position: Array = state.actors[actor_id].last_visual_position
    check(not state.actors[actor_id].has("position"),"Recorded canonical actor uses the original last_visual_position schema")
    world.visual_actors[actor_id] = {"row":{"position":observed_position,"base_height_steps":0}}
    world.camera = Camera3D.new(); world.add_child(world.camera)
    hud._update_ground_preview()
    var cell_key = "%d,%d" % [observed_position[0],observed_position[1]]
    check(world.ground_overlay.marks.has(cell_key),"Turn cell marker uses the rendered actor position without reading a nonexistent SDK field")
    var marked={cell_key:{"fill_colour":Color(1,.5,0,.2)}}
    hud._ground_mark(marked,observed_position,Color.WHITE)
    check(marked[cell_key].fill_colour==Color(1,.5,0,.2),"Cursor/current-actor outline preserves computed AoE fill underneath")
    world.camera.free(); world.camera = null; world.visual_actors.clear()
    check(not world.normals_visible and not hud.normals_button.button_pressed,"Normals preview starts off")
    check(hud.normals_button.get_global_rect().position.x>hud.grid_button.get_global_rect().end.x,"Normals control is beside Grid without overlapping it")
    var normal_point: Vector2 = hud.normals_button.get_global_rect().get_center()
    check(hud.pointer_over_controls(normal_point),"Normals button owns its world pointer boundary")
    click(normal_point);await process_frame
    check(world.normals_visible and hud.normals_button.button_pressed,"Native Normals click enables the scene preview")
    check(world.issued.is_empty() and root.gui_get_focus_owner()==null,"Normals click neither submits an action nor captures keyboard focus")
    world.set_normals_visible(false);await process_frame;await process_frame
    check(not hud.normals_button.button_pressed,"Button follows a scene-side normal preview change")
    click(normal_point);await process_frame
    click(normal_point);await process_frame
    check(not world.normals_visible and world.issued.is_empty(),"Second native click restores ordinary rendering without a game command")
    check(hud.groups.Base.size()==36,"both explicit weapon slots and base rows remain separate")
    check(hud.groups.Spells.size()==1 and hud.groups.Spells[0].rows.size()==3,"actual native variants remain one family")
    check(hud.groups.Items.size()==1 and hud.groups.Class.size()==1,"four groups use native sources")
    check(hud.shortcuts.size()>0,"visible painted controls own shortcuts")
    var mode: Button = hud.bar.find_child("AttackPreference",true,false)
    check(mode != null and mode.text == "Melee · X","ordinary click preference is visibly labeled")
    mode.emit_signal("pressed")
    await settle_action_bar()
    mode = hud.bar.find_child("AttackPreference",true,false)
    check(world.attack_preference == "RANGED_MAIN" and mode.text == "Ranged · X","mode control toggles preference without issuing an action")
    var ordinary = fixture_row("action.dash",100,actor_id)
    var restricted = ordinary.duplicate(true); restricted.discovery_index=101; restricted.restricted_action_budget="Haste"
    check(hud._choices([ordinary,restricted]).size()==1 and hud._choices([ordinary,restricted])[0].discovery_index==101,"restricted budget alternatives retain one verb and source preferred budget")
    var residual = ordinary.duplicate(true); residual.discovery_index=102; residual.costs=[{"cost":0,"cost_type":"actions","resource_name":"fixture","resource_cost":2}]
    check(hud._choices([ordinary,residual]).size()==2,"distinct ordinary native options never collapse by matching facets")
    var first: Button = hud.shortcuts[0]
    var old_index: int = first.get_meta("native_row").discovery_index
    key(KEY_1)
    check(world.issued.size()==1 and world.issued[-1].discovery_index==old_index,"digit dispatches currently painted exact row")
    # Feed a real GUI wheel event over an icon; the group must own it.
    var wheel = InputEventMouseButton.new()
    wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
    wheel.pressed = true
    wheel.position = first.get_global_rect().get_center()
    root.push_input(wheel)
    await settle_action_bar()
    check(hud.pages.Base==1,"wheel over painted icon pages its group")
    var new_index: int = hud.shortcuts[0].get_meta("native_row").discovery_index
    check(new_index!=old_index,"independent base page changes painted shortcut")
    key(KEY_1)
    check(world.issued.size()==2 and world.issued[-1].discovery_index==new_index,"paging never executes former shortcut")
    check(hud.pages.Spells==0 and hud.pages.Items==0,"paging does not change other groups")
    var prior_discovery: Dictionary = world.available_actions
    world.available_actions = prior_discovery.duplicate()
    world.available_actions.discovery_generation = "ui-boundary-b"
    check(hud.painted_discovery.discovery_generation=="ui-boundary-a","New admitted generation never mutates the still-painted discovery")
    var before: int = world.issued.size()
    key(KEY_1)
    check(world.issued.size()==before,"stale generation rejected before next redraw")
    world.available_actions = prior_discovery
    check(world.available_actions==original_discovery,"Grouping, paging and stale input preserve the admitted discovery exactly")
    world.allow_commands = false
    key(KEY_1)
    check(world.issued.size()==before,"catchup boundary rejects spending")
    world.allow_commands = true
    await process_frame
    var origin: Button
    for button in hud.action_buttons:
        if button.get_meta("group") == "Spells": origin = button; break
    click(origin.get_global_rect().get_center())
    check(hud.popup.visible,"Native pointer opens authored variant choices")
    var grid = hud.popup.get_child(0).get_child(1).get_child(0)
    check(grid.get_child_count()==3,"popup contains only actual discovered variants")
    check(grid.get_child(2).disabled,"unaffordable native variant remains inspectable and disabled")
    check(hud.popup_bridge.has_point(origin.get_global_rect().get_center()),"continuous capture region includes source icon")
    # Force a native overlapping boundary without changing the production layout.
    # Bar rebuilds append a newer sibling than the visible popup: paint Z alone
    # must not let that lower action receive a popup choice's mouse event.
    var underneath: Button = hud.shortcuts[0]
    var choice: Button = grid.get_child(1)
    await process_frame; await process_frame
    var disabled_choice: Button = grid.get_child(2)
    var disabled_offset: Vector2 = disabled_choice.get_global_rect().get_center()-hud.popup.global_position
    hud.popup.global_position = underneath.get_global_rect().get_center()-disabled_offset
    hud.popup_bridge = hud.popup.get_global_rect().merge(origin.get_global_rect())
    var disabled_before: int = world.issued.size()
    click(disabled_choice.get_global_rect().get_center())
    check(world.issued.size()==disabled_before and hud.popup.visible,"Disabled overlapping native choice cannot click the underlying action")
    var choice_offset: Vector2 = choice.get_global_rect().get_center()-hud.popup.global_position
    hud.popup.global_position = underneath.get_global_rect().get_center()-choice_offset
    hud.popup_bridge = hud.popup.get_global_rect().merge(origin.get_global_rect())
    var choice_point: Vector2 = choice.get_global_rect().get_center()
    check(underneath.get_global_rect().has_point(choice_point),"Native variant click overlaps a real underlying action button")
    var choice_before: int = world.issued.size()
    click(choice_point)
    check(world.issued.size()==choice_before+1 and world.issued[-1].discovery_index==51,"Actual overlapping mouse dispatch selects only the exact native upcast row")
    check(not hud.popup.visible,"Selecting a native variant closes its choice popup")
    before = world.issued.size()
    origin.emit_signal("mouse_entered")
    key(KEY_ESCAPE)
    check(not hud.popup.visible,"Escape consumes local choices")
    key(KEY_I)
    check(hud.panel.visible,"I opens equipment without world command")
    check(hud.slot_buttons.size()==14,"body, rings, and four weapon slots preserved")
    check(hud.inventory_buttons.size()==state.actors[actor_id].controlled_items.size(),"bag uses exact disclosed carried collection")
    check(hud.panel.get_rect().end.y <= hud.bar.position.y,"equipment panel leaves actionbar visible at 720p")
    hud.search.grab_focus()
    await process_frame
    key(KEY_1)
    check(world.issued.size()==before,"search focus captures action hotkeys")
    hud.search.text = "javelin"; hud.search.emit_signal("text_changed",hud.search.text)
    check(hud.inventory_buttons.size()==1,"search filters actual native inventory names")
    var javelin: Dictionary = UI.inventory(state.actors[actor_id],"javelin",state)[0]
    hud.inventory_buttons[javelin.item_uuid].emit_signal("pressed")
    var compatible = UI.compatible_slots(UI.sheet(state,actor_id),javelin.item_uuid)
    check(compatible==["MELEE_MAIN"],"native compatibility restricts exact disclosed slot")
    var equip: Button
    for button in hud.item_commands.get_children():
        if button.text.begins_with("Equip"): equip = button; break
    check(equip != null,"compatible equip intent is available")
    if equip != null:
        equip.emit_signal("pressed")
        check(world.issued[-1]==UI.equip_intent(javelin.item_uuid,"MELEE_MAIN"),"equip dispatches nested exact wire intent")
        equip.emit_signal("pressed")
        check(world.issued.size()==before+1,"outstanding inventory command cannot repeat")
    check(world.timeline.state==original_state,"UI never fabricates inventory state")
    check(UI.sheet({"hud_snapshot":null},actor_id).is_empty(),"undisclosed HUD snapshot remains optional")
    check(UI.cost_text({"costs":[{"cost":1,"cost_type":"bonus_actions","resource_name":"sorcery_points","resource_cost":3}]})=="1 bonus actions · 3 sorcery points","economy and named-resource costs retain independent amounts")
    check(UI.inventory({"controlled_items":null}).is_empty(),"undisclosed inventory stays absent")
    check(UI.unequip_intent("Body")=={"kind":"unequip","item":{"slot":"Body"}},"unequip uses exact nested wire payload")
    root.size = Vector2i(1920,1080)
    await settle_action_bar()
    check(hud.panel.get_rect().end.y <= hud.bar.position.y,"equipment leaves actionbar visible at 1080p")
    root.size = Vector2i(1920,600)
    await process_frame; await process_frame
    check(hud.end_button.get_global_rect().end.y<=600 and hud.inventory_button.get_global_rect().end.y<=600,"Height-only resize keeps spending/inventory controls inside viewport")
    check(hud.bar.position.y==454,"Height-only resize reanchors the action bar during an idle turn")
    if "--screenshot" in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("C:/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/ui/ui-fixture.png")
    root.remove_child(hud); hud.free()
    root.remove_child(world); world.free()
    await process_frame
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/ui"))
    var report = FileAccess.open("res://.runtime/ui/checks.json",FileAccess.WRITE)
    report.store_string(JSON.stringify({"kind":"named_ui_boundary_fixtures","checks":checks,"failures":failures,"ok":failures==0},"  ")); report.close()
    print("UI_BOUNDARY_CHECKS checks=",checks," failures=",failures)
    quit(1 if failures else 0)
func fixture_row(behavior: String, index: int, actor: String) -> Dictionary:
    return {"discovery_generation":"ui-boundary-a","discovery_index":index,"discovery_actor_uuid":actor,"discovery_runtime":"fixture", "behavior_id":behavior,"provided_by_id":behavior,"display_name":behavior.trim_prefix("action.").capitalize(),"description":"Named UI boundary fixture","availability_status":"available","can_afford":true,"target_set":0,"action_category":"ability","interaction_affordance":{"surface":"action_bar"},"variant_facets":[],"costs":[],"target_type":"self"}
func key(code: Key, shift: bool = false) -> void:
    var event = InputEventKey.new(); event.keycode = code; event.pressed = true; event.shift_pressed = shift
    hud._input(event)
func click(point: Vector2) -> void:
    var motion = InputEventMouseMotion.new(); motion.position = point; root.push_input(motion)
    for pressed in [true,false]:
        var event = InputEventMouseButton.new()
        event.position = point; event.global_position = point
        event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
        root.push_input(event)

func settle_action_bar() -> void:
    await process_frame
    await process_frame
    for _frame in range(100):
        if not hud.bar_pending(): break
        await process_frame
    check(not hud.bar_pending(),"Action bar preparation publishes before native input/layout assertions")
    await process_frame
