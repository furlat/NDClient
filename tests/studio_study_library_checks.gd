extends SceneTree
## Current source/scenario/provider/review browser, original real cases and
## exact tree/filter/open interactions. Superseded generation/show_selection
## and legacy StudyCatalog prose widgets are not current browser contracts.
const Library=preload("res://studio/study_library.gd")
const Cases=preload("res://studio/case_library.gd")
var checks:int=0
var failures:Array=[]
var captures:Array=[]
var signals:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("STUDY_LIBRARY_FAIL ",label)
func tree_rows(panel:Window)->Array:
    var result:Array=[];var pending:Array=[panel.tree.get_root()]
    while not pending.is_empty():
        var item:TreeItem=pending.pop_back()
        if item==null:continue
        var metadata:Variant=item.get_metadata(0)
        if metadata is Dictionary:result.append({"item":item,"metadata":metadata})
        var child:TreeItem=item.get_first_child()
        while child!=null:pending.append(child);child=child.get_next()
    return result
func choose(panel:Window,entry:String,case_id:String="")->void:
    var found:Array=tree_rows(panel).filter(func(row):return row.metadata.capability.id==entry and str(row.metadata.case.get("id",""))==case_id)
    check(found.size()==1,"Exactly one current browser selection: "+entry+" / "+case_id)
    if found.size()==1:
        found[0].item.select(0)
func capture(panel:Window,name:String)->void:
    if DisplayServer.get_name()=="headless":return
    await process_frame;await RenderingServer.frame_post_draw
    var path:String="res://.captures/studio/study-library/"+name+".png"
    panel.get_texture().get_image().save_png(path);captures.append(path)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1280,720)
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/study-library")
    var panel=Library.new();root.add_child(panel)
    panel.recording_selected.connect(func(capability,scenario,record):signals.append({"capability":capability.id,"scenario":scenario,"record":record}))
    var records:Array=Cases.read()
    panel.open({},records);panel.open({},records)
    check(not panel.report.is_empty() and not panel.rebuilding,"Synchronous current catalog is completely published on open")
    var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Cases.SERVER_IDS))
    var source:Resource=load(Cases.ABILITIES)
    var expected:Dictionary={}
    for kind in snapshot.ids:
        for id in snapshot.ids[kind]:expected[str(kind)+":"+str(id)]=true
    # Source-only class features must not vanish merely because the backend
    # inventory has not exported them. These are actual declared resources.
    for section in ["spells","conditions","actions"]:
        for id in source.sections.get(section,{}):
            var kind:String=str(id).get_slice(".",0)
            if section=="conditions" and not Cases.CATEGORY.has(kind):
                kind="condition"
                var unbound:Dictionary=panel.report.by_key.get("condition:"+str(id),{})
                check(unbound.get("category")=="Conditions" and unbound.get("inventory_origin")=="typed_source" and unbound.get("engine_inventory")=="not_listed",
                    "An unbound declared condition stays discoverable without inventing an engine kind or availability: "+str(id))
            expected[kind+":"+str(id)]=true
    for key in expected:check(panel.report.by_key.has(key),"Current declared capability is discoverable: "+key)
    var rows:Array=tree_rows(panel)
    var capabilities:Array=rows.filter(func(row):return row.metadata.case.is_empty())
    check(capabilities.size()==panel.report.entries.size(),"Every catalog capability has one actual selectable tree row")
    for row in capabilities:
        var entry:Dictionary=row.metadata.capability
        check(entry.has("source_status") and entry.has("scenario_status") and entry.has("presentation_status") and entry.has("approval_status"),"Coverage facts remain separate for "+entry.id)
        check(entry.approval_status=="needs_review","All current artwork awaits human review: "+entry.id)
    var missing:Array=capabilities.filter(func(row):return row.metadata.capability.cases.is_empty())
    check(not missing.is_empty(),"Capabilities lacking a recording stay visible")
    if not missing.is_empty():
        var entry:Dictionary=missing[0].metadata.capability
        choose(panel,entry.id)
        check(panel.open_button.disabled and panel.recording_picker.disabled and panel.recording_options.is_empty(),"Unrecorded capability cannot open an unrelated replay")
        check(panel.detail.text.contains("Art:") and panel.detail.text.contains("Scenario:") and panel.detail.text.contains("Presentation:") and panel.detail.text.contains("Review:"),"Unrecorded capability still exposes all four coverage facts")
        await capture(panel,"unrecorded")
    var failed:Array=rows.filter(func(row):return not row.metadata.case.is_empty() and not row.metadata.case.ready and not str(row.metadata.case.get("reason","")).is_empty())
    check(not failed.is_empty(),"Current failed/partial original recordings remain explicit")
    if not failed.is_empty():
        var row:Dictionary=failed[0]
        choose(panel,row.metadata.capability.id,row.metadata.case.id)
        check(panel.open_button.disabled and panel.recording_options.is_empty(),"Failed recording cannot substitute a different available replay")
        check(panel.detail.text.contains(str(row.metadata.case.reason)),"Failed recording explains its actual capture gap")
    panel.search.text="no-capability-matches-this-query";panel.search.text_changed.emit(panel.search.text)
    check(tree_rows(panel).is_empty() and panel.selected_capability.is_empty() and panel.selected_scenario.is_empty() and panel.open_button.disabled,"Filtering away selection clears stale details and replay action")
    panel.search.text="";panel.search.text_changed.emit("")
    var spells:int=-1
    for index in panel.kind_picker.item_count:
        if panel.kind_picker.get_item_text(index)=="Spells":spells=index
    check(spells>=0,"Actual Spells category is available")
    if spells>=0:
        panel.kind_picker.select(spells);panel.kind_picker.item_selected.emit(spells)
        var filtered:Array=tree_rows(panel).filter(func(row):return row.metadata.case.is_empty())
        check(not filtered.is_empty() and filtered.all(func(row):return row.metadata.capability.kind=="spell"),"Spell filter exposes actual spell capabilities only")
        await capture(panel,"spell-catalog")
    panel.kind_picker.select(0);panel.kind_picker.item_selected.emit(0)
    var available:Array=tree_rows(panel).filter(func(row):return not row.metadata.case.is_empty() and row.metadata.case.ready)
    check(not available.is_empty(),"Actual original recorded studies are selectable")
    # One original per current recorded spell, plus a non-spell interaction.
    var seen:Dictionary={};var opened:int=0
    for row in available:
        var entry:Dictionary=row.metadata.capability;var record:Dictionary=row.metadata.case
        if seen.has(entry.id):continue
        if entry.kind!="spell" and opened>0:continue
        seen[entry.id]=true
        var previous:int=signals.size()
        choose(panel,entry.id,record.id)
        check(signals.size()>previous,"Selecting an available actual case opens its recording: "+record.id)
        if signals.size()<=previous:continue
        var actual:Dictionary=signals[-1]
        check(actual.capability==entry.id and actual.record==record and actual.scenario.id==record.id,"Open emits exact capability, scenario and original recording: "+record.id)
        check(actual.record.perspectives==record.perspectives,"Both original audience choices are retained without a fabricated combined stream")
        opened+=1
    check(opened>30,"Current browser exposes more than the retired thirty-spell batch")
    await finish(panel)
func finish(panel:Window)->void:
    panel.queue_free();await process_frame;await process_frame
    var report:Dictionary={"checks":checks,"failures":failures,"captures":captures,
        "scope":"Complete current declared source/capability inventory, actual browser tree/filter/exact recording selection and separate source/scenario/provider/approval facts. No animation or art-acceptance claim. Removed legacy prose/generation widgets are not reintroduced."}
    FileAccess.open("res://generated/studio_study_library_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDY_LIBRARY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
