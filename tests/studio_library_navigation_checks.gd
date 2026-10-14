extends SceneTree
## Native Library controls must switch the actual recorded world and timeline.
const Studio=preload("res://studio/studio.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("LIBRARY_NAV_FAIL ",label)
func ready(s:Control)->bool:
    return not s.index.is_empty() and s.loader==null and (s.seeker==null or s.preparing_loop) and (not s.installing or s.preparing_loop) and s.requested_seek<0
func settle(s:Control)->bool:
    var deadline=Time.get_ticks_msec()+90000
    while not ready(s) and Time.get_ticks_msec()<deadline:await process_frame
    check(ready(s),"Requested Library selection becomes ready: "+s.status.text)
    return ready(s)
func choose(picker:OptionButton,text:String)->void:
    var choice=-1
    for i in picker.item_count:
        if picker.get_item_text(i)==text:choice=i;break
    check(choice>=0,"Native menu contains "+text)
    if choice<0:return
    picker.show_popup();await process_frame
    var popup=picker.get_popup();popup.set_focused_item(choice)
    var key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true
    # Embedded window routing reaches PopupMenu's native window input handler;
    # pushing directly to its viewport would bypass menu keyboard handling.
    root.push_input(key,true)
    key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;root.push_input(key,true)
    await process_frame
    check(picker.selected==choice,"Native menu accepts "+text)
func requested(s:Control)->bool:
    return s.loader!=null or not s.pending_directory.is_empty() or not s.pending_index.is_empty() or s.installing
func selection(s:Control,capability:String,interaction:String)->void:
    check(s.active_case.get("capability")==capability and s.active_case.get("interaction")==interaction,"Displayed recording follows "+capability+" / "+interaction)
    check(s.index.directory==s.active_directory and s.tracks.index.directory==s.active_directory,"World and timeline use the selected recording together")
    check(not s.world.timeline.paused,"Library selection automatically plays its recording")
    check(s.case_picker.get_item_text(s.case_picker.selected)==s.active_case.label,"Header identifies the actual displayed case")
    evidence.append({"case":s.active_case.id,"directory":s.active_directory})
func find_item(item:TreeItem,id:String)->TreeItem:
    if item==null:return null
    var data=item.get_metadata(0)
    if data is Dictionary and (data.scenario.get("id","")==id or (data.scenario.is_empty() and data.capability.id==id)):return item
    for child in item.get_children():
        var found=find_item(child,id)
        if found!=null:return found
    return null
func click_tree(panel:Window,id:String,column:int=0)->void:
    var item=find_item(panel.tree.get_root(),id)
    check(item!=null,"Library contains "+id)
    if item==null:return
    var parent=item.get_parent()
    while parent!=null:parent.collapsed=false;parent=parent.get_parent()
    panel.tree.scroll_to_item(item,true);await process_frame
    var rect=panel.tree.get_item_area_rect(item,column)
    var at=panel.tree.global_position+rect.position+Vector2(minf(65,rect.size.x*.5),rect.size.y*.5)
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at
        panel.push_input(event,true)
    await process_frame
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
    var s=Studio.new();root.add_child(s)
    if not await settle(s):await finish(s);return
    await choose(s.capability_picker,"Hide")
    var started=requested(s);check(started,"Choosing Hide starts its first real recording without a third menu click")
    if started and await settle(s):selection(s,"Hide","Apply / move / attack")
    await choose(s.interaction_picker,"Illumination / reveal")
    started=requested(s);check(started,"Choosing Hide illumination switches recording without a third menu click")
    if started and await settle(s):selection(s,"Hide","Illumination / reveal")
    s._show_study_library()
    var panel=s.study_library;var deadline=Time.get_ticks_msec()+60000
    while not panel.is_prepared() and Time.get_ticks_msec()<deadline:await process_frame
    check(panel.is_prepared(),"Full Library catalog is ready")
    var retained=s.active_directory
    await click_tree(panel,"base.DS02")
    check(panel.visible and panel.selected_scenario.get("id")=="base.DS02" and panel.open_button.disabled,"Unrecorded row exposes its gap and keeps Library open")
    check(s.active_directory==retained and not requested(s),"Unrecorded study never plays an unrelated recording")
    await click_tree(panel,"base.HD01",1)
    started=requested(s);check(started,"Single-click recorded Library row opens its exact recording, including status column")
    if started and await settle(s):
        selection(s,"Hide","Apply / move / attack")
        check(s.study_scenario.get("id")=="base.HD01" and not panel.visible,"Selected study and scene publish together and Library closes")
        s._show_study_library();deadline=Time.get_ticks_msec()+60000
        while not panel.is_prepared() and Time.get_ticks_msec()<deadline:await process_frame
        check(panel.visible and panel.selected_scenario.get("id")=="base.HD01" and not requested(s),"Reopening Library restores selection without triggering playback")
        await click_tree(panel,"base.HD01")
        check(requested(s),"Clicking the already highlighted study opens it again")
        if requested(s) and await settle(s):
            selection(s,"Hide","Apply / move / attack")
            check(s.world.timeline.display_ms<100,"Reselecting the same recording starts from its initial state")
    # A later menu intent must cancel the earlier one, without label-sync loads.
    await choose(s.capability_picker,"Attack")
    await choose(s.capability_picker,"Hide")
    await choose(s.interaction_picker,"Illumination / reveal")
    if requested(s) and await settle(s):selection(s,"Hide","Illumination / reveal")
    else:check(false,"Rapid Library navigation submits the final selected case")
    s.world.timeline.paused=true
    for _i in 5:await process_frame
    check(s.loader==null and s.pending_directory.is_empty(),"Publishing header labels does not issue another case load")
    var retained_world=s.world;retained=s.active_directory
    await choose(s.capability_picker,"Attack")
    await choose(s.capability_picker,"Combined regression · unrecorded")
    if await settle(s):
        check(s.world==retained_world and s.active_directory==retained,"Unrecorded final intent cancels the earlier recorded switch")
        check(s.case_picker.disabled and s.status.text.contains("No recording") and s.capability_picker.get_item_text(s.capability_picker.selected).begins_with("Combined regression"),"Unrecorded selection remains explicit after canceled worker completes")
        check(not s.perspective_picker.disabled,"Retained recording's faction selector becomes usable after cancellation")
    check(s.world.presentation_errors.is_empty(),"Library switching has no presentation errors")
    await finish(s)
func finish(s:Control)->void:
    s.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Native OptionButton keyboard and Library Tree pointer input; recorded/unrecorded selection, actual world/timeline identity, autoplay and rapid navigation."}
    FileAccess.open("res://generated/studio_library_navigation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIBRARY_NAV ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
