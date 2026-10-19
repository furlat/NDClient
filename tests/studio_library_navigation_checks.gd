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
    check(s.active_case.get("capability")==capability and s.active_case.get("interaction")==interaction,"Displayed recording follows "+capability+" / "+interaction+"; actual "+str(s.active_case.get("id"))+" / "+str(s.active_case.get("capability"))+" / "+str(s.active_case.get("interaction")))
    check(s.active_case.get("id")=="action.hide/lifecycle","Exact selected Hide case is displayed")
    check(s.index.directory==s.active_directory and s.tracks.index.directory==s.active_directory,"World and timeline use the selected recording together")
    check(not s.world.timeline.paused,"Library selection automatically plays its recording")
    check(s.case_picker.get_item_text(s.case_picker.selected)==s.active_case.label,"Header identifies the actual displayed case")
    evidence.append({"case":s.active_case.id,"directory":s.active_directory})
func find_item(item:TreeItem,id:String)->TreeItem:
    if item==null:return null
    var data=item.get_metadata(0)
    if data is Dictionary and (data.get("case",{}).get("id","")==id or (data.get("case",{}).is_empty() and data.capability.id==id)):return item
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
    var local=rect.position+Vector2(minf(65,rect.size.x*.5),rect.size.y*.5)
    # Native Tree scrolling/layout publishes after the request. Click its
    # actual visible geometry, not the previous layout at the new row index.
    var deadline=Time.get_ticks_msec()+2000
    while panel.tree.get_item_at_position(local)!=item and Time.get_ticks_msec()<deadline:
        await process_frame
        rect=panel.tree.get_item_area_rect(item,column)
        local=rect.position+Vector2(minf(65,rect.size.x*.5),rect.size.y*.5)
    check(panel.tree.get_item_at_position(local)==item,"Pointer geometry identifies the intended current Library item: "+id)
    var at=panel.tree.global_position+local
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at
        panel.push_input(event,true)
    await process_frame
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
    var s=Studio.new();root.add_child(s)
    if not await settle(s):await finish(s);return
    var hide:Dictionary={}
    for record in s.case_records:
        if record.id=="action.hide/lifecycle":hide=record;break
    check(not hide.is_empty() and hide.ready,"Current Library supplies original Hide lifecycle")
    if hide.is_empty():await finish(s);return
    await choose(s.capability_picker,"Actions")
    var started=requested(s);check(started,"Choosing Actions starts its first real case without a third click")
    if started and await settle(s):
        check(s.active_case.capability=="Actions","Category selection publishes an actual action recording")
    await choose(s.case_picker,hide.label)
    started=requested(s);check(started,"Choosing Hide starts its exact current recording")
    if started and await settle(s):selection(s,hide.capability,hide.interaction)
    s._show_study_library()
    var panel=s.study_library
    check(not panel.report.is_empty(),"Full current authoring catalog is ready")
    var unrecorded:Dictionary={}
    for entry in panel.report.entries:
        if entry.cases.is_empty() and entry.scenario_status=="missing":unrecorded=entry;break
    check(not unrecorded.is_empty(),"Catalog exposes genuine unrecorded capabilities")
    var retained=s.active_directory
    if not unrecorded.is_empty():
        await click_tree(panel,unrecorded.id)
        check(panel.visible and panel.open_button.disabled,"Unrecorded capability exposes its gap and keeps Library open")
        check(s.active_directory==retained and not requested(s),"Unrecorded capability cannot play an unrelated recording")
    await click_tree(panel,hide.id,1)
    started=requested(s);check(started,"Single-click current Library case opens its recording, including status column")
    if started and await settle(s):
        selection(s,hide.capability,hide.interaction)
        check(s.study_scenario.get("id")==hide.id and not panel.visible,"Actual study and scene publish together and Library closes")
        s._show_study_library();await process_frame
        check(panel.visible and not requested(s),"Reopening Library does not trigger playback")
        await click_tree(panel,"action.hide")
        check(requested(s),"Clicking the same recorded case reopens it")
        if requested(s) and await settle(s):
            selection(s,hide.capability,hide.interaction)
            check(s.world.timeline.display_ms<100,"Reselecting starts from the actual initial state")
    await choose(s.capability_picker,"Spells")
    await choose(s.capability_picker,"Actions")
    await choose(s.case_picker,hide.label)
    if requested(s) and await settle(s):selection(s,hide.capability,hide.interaction)
    else:check(false,"Rapid Library navigation submits the final case")
    s.world.timeline.paused=true
    for _i in 5:await process_frame
    check(s.loader==null and s.pending_directory.is_empty(),"Header publication cannot issue another case load")
    var retained_world=s.world;retained=s.active_directory
    await choose(s.capability_picker,"Spells")
    var missing_category=""
    for i in s.capability_picker.item_count:
        if s.capability_picker.get_item_text(i).ends_with(" · unrecorded"):missing_category=s.capability_picker.get_item_text(i);break
    check(not missing_category.is_empty(),"Browser retains explicit categories without recordings")
    if not missing_category.is_empty():
        await choose(s.capability_picker,missing_category)
        if await settle(s):
            check(s.world==retained_world and s.active_directory==retained,"Unrecorded final intent cancels an older recorded switch")
            check(s.case_picker.disabled and s.status.text.contains("No recording"),"Unrecorded selection remains explicit after worker cancellation")
            check(not s.perspective_picker.disabled,"Retained recording's faction selector remains usable")
    check(s.world.presentation_errors.is_empty(),"Library switching has no presentation errors")
    await finish(s)
func finish(s:Control)->void:
    s.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Native OptionButton keyboard and Library Tree pointer input; recorded/unrecorded selection, actual world/timeline identity, autoplay and rapid navigation."}
    FileAccess.open("res://generated/studio_library_navigation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIBRARY_NAV ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
