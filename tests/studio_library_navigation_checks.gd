extends SceneTree
## Native Library controls must switch the actual recorded world and timeline.
const Studio=preload("res://studio/studio.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Library=preload("res://studio/case_library.gd")
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
    var original:Array=s.case_records.filter(func(record):return record.id==s.active_case.id)
    check(original.size()==1 and s.active_case.capture_engine==original[0].get("engine",{}) and s.active_case.engine_status==original[0].engine_status,"Native navigation retains this original's actual engine identity and qualification scope")
    evidence.append({"case":s.active_case.id,"directory":s.active_directory,"capture_engine":s.active_case.capture_engine,"engine_status":s.active_case.engine_status})
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
func inspect_failed_prefix(s:Control)->void:
    var original:Dictionary=Fixtures.failed_original("res://tests/fixtures/schema16/event-families/spell.dragons_breath__fire_grant_exhale_end")
    check(not original.is_empty() and not original.ready and original.scenario_status=="failed" and original.engine_status=="historical_or_unverified","Exact preserved failed Dragon original remains failed before inspection, independently of current capture success")
    if original.is_empty():return
    var immutable:PackedByteArray=var_to_bytes(original)
    # The native UI consumes the genuine historical capture as an explicit
    # control. No current index/status or journal bytes are rewritten.
    s.case_records=s.case_records.filter(func(record):return record.id!=original.id)+[original]
    s._show_study_library();var panel:Window=s.study_library
    panel.report=Library.build(Library._read(Library.SERVER_IDS),{}, {"engine":original.engine,"cases":[original]})
    panel._refresh("spell:spell.dragons_breath",original.id)
    await click_tree(panel,original.id)
    check(panel.visible and panel.open_button.disabled and not panel.prefix_button.disabled \
        and not requested(s),"Failed case exposes an explicit prefix action without automatic playback or ready promotion")
    await process_frame
    # Embedded Window input enters through the parent viewport. A mouse move
    # establishes native Button hover; a panel-local button event alone leaves
    # that state unchanged even though Tree's press handling accepts it.
    var at:Vector2=Vector2(panel.position)+panel.prefix_button.get_global_rect().get_center()
    var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
    root.push_input(motion,true);await process_frame
    check(panel.gui_get_hovered_control()==panel.prefix_button,"Native pointer targets the actual failed-prefix action")
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=at;event.global_position=at
        root.push_input(event,true)
    await process_frame
    check(requested(s),"Native pointer activation opens the selected failed case's exact journal")
    if not requested(s) or not await settle(s):return
    check(s.active_case.id==original.id and not s.active_case.ready and s.active_case.scenario_status=="failed" \
        and s.study_scenario.inspection_mode=="failed_prefix" and s.status.text.contains("Failed recording prefix"),"Published scene/header/inspection retain original failed-prefix status")
    check(s.index.directory==original.perspectives[0].journal and s.tracks.index.directory==s.index.directory,"Failed prefix uses the actual selected journal for world and timeline")
    var receivers:Array=s.index.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")=="bg3-36/dragons-breath/fire_native_receiver")
    check(receivers.size()==1,"Failed lifecycle prefix exposes its actual accepted Exhale receiver")
    if receivers.size()==1:
        var row:Dictionary=receivers[0]
        s._seek((float(row.start_ms)+float(row.end_ms))*.5)
        if await settle(s):
            s._show_inspector(row)
            check(s.inspector_text.text.contains("damage_event") and s.inspector_text.text.contains("current native submission/input diagnostics"),"Actual receiver inspection shows current exact channel diagnostics")
            check(row.coverage.rendered=="not_witnessed","Inspecting a supported failed-prefix phase does not promote recorded pixel qualification")
            s.inspector.hide()
    s.select_perspective("blue")
    if await settle(s):
        check(s.active_perspective=="blue" and s.active_case.id==original.id and not s.active_case.ready \
            and s.status.text.contains("Failed recording prefix"),"Independent faction switch preserves the actual failed original and explicit inspection scope")
        s._seek(0.0)
        if await settle(s):check(s.status.text.contains("Failed recording prefix"),"Backward seek keeps failed-prefix scope visible")
    check(var_to_bytes(original)==immutable,"Prefix navigation leaves the actual case failure/qualification unchanged")
    evidence.append({"case":original.id,"scope":"failed_prefix_inspection","scenario_status":original.scenario_status,
        "ready":original.ready,"recording_failure":original.reason,"directory":s.active_directory})
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
    var s=Studio.new();root.add_child(s)
    if not await settle(s):await finish(s);return
    var hide:Dictionary={}
    for record in s.case_records:
        if record.id=="action.hide/lifecycle":hide=record;break
    check(not hide.is_empty() and hide.ready,"Library supplies an admitted original Hide lifecycle")
    if hide.is_empty():await finish(s);return
    await choose(s.capability_picker,"Actions")
    var started=requested(s);check(started,"Choosing Actions starts its first real case without a third click")
    if started and await settle(s):
        check(s.active_case.capability=="Actions","Category selection publishes an actual action recording")
    await choose(s.case_picker,hide.label)
    started=requested(s);check(started,"Choosing Hide starts its exact admitted original recording")
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
    await inspect_failed_prefix(s)
    await finish(s)
func finish(s:Control)->void:
    s.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Native OptionButton keyboard and Library Tree pointer input; recorded/unrecorded selection, actual world/timeline identity, autoplay and rapid navigation."}
    FileAccess.open("res://generated/studio_library_navigation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIBRARY_NAV ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
