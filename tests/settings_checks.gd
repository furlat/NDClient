extends SceneTree
# Native Control input and local ConfigFile persistence; no backend simulator.
const HUD = preload("res://play_hud.gd")
const Settings = preload("res://presentation/render_settings.gd")
const FixtureWorld = preload("res://tests/ui_fixture_world.gd")
var checks=0
var failures=[]
var world:Node3D
var hud:Control
var underlay:Button
var hits=0
var config_path="user://settings-checks-%s.cfg" % Time.get_ticks_usec()
class SettingsWorld extends FixtureWorld:
    var character_light_profile=Settings.DEFAULT_PROFILE
    var fire_light_flicker=Settings.DEFAULT_FIRE_LIGHT_FLICKER
    var light_strength=Settings.DEFAULT_LIGHT_STRENGTH
    var settings_path=""
    var accepted=[]
    var media_issue=""
    var owner_hud:Control
    var unhandled=[]
    func set_character_light_profile(profile:String)->void:
        if Settings.write(profile,settings_path)!=OK:return
        character_light_profile=profile;accepted.append(profile)
    func set_fire_light_flicker(enabled:bool)->void:
        if Settings.write_fire_light_flicker(enabled,settings_path)!=OK:return
        fire_light_flicker=enabled
    func set_light_strength(value:float,persist:bool=true)->void:
        light_strength=value
        if persist:Settings.write_light_strength(value,settings_path)
    func close_storage()->void:
        loot_object_uuid=""
        if owner_hud!=null:owner_hud.loot_panel.hide()
    func _process(delta:float)->void:timeline.advance(delta*1000.0)
    func _unhandled_input(event:InputEvent)->void:
        if owner_hud!=null:
            if event is InputEventKey and owner_hud.owns_keyboard_focus():return
            if event is InputEventMouse and owner_hud.pointer_over_controls(event.position):return
        if event is InputEventKey and event.pressed:unhandled.append(event.keycode)
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("SETTINGS_FAIL ",label)
func _initialize()->void:run.call_deferred()
func key(code:Key)->void:
    var target=root
    for pressed in [true,false]:
        var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
        target.push_input(event,true)
func click(point:Vector2,button:MouseButton=MOUSE_BUTTON_LEFT)->void:
    var move=InputEventMouseMotion.new();move.position=point;root.push_input(move)
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed
        root.push_input(event)
func run()->void:
    root.size=Vector2i(1280,720)
    root.gui_embed_subwindows=true
    check(Settings.PROFILES.keys()==["original","gentle","reference"],"Only three delivered normal profiles are offered")
    check(Settings.read(config_path)=={"profile":"reference","fire_light_flicker":false,"light_strength":1.0,"error":OK} and not FileAccess.file_exists(config_path),"Missing setting uses current demo Reference default without writing a file")
    check(Settings.write("gentle",config_path)==OK and Settings.read(config_path).profile=="gentle","ConfigFile round trip preserves a selected profile")
    check(Settings.write("unregistered-profile",config_path)==ERR_INVALID_PARAMETER and Settings.read(config_path).profile=="gentle","Unknown profile cannot overwrite saved selection")
    var saved=ConfigFile.new();saved.load(config_path);saved.set_value("unrelated","keep",73);saved.save(config_path)
    check(Settings.write("reference",config_path)==OK,"Known profile is saved")
    saved=ConfigFile.new();saved.load(config_path)
    check(saved.get_value("unrelated","keep")==73,"Saving rendering settings preserves unrelated ConfigFile values")
    saved.set_value("rendering","character_light_profile","retired-choice");saved.save(config_path)
    check(Settings.read(config_path).profile==Settings.DEFAULT_PROFILE,"Unsupported saved value uses declared current default")
    Settings.write("reference",config_path)
    world=SettingsWorld.new();world.settings_path=config_path;root.add_child(world)
    var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.runtime/player-runs/20261011T223103.996259Z/state.json"))
    world.timeline.state=state
    underlay=Button.new();underlay.text="";root.add_child(underlay);underlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    underlay.pressed.connect(func():hits+=1)
    hud=HUD.new();hud.world=world;world.owner_hud=hud;root.add_child(hud)
    await process_frame;await process_frame
    click(Vector2(5,360));await process_frame
    check(hits==1,"Underlying control receives an ordinary nonmodal pointer event")
    hud.popup.show();key(KEY_ESCAPE);await process_frame
    check(not hud.popup.visible and not hud.settings_open(),"Escape closes an existing action popup before settings")
    hud.toggle_inventory();hud.search.grab_focus();key(KEY_ESCAPE);await process_frame
    check(not hud.panel.visible and not hud.settings_open() and not hud.search.has_focus(),"Escape closes focused inventory and releases text focus first")
    hud.toggle_history();key(KEY_ESCAPE);await process_frame
    check(not hud.history_panel.visible and not hud.settings_open(),"Escape closes history first")
    hud.loot_panel.show();key(KEY_ESCAPE);await process_frame
    check(not hud.loot_panel.visible and not hud.settings_open(),"Escape closes disclosed storage first")
    world.selected_action={"discovery_index":7};key(KEY_ESCAPE);await process_frame
    check(world.selected_action.is_empty() and not hud.settings_open(),"Escape cancels an existing selection before opening settings")
    key(KEY_ESCAPE);await process_frame;await process_frame
    check(hud.settings_open() and hud.settings_panel.visible,"Escape opens the native settings menu")
    check(hud.settings_panel.profiles.get_item_metadata(hud.settings_panel.profiles.selected)=="reference","Menu reflects renderer's accepted profile")
    check(not hud.settings_panel.fire_flicker.button_pressed,"Fire light flicker defaults off")
    await process_frame;await process_frame
    click(hud.settings_panel.fire_flicker.get_global_rect().get_center());await process_frame
    check(world.fire_light_flicker and Settings.read(config_path).fire_light_flicker,"Checkbox enables and persists fire light flicker")
    await process_frame;await process_frame
    click(hud.settings_panel.fire_flicker.get_global_rect().get_center());await process_frame
    check(not world.fire_light_flicker and not Settings.read(config_path).fire_light_flicker,"Checkbox restores static fire lighting without affecting the profile")
    check(hud.settings_panel.strength.value==1.0 and hud.settings_panel.strength.max_value==1.5,"Light strength defaults to100% with a150% maximum")
    hud.settings_panel.strength.grab_focus();key(KEY_LEFT);await process_frame
    check(is_equal_approx(world.light_strength,.99),"Native slider keyboard input changes light strength immediately")
    await create_timer(.25).timeout
    check(is_equal_approx(Settings.read(config_path).light_strength,.99),"Settled slider value is persisted without changing normal/flicker settings")
    check(Settings.read(config_path).profile=="reference" and not Settings.read(config_path).fire_light_flicker,"Light strength preserves independent rendering preferences")
    check(hud.owns_keyboard_focus() and hud.pointer_over_controls(Vector2(5,360)),"Modal owns keyboard and complete viewport pointer boundary")
    var normals_before: bool = world.normals_visible
    click(hud.normals_button.get_global_rect().get_center());await process_frame
    check(world.normals_visible==normals_before and hud.settings_open(),"Modal intercepts clicks at Normals without changing the preview behind it")
    check(hud.settings_panel.card.get_global_rect().has_point(root.size*0.5),"Settings card stays centered over visible game")
    var at=world.timeline.display_ms
    await process_frame;await process_frame
    check(not paused and not world.timeline.paused and world.timeline.display_ms>at,"Settings leaves SceneTree and displayed timeline running")
    var commands=world.issued.duplicate(true);var before=world.unhandled.size()
    for code in [KEY_P,KEY_Q,KEY_E,KEY_G,KEY_Z,KEY_X,KEY_M,KEY_J,KEY_I,KEY_L,KEY_1,KEY_BACKSPACE]:key(code)
    click(Vector2(5,360));click(Vector2(5,360),MOUSE_BUTTON_WHEEL_DOWN);await process_frame
    check(hits==1 and world.issued==commands and world.unhandled.size()==before,"Modal blocks clickthrough, action shortcuts, navigation and pause keys")
    check(not hud.panel.visible and not hud.history_panel.visible,"Inventory/history shortcuts cannot replace settings")
    hud.settings_panel.profiles.grab_focus();key(KEY_SPACE);await process_frame
    var popup:PopupMenu=hud.settings_panel.profiles.get_popup()
    check(popup.visible,"Focused native profile selector opens with Space")
    if popup.visible:
        key(KEY_UP);await process_frame
        key(KEY_ENTER);await process_frame
    check(world.character_light_profile=="gentle" and Settings.read(config_path).profile=="gentle","Native selector keyboard choice applies and persists Gentle")
    hud.settings_panel.profiles.grab_focus();key(KEY_SPACE);await process_frame
    check(popup.visible,"Profile selector reopens without restarting the menu")
    if popup.visible:key(KEY_ESCAPE)
    await process_frame
    check(not popup.visible and hud.settings_open(),"Escape closes only the native profile dropdown first")
    key(KEY_ESCAPE);await process_frame
    check(not hud.settings_open() and not hud.owns_keyboard_focus(),"Escape resumes game input from settings")
    key(KEY_ESCAPE);await process_frame;await process_frame
    check(hud.settings_panel.profiles.get_item_metadata(hud.settings_panel.profiles.selected)=="gentle","Reopening settings retains accepted renderer profile")
    click(hud.settings_panel.resume_button.get_global_rect().get_center());await process_frame
    check(not hud.settings_open() and hits==1,"Back to game closes without leaking its click underneath")
    var reopened=Settings.read(config_path)
    check(reopened.error==OK and reopened.profile=="gentle","A fresh settings load restores the accepted profile")
    root.size=Vector2i(700,500);hud.open_settings();await process_frame;await process_frame
    var rect=hud.settings_panel.card.get_global_rect()
    check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=700 and rect.end.y<=500,"Modal remains usable after viewport resize")
    hud.close_settings()
    root.remove_child(hud);hud.free();root.remove_child(world);world.free();root.remove_child(underlay);underlay.free()
    DirAccess.remove_absolute(config_path)
    var report={"checks":checks,"failures":failures,"scope":"Native Control push_input, focus/foreground Escape order, three fixed profiles, pointer/keyboard blocking, continuing display clock and temporary ConfigFile round trips. Rendering profile pixels and real SDK delivery remain integration tests."}
    FileAccess.open("res://generated/settings_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SETTINGS_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
