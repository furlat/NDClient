extends SceneTree
# Exact displayed state/discovery captured from the live native sorcerer seat.
# This checks its real UI projection; it does not submit backend commands.
const HUD = preload("res://play_hud.gd")
const UI = preload("res://presentation/ui_catalog.gd")
const JSONReader = preload("res://sdk/strict_json.gd")
const FixtureWorld = preload("res://tests/ui_fixture_world.gd")
var checks = 0
var failures: Array = []
var bar_layouts: Array = []
func check(value: bool, message: String) -> void:
    checks += 1
    if not value: failures.append(message); print("RECORDED_UI_FAIL ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    if "--background-check" in OS.get_cmdline_user_args():
        root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    var directory = "res://.runtime/player-runs/20261011T222502.988278Z"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="): directory = argument.trim_prefix("--capture=")
    var state = JSONReader.new().parse(FileAccess.get_file_as_string(directory.path_join("state.json"))).value
    var discovery = JSONReader.new().parse(FileAccess.get_file_as_string(directory.path_join("discovery.json"))).value
    var original = state.duplicate(true)
    var original_discovery: Dictionary = discovery.duplicate(true)
    var identifiers_match = true
    var seen_content = {}
    for descriptor in state.content:
        var ref: Dictionary = descriptor.ref
        var identity = "%s:%s:%s@%d" % [ref.pack_id,ref.definition_kind,ref.content_id,ref.content_version]
        if not seen_content.has(ref.content_id): seen_content[ref.content_id] = descriptor
        identifiers_match = identifiers_match and UI.descriptor(state,ref.content_id)==seen_content[ref.content_id] and UI.descriptor(state,identity)==descriptor and UI.descriptor(state,"",ref)==descriptor
    check(identifiers_match,"Every admitted short ID, qualified ContentRef identity and exact reference resolves its original descriptor")
    check(discovery.entity_uuid == state.current_actor_uuid,"captured choices belong to displayed actor")
    root.size = Vector2i(1280,720)
    var world = FixtureWorld.new()
    world.timeline.state = state
    world.available_actions = discovery
    root.add_child(world)
    var hud = HUD.new(); hud.world = world; root.add_child(hud)
    await process_frame; await process_frame
    check(hud.groups.Base.size()==10,"native base family count")
    check(hud.groups.Class.size()==4,"slot conversion and metamagic families")
    check(hud.groups.Spells.size()==11,"all eleven admitted spell families")
    check(hud.groups.Items.size()==3,"three carried item action families")
    var icons = 0
    var original_handles = {}
    for group in hud.groups.values():
        for family in group:
            for row in family.rows:
                var key = UI.action_key(row,state,hud.cache,true)
                check(not key.is_empty() and UI.texture(key,hud.cache)!=null,"authored icon for "+str(row.display_name))
                original_handles[key] = UI.texture(key,hud.cache)
                icons += 1
    var image_deadline = Time.get_ticks_msec()+30000
    while UI.images_pending(hud.cache) and Time.get_ticks_msec()<image_deadline: await process_frame
    check(not UI.images_pending(hud.cache) and hud.cache.ui_media.failed.is_empty(),"Actual action icons finish asynchronously without errors")
    check(original_handles.keys().all(func(key):return is_same(original_handles[key],UI.texture(key,hud.cache))),"Async decoding preserves the original icon resources already assigned to native controls")
    check(hud.missing_icons.is_empty(),"painted real controls have authored icons")
    check_bar_alignment(hud,"720p with mixed header controls")
    if "--screenshot" in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://.runtime/ui/action-bar-aligned.png")
    var wheel = InputEventMouseButton.new()
    wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true
    wheel.position = hud.shortcuts[0].get_global_rect().get_center()
    root.push_input(wheel)
    await process_frame; await process_frame
    check(hud.pages.Base==1,"real base paging changes the painted page")
    check_bar_alignment(hud,"paged base actions")
    for viewport_size in [Vector2i(960,720),Vector2i(1920,1080),Vector2i(1280,720)]:
        root.size = viewport_size
        await process_frame; await process_frame; await process_frame
        check_bar_alignment(hud,"resized %s" % viewport_size)
    var magic: Dictionary = hud.groups.Spells.filter(func(f):return f.rows[0].behavior_id=="spell.magic_missile")[0]
    check(hud._choices(magic.rows).size()==3,"actual magic missile ranks preserve exact rows")
    for row in hud._choices(magic.rows): check(row in discovery.entity_actions,"rank is an unchanged native entity choice")
    var inventory_started = Time.get_ticks_usec()
    hud.toggle_inventory()
    var inventory_open_ms = (Time.get_ticks_usec()-inventory_started)/1000.0
    print("RECORDED_INVENTORY_OPEN cpu_ms=",inventory_open_ms)
    await process_frame
    var actor: Dictionary = state.actors[state.current_actor_uuid]
    check(hud.inventory_buttons.size()==actor.controlled_items.size(),"actual carried inventory projects exactly")
    var potion: Dictionary = actor.controlled_items.filter(func(item):return item.item_id=="consumable.healing_potion")[0]
    hud.inventory_buttons[potion.item_uuid].emit_signal("pressed")
    check(hud.item_commands.get_child_count()==2,"native use and native drop both appear for healing potion")
    check(not "<null>" in hud.item_details.text,"nullable native description is omitted from visible details")
    for button in hud.item_commands.get_children():
        if button.text.begins_with("Drink"):
            button.emit_signal("pressed")
            check(world.issued[-1].source_item_uuid==potion.item_uuid and world.issued[-1].behavior_id=="action.item.potion_healing.drink","use button passes unchanged native item choice")
            break
    check(state==original,"real inventory projection stays read only")
    hud.search.grab_focus()
    var keyevent = InputEventKey.new(); keyevent.keycode=KEY_1; keyevent.pressed=true
    var before = world.issued.size()
    hud._input(keyevent)
    check(world.issued.size()==before,"real inventory search captures shortcuts")
    image_deadline = Time.get_ticks_msec()+30000
    while UI.images_pending(hud.cache) and Time.get_ticks_msec()<image_deadline: await process_frame
    check(not UI.images_pending(hud.cache) and hud.cache.ui_media.failed.is_empty(),"Inventory and paged icon originals finish asynchronously without errors")
    if DisplayServer.get_name() != "headless":
        for path in hud.cache.ui_media.sources:
            var expected = Image.load_from_file(UI.Catalog.media_path(path))
            var actual = hud.cache.ui_media.sources[path].get_image()
            check(actual != null and actual.get_size()==expected.get_size() and actual.get_data()==expected.get_data(),"Worker-decoded native texture retains exact original image bytes: "+path)
    if "--screenshot" in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("C:/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/ui/ui-recorded-720.png")
    check(discovery==original_discovery,"Recorded discovery and all native target rows remain unchanged through HUD use")
    root.remove_child(hud); hud.free(); root.remove_child(world); world.free()
    await process_frame
    var report = {"kind":"recorded_live_ui_projection","capture":directory,"checks":checks,"failures":failures,"icons":icons,"inventory_open_cpu_ms":inventory_open_ms,"bar_layouts":bar_layouts,"ok":failures.is_empty()}
    var file = FileAccess.open("res://.runtime/ui/recorded-checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func check_bar_alignment(hud: Control, scenario: String) -> void:
    var rows = {}
    for shortcut in hud.shortcuts:
        var row = int(shortcut/12)
        var rect: Rect2 = hud.shortcuts[shortcut].get_global_rect()
        if not rows.has(row): rows[row] = []
        rows[row].append(rect.position.y)
    for row in rows:
        var aligned = rows[row].max()-rows[row].min() <= 1.0
        check(aligned,"%s: all group icons align in row %d (%s)" % [scenario,row,rows[row]])
    bar_layouts.append({"scenario":scenario,"row_y":rows})
