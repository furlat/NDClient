extends SceneTree
## Current catalog -> real Library interactions; no synthetic server events.
const Library=preload("res://studio/study_library.gd")
const Cases=preload("res://studio/case_library.gd")
var checks=0
var failures:Array=[]
var captures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("STUDY_LIBRARY_FAIL ",label)
func prepared(panel:Window)->bool:
    var deadline=Time.get_ticks_msec()+60000
    while not panel.is_prepared() and Time.get_ticks_msec()<deadline:await process_frame
    check(panel.is_prepared() and panel.error.is_empty(),"Library publishes complete catalog: "+panel.error)
    return panel.is_prepared()
func find_study(panel:Window,id:String)->Array:
    for capability in panel.report.get("capabilities",[]):
        for scenario in capability.scenarios:
            if scenario.id==id:return [capability,scenario]
    return []
func capture(panel:Window,name:String)->void:
    if DisplayServer.get_name()=="headless":return
    await process_frame;await RenderingServer.frame_post_draw
    var path="res://.captures/studio/study-library/"+name+".png"
    panel.get_texture().get_image().save_png(path);captures.append(path)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    root.size=Vector2i(1280,720)
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/study-library")
    var panel=Library.new();root.add_child(panel)
    panel.open({},Cases.read());panel.open({},Cases.read())
    if not await prepared(panel):await finish(panel);return
    check(panel.installed_generation==panel.generation,"Only latest request is published")
    check(panel.report.counts.scenarios>0 and panel.report.counts.study_needed>0,"Authored studies and capabilities without a study coexist")
    var missing=find_study(panel,"base.DS02")
    check(not missing.is_empty(),"Required before/after allowance study is independently discoverable")
    if not missing.is_empty():
        panel.show_selection(missing[0],missing[1])
        check(panel.open_button.disabled and panel.recording_picker.disabled,"Unrecorded study cannot open an unrelated replay")
        check(not panel.sequence.text.is_empty() and panel.expectations.get_root().get_child_count()>0,"Unimplemented/unrecorded study exposes sequence and participant expectations")
        check(panel.recording_state(missing[1])=="Needs recording","Missing recording is not confused with missing effect")
        await capture(panel,"unrecorded")
    var partial=find_study(panel,"base.OA04")
    check(not partial.is_empty(),"Causal multi-participant study is discoverable")
    if not partial.is_empty():
        panel.show_selection(partial[0],partial[1])
        check(not panel.open_button.disabled and panel.recording_state(partial[1])=="Partial recording","Related partial recording remains usable without qualifying whole sequence")
        check(not panel.recording_note.text.is_empty(),"Partial recording explains its actual coverage gap")
        await capture(panel,"partial")
    panel.search.text="no-capability-matches-this-query";panel.search.text_changed.emit(panel.search.text)
    await process_frame
    if not await prepared(panel):await finish(panel);return
    check(panel.filtered.is_empty() and panel.selected_scenario.is_empty() and panel.open_button.disabled,"Filtering away selection clears stale details and replay action")
    panel.search.text="";panel.search.text_changed.emit("")
    panel.kind_picker.select(2);panel.kind_picker.item_selected.emit(2)
    await process_frame
    if not await prepared(panel):await finish(panel);return
    check(not panel.filtered.is_empty() and panel.filtered.all(func(c):return c.kind=="Spell"),"Spell catalog is accessible before models or recordings exist")
    var studyless=panel.filtered.filter(func(c):return c.scenarios.is_empty())
    check(not studyless.is_empty(),"Unstudied spells remain explicit, not omitted")
    if not studyless.is_empty():
        panel.show_selection(studyless[0],{})
        check(panel.purpose.text.contains("not been authored") and panel.open_button.disabled,"Unstudied capability does not invent a default scenario")
    await capture(panel,"spell-catalog")
    var signals:Array=[]
    panel.recording_selected.connect(func(c,s,r):signals.append({"capability":c.id,"study":s.id,"record":r}))
    if not partial.is_empty():
        panel.show_selection(partial[0],partial[1]);var exact=panel.recording_options[0].record
        panel.open_selected_recording()
        check(signals.size()==1 and signals[0].study==partial[1].id and signals[0].record==exact,"Open emits exact available real recording and selected study independently")
    var spell_records=Cases.read().filter(func(record):return record.has("spell_id"))
    check(spell_records.size()==30,"The finite native spell batch is available through the real Library")
    for record in spell_records:
        var study=find_study(panel,record.id)
        check(not study.is_empty(),"Library exposes the selected real spell sequence: "+record.spell_id)
        if study.is_empty():continue
        panel.show_selection(study[0],study[1])
        check(not panel.open_button.disabled and panel.recording_options.size()==1,"Spell sequence has one exact openable recording: "+record.spell_id)
        var previous=signals.size()
        panel.open_selected_recording()
        check(signals.size()==previous+1 and signals[-1].capability=="spell."+record.spell_id and signals[-1].study==record.id and signals[-1].record==record,"Spell Open recording emits its own server capture: "+record.spell_id)
    await finish(panel)
func finish(panel:Window)->void:
    panel.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"captures":captures,"scope":"Actual catalog and Library interaction: expected sequences, missing/partial recordings, filtering, source inventory and exact recording selection. Does not qualify animation models."}
    FileAccess.open("res://generated/studio_study_library_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDY_LIBRARY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
