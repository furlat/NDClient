extends SceneTree
## Native menu input during actual recorded loop preparation/publication.
const Studio=preload("res://studio/studio.gd")
const Settings=preload("res://presentation/render_settings.gd")
var checks=0
var failures:Array=[]
var saved:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("STUDIO_PREFERENCE_FAIL ",label)
func preserve(path:String)->void:
    saved[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
func restore(path:String)->void:
    if saved[path]==null:DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    else:FileAccess.open(path,FileAccess.WRITE).store_buffer(saved[path])
func ready(studio:Control)->bool:
    return not studio.index.is_empty() and studio.loader==null and (studio.seeker==null or studio.preparing_loop) and (not studio.installing or studio.preparing_loop) and studio.requested_seek<0
func enter(menu:PopupMenu)->void:
    for pressed in [true,false]:
        var event=InputEventKey.new();event.keycode=KEY_ENTER;event.physical_keycode=KEY_ENTER;event.pressed=pressed
        root.push_input(event,true)
func run()->void:
    preserve(Studio.CONFIG);preserve(Settings.PATH)
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,720)
    root.gui_embed_subwindows=true
    var studio=Studio.new();root.add_child(studio)
    var deadline=Time.get_ticks_msec()+45000
    while not ready(studio) and Time.get_ticks_msec()<deadline:await process_frame
    check(ready(studio),"Explicit recording reaches a prepared displayed scene")
    if not ready(studio):await finish(studio);return
    var bodies=studio.index.rows.filter(func(row):return row.kind=="body" and row.end_ms-row.start_ms>100)
    check(not bodies.is_empty(),"Recording contains an actual playable body interval")
    if bodies.is_empty():await finish(studio);return
    studio.world.playback_speed=.25
    studio.tracks.clip_requested.emit(bodies[0])
    for iteration in 2:
        deadline=Time.get_ticks_msec()+15000
        while not (studio.preparing_loop and studio.installing and studio.candidate_world!=null) and Time.get_ticks_msec()<deadline:await process_frame
        var prepared=studio.preparing_loop and studio.installing and studio.candidate_world!=null
        check(prepared,"Loop prepares a private next world: "+str(iteration))
        if not prepared:break
        var previous=studio.world
        var selected:bool=not previous.native_spell_hit_material
        studio.diagnostic_menu.popup()
        await process_frame
        studio.diagnostic_menu.set_focused_item(studio.diagnostic_menu.get_item_index(12))
        check(studio.diagnostic_menu.visible,"Inspect menu is visible before keyboard selection")
        enter(studio.diagnostic_menu)
        check(previous.native_spell_hit_material==selected,"Actual Full spell hit material menu input changes the displayed preference")
        check(Settings.read().native_spell_hit_material==selected,"Menu persists the accepted preference")
        # Restore user's disk values immediately; the accepted in-session value
        # must still survive publication and the next reused pane.
        restore(Settings.PATH)
        deadline=Time.get_ticks_msec()+15000
        while studio.world==previous and Time.get_ticks_msec()<deadline:await process_frame
        check(studio.world!=previous,"Prepared loop publishes after the setting change")
        check(studio.world.native_spell_hit_material==selected,"Published world preserves the latest accepted preference")
        check(studio.world.presentation_errors.is_empty(),"Publication reports no native preparation/render errors")
    await finish(studio)
func finish(studio:Control)->void:
    studio.queue_free();await process_frame;await process_frame
    restore(Settings.PATH);restore(Studio.CONFIG)
    var report={"checks":checks,"failures":failures,"scope":"Real Studio journal, clip-request UI boundary and native PopupMenu keyboard input; latest hit-material preference survives two actual prepared loop publications. User settings/layout bytes restored. No appearance or frame-time claim."}
    FileAccess.open("res://generated/studio_render_preference_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_RENDER_PREFERENCE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
