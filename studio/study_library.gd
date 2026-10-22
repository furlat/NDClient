extends Window
## Authoring IDs and their actual current cases. One compact browser; production owns playback.
signal recording_selected(capability:Dictionary,scenario:Dictionary,record:Dictionary)
signal recording_unavailable
signal failed_prefix_selected(capability:Dictionary,scenario:Dictionary,record:Dictionary,perspective_id:String)
const Library=preload("res://studio/case_library.gd")
const Studies=preload("res://studio/study_catalog.gd")
const FILTERS={"All statuses":"","Recorded":"recorded","No recording":"missing_recording","Failed / stale":"recording_failure","Evidence linked":"evidence","No output evidence":"unwitnessed","Source gaps":"source_gap","Awaiting art review":"needs_review","Rejected art":"rejected","Current engine/package receipts":"current_evidence","Matching package receipts":"package_evidence","Historical / unknown receipts":"historical_evidence","Reader safety receipts":"reader_evidence","Issued-command receipts":"command_evidence","Audio receipts":"audio_evidence","Described studies":"described_studies","Studies without playable originals":"unlinked_studies"}
var report:Dictionary={}
var search:LineEdit
var kind_picker:OptionButton
var status_picker:OptionButton
var tree:Tree
var summary:Label
var detail:Label
var recording_picker:OptionButton
var open_button:Button
var prefix_button:Button
var prefix_record:Dictionary={}
var prefix_perspectives:Array=[]
var selected_capability:Dictionary={}
var selected_scenario:Dictionary={}
var selected_study:Dictionary={}
var recording_options:Array=[]
var rebuilding=false
# Opus worker/generation ownership and bounded Tree publication, adapted only
# to the current exact CaseLibrary report and five existing columns.
var worker:Thread
var request:Dictionary={}
var generation=0
var installed_generation=0
var refresh_pending=false
var pending_rows:Array=[]
var row_cursor=0
var preferred_id=""
var preferred_scenario=""
var published_rows:Dictionary={}
var preferred_item:TreeItem
var error=""
func _ready()->void:
    title="Studio library";size=Vector2i(1120,640);min_size=Vector2i(820,420);close_requested.connect(hide)
    var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
    for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,10)
    var box=VBoxContainer.new();margin.add_child(box);var tools=HBoxContainer.new();box.add_child(tools)
    kind_picker=OptionButton.new();kind_picker.add_item("All")
    for category in Library.CAPABILITIES:kind_picker.add_item(category)
    tools.add_child(kind_picker);kind_picker.item_selected.connect(func(_choice):_refresh())
    status_picker=OptionButton.new();status_picker.fit_to_longest_item=false;status_picker.custom_minimum_size.x=155;tools.add_child(status_picker)
    for label in FILTERS:status_picker.add_item(label);status_picker.set_item_metadata(status_picker.item_count-1,FILTERS[label])
    status_picker.item_selected.connect(func(_choice):_refresh())
    search=LineEdit.new();search.placeholder_text="Find a spell, condition, action or object";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tools.add_child(search);search.text_changed.connect(func(_value):_refresh())
    var reload=Button.new();reload.text="Refresh";tools.add_child(reload);reload.pressed.connect(_reload_catalog)
    summary=Label.new();summary.add_theme_font_size_override("font_size",12);box.add_child(summary)
    tree=Tree.new();tree.hide_root=true;tree.columns=5;tree.column_titles_visible=true;tree.select_mode=Tree.SELECT_ROW;tree.allow_reselect=true;tree.size_flags_vertical=Control.SIZE_EXPAND_FILL
    for column in 5:tree.set_column_title(column,["Capability / case","Source","Scenario","Output evidence","Art review"][column]);tree.set_column_expand_ratio(column,4 if column==0 else 2)
    box.add_child(tree)
    tree.item_selected.connect(_selected);tree.item_activated.connect(_open)
    detail=Label.new();detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",12);box.add_child(detail)
    var bottom=HBoxContainer.new();box.add_child(bottom);recording_picker=OptionButton.new();recording_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;recording_picker.fit_to_longest_item=false;recording_picker.clip_text=true;bottom.add_child(recording_picker)
    recording_picker.item_selected.connect(func(_choice):_open())
    var copy_button=Button.new();copy_button.text="Copy details";bottom.add_child(copy_button);copy_button.pressed.connect(copy_study)
    open_button=Button.new();open_button.text="Play";open_button.disabled=true;bottom.add_child(open_button);open_button.pressed.connect(_open)
    prefix_button=Button.new();prefix_button.text="Inspect failed prefix";prefix_button.disabled=true;bottom.add_child(prefix_button);prefix_button.pressed.connect(_inspect_prefix)
func open(_cache:Dictionary,_records:Array,preferred:String="",scenario:String="")->void:
    search.set_block_signals(true);search.text="";search.set_block_signals(false)
    kind_picker.select(0);status_picker.select(0)
    _request_catalog(preferred,scenario)
    popup_centered(Vector2i(mini(1120,DisplayServer.window_get_size().x-40),mini(640,DisplayServer.window_get_size().y-40)))

func _request_catalog(preferred:String,scenario:String)->void:
    generation+=1;preferred_id=preferred;preferred_scenario=scenario
    request={"generation":generation}
    report={};error="";pending_rows=[];row_cursor=0;published_rows={};preferred_item=null
    tree.clear();recording_options=[];recording_picker.clear();selected_capability={};selected_scenario={};selected_study={}
    open_button.disabled=true;prefix_button.disabled=true;prefix_record={};prefix_perspectives=[];detail.text=""
    summary.text="Reading capability definitions, cases and retained evidence…"
    _start()

func _reload_catalog()->void:
    var preferred:String="";var scenario:String=""
    if tree.get_selected()!=null:
        var selected:Variant=tree.get_selected().get_metadata(0)
        if selected is Dictionary:
            preferred=str(selected.capability.get("key",selected.capability.id))
            scenario=str(selected.case.get("id",selected.get("study",{}).get("id","")))
    _request_catalog(preferred,scenario)

func _start()->void:
    if worker!=null or request.is_empty():return
    var job:Dictionary=request;request={};worker=Thread.new()
    var started:Error=worker.start(_build.bind(job))
    if started!=OK:
        worker=null
        if job.get("stage","base")=="methods":
            report.study_state="unavailable"
            report.study_errors=["Authored methods could not start: "+error_string(started)]
            refresh_pending=true
        else:error=error_string(started);summary.text=error

static func _build(job:Dictionary)->Dictionary:
    var stage:String=job.get("stage","base")
    if stage=="base":
        var base:Dictionary=Library.catalog();base.study_state="loading"
        return {"generation":job.generation,"stage":stage,"report":base}
    # Only the worker's entry shells are enriched. Actual case/receipt records
    # remain read-only, and every entry lookup must point at the new shell.
    var original:Dictionary=job.report
    var catalog:Dictionary=original.duplicate()
    catalog.entries=[];catalog.by_key={};catalog.categories={}
    for previous in original.entries:
        var entry:Dictionary=previous.duplicate()
        catalog.entries.append(entry);catalog.by_key[entry.key]=entry
    for category in original.categories:
        var entries:Array=[]
        for previous in original.categories[category]:entries.append(catalog.by_key[previous.key])
        catalog.categories[category]=entries
    Studies.join_library(catalog,Studies.build({},catalog.records))
    catalog.study_state="complete"
    return {"generation":job.generation,"stage":stage,"report":catalog}

func _process(_delta:float)->void:
    if worker!=null and not worker.is_alive():
        var result:Dictionary=worker.wait_to_finish();worker=null
        if result.generation==generation:
            report=result.report;installed_generation=generation;refresh_pending=true
            if result.stage=="base":request={"generation":generation,"stage":"methods","report":report}
        _start()
    if refresh_pending and installed_generation==generation:
        refresh_pending=false;_filter()
    var started:int=Time.get_ticks_usec();var count:int=0
    rebuilding=true
    while row_cursor<pending_rows.size() and count<24 and Time.get_ticks_usec()-started<2000:
        var entry:Dictionary=pending_rows[row_cursor];row_cursor+=1;count+=1
        _publish_row(entry)
    rebuilding=false
    if row_cursor==pending_rows.size() and not pending_rows.is_empty():
        pending_rows=[];row_cursor=0
        if preferred_item!=null:
            var ancestor:TreeItem=preferred_item.get_parent()
            while ancestor!=null:ancestor.collapsed=false;ancestor=ancestor.get_parent()
            rebuilding=true;preferred_item.select(0);rebuilding=false
            _selected(false);tree.scroll_to_item(preferred_item)

func is_prepared()->bool:
    return not report.is_empty() and installed_generation==generation and worker==null and request.is_empty() and pending_rows.is_empty() and not refresh_pending

func _refresh(preferred:String="",scenario:String="")->void:
    if preferred.is_empty() and tree.get_selected()!=null:
        var previous:Variant=tree.get_selected().get_metadata(0)
        if previous is Dictionary:
            preferred=str(previous.capability.get("key",previous.capability.id));scenario=str(previous.case.get("id",previous.get("study",{}).get("id","")))
    preferred_id=preferred;preferred_scenario=scenario;refresh_pending=true

func _filter()->void:
    rebuilding=true;tree.clear();tree.create_item();pending_rows=[];row_cursor=0;published_rows={};preferred_item=null
    var query:String=search.text.strip_edges().to_lower()
    var category:String=kind_picker.get_item_text(kind_picker.selected)
    selected_capability={};selected_scenario={};selected_study={};recording_options=[];recording_picker.clear()
    open_button.disabled=true;prefix_button.disabled=true;prefix_record={};prefix_perspectives=[];detail.text=""
    var categories:Dictionary={};var groups:Dictionary={}
    var count:int=0;var recorded:int=0;var evidenced:int=0;var awaiting_review:int=0
    for entry in report.get("entries",[]):
        if not Library.matches(entry,query,category if kind_picker.selected>0 else "",str(status_picker.get_item_metadata(status_picker.selected))):continue
        var category_key:String="category:"+str(entry.category)
        if not categories.has(category_key):
            categories[category_key]=true
            pending_rows.append({"kind":"category","key":category_key,"parent":"","label":entry.category})
        var group_key:String="group:"+str(entry.category)+":"+str(entry.group)
        if not groups.has(group_key):
            groups[group_key]=true
            pending_rows.append({"kind":"group","key":group_key,"parent":category_key,"label":entry.group,
                "collapsed":query.is_empty() and entry.kind!="spell"})
        var capability_key:String="capability:"+str(entry.key)
        pending_rows.append({"kind":"capability","key":capability_key,"parent":group_key,
            "capability":entry,"case":{},"collapsed":query.is_empty()})
        count+=1
        if entry.scenario_status=="recorded":recorded+=1
        if not entry.get("output_witnesses",[]).is_empty():evidenced+=1
        if entry.approval_status=="needs_review":awaiting_review+=1
    summary.text="%d / %d capabilities · %d recorded · %d with linked evidence · %d awaiting art review"%[count,report.get("entries",[]).size(),recorded,evidenced,awaiting_review]
    if report.get("study_state")=="loading":summary.text+=" · authored methods loading"
    if not report.get("study_errors",[]).is_empty():summary.tooltip_text="Study input issues: "+"; ".join(report.study_errors)
    else:summary.tooltip_text=report.get("study_scope","")
    rebuilding=false

func _publish_row(row:Dictionary)->void:
    var parent:TreeItem=published_rows.get(row.parent,tree.get_root())
    var item:TreeItem=tree.create_item(parent);published_rows[row.key]=item
    if row.kind in ["category","group"]:
        item.set_text(0,row.label);item.set_selectable(0,false);item.collapsed=row.get("collapsed",false);return
    var entry:Dictionary=row.capability
    var record:Dictionary=row.case
    var study:Dictionary=row.get("study",{})
    item.set_metadata(0,{"capability":entry,"case":record,"study":study})
    if row.kind=="study":
        item.set_text(0,"Study · "+str(study.label));item.set_text(1,"Described expectations")
        var references:Array=study.get("recordings",[])
        item.set_text(2,"Linked original" if references.any(func(binding):return binding.get("ready",false)) else "Original not playable" if references.any(func(binding):return binding.get("available",false)) else "No linked original")
        item.set_text(3,"Not assessed");item.set_tooltip_text(0,_study_text(study));item.set_tooltip_text(2,_study_text(study))
        if preferred_id in [str(entry.key),str(entry.id)] and study.id==preferred_scenario:preferred_item=item;parent.collapsed=false
        return
    if row.kind=="case":
        item.set_text(0,record.label);item.set_text(2,record.scenario_status.replace("_"," "))
        item.set_text(3,_output_label(record));item.set_tooltip_text(3,_evidence_text(record.witnesses))
        if preferred_id in [str(entry.key),str(entry.id)] and record.id==preferred_scenario:
            preferred_item=item;parent.collapsed=false
        return
    item.set_text(0,entry.label);item.set_text(1,entry.source_status.replace("_"," "))
    item.set_text(2,entry.scenario_status.replace("_"," "));item.set_text(3,_output_label(entry));item.set_text(4,entry.approval_status.replace("_"," "))
    item.set_tooltip_text(3,_evidence_text(entry.get("witnesses",[])))
    if entry.approval_status=="rejected":item.set_custom_color(4,Color("eeaa9c"))
    item.set_tooltip_text(0,entry.id+("\nTyped source; not listed in the server snapshot. Runtime availability unverified." if entry.get("inventory_origin")=="typed_source" else ""))
    item.collapsed=row.collapsed
    if preferred_id in [str(entry.key),str(entry.id)] and preferred_item==null:preferred_item=item
    # Preserve Opus child enqueueing inside the bounded parent publication,
    # rather than eagerly flattening every linked case during filtering.
    for child_record in entry.cases:
        pending_rows.append({"kind":"case","key":str(row.key)+":case:"+str(child_record.id),
            "parent":row.key,"capability":entry,"case":child_record})
    for described in entry.get("scenarios",[]):
        pending_rows.append({"kind":"study","key":str(row.key)+":study:"+str(described.id),
            "parent":row.key,"capability":entry,"case":{},"study":described})

static func _study_text(study:Dictionary)->String:
    var lines:Array=[str(study.get("label",study.get("id",""))),"Source: "+str(study.get("source","")),
        "Described expectations; not observed outcomes or output qualification.",str(study.get("purpose","")),
        "Sequence: "+JSON.stringify(study.get("sequence",[])),"Expectations: "+JSON.stringify(study.get("expectations",[]))]
    for binding in study.get("recordings",[]):
        lines.append("Exact original %s: %s"%[str(binding.get("case_id","")),"playable" if binding.get("ready",false) else str(binding.get("scenario_status","not linked in this Library"))])
    return "\n".join(lines)

static func _output_label(owner:Dictionary)->String:
    if not owner.get("current_output_witnesses",[]).is_empty():return "Engine/package receipts"
    if not owner.get("matching_package_output_witnesses",[]).is_empty():return "Package receipts"
    if not owner.get("output_witnesses",[]).is_empty():return "Historical / unknown receipts"
    if not owner.get("reader_witnesses",[]).is_empty() or not owner.get("command_witnesses",[]).is_empty():return "Safety/command receipts only"
    if not owner.get("audio_witnesses",[]).is_empty():return "Audio transport receipts only"
    return "Not assessed"

static func _evidence_text(witnesses:Array)->String:
    if witnesses.is_empty():return "No saved output evidence is linked. Recording/source presence does not qualify rendered pixels or audible output."
    var lines:Array=[]
    for witness in witnesses:
        lines.append("%s · %s\n%s\nPackage: %s (%s)\nEngine: %s (%s)\n%s"%[str(witness.get("kind","output")).replace("_"," "),witness.get("status","reported"),witness.get("report",""),str(witness.get("factory_version","not recorded")),witness.get("package_scope","identity not recorded"),JSON.stringify(witness.get("engine",{})),witness.get("engine_scope","identity not recorded"),witness.get("qualifies","")])
    return "\n\n".join(lines)
func _selected(open_recording:bool=true)->void:
    if rebuilding:return
    var item=tree.get_selected()
    if item==null:return
    var selected:Variant=item.get_metadata(0)
    if not selected is Dictionary:return
    selected_capability=selected.capability;recording_options=[];recording_picker.clear();selected_scenario={};selected_study=selected.get("study",{})
    if open_recording:
        preferred_id=str(selected_capability.get("key",selected_capability.id))
        preferred_scenario=str(selected.case.get("id",selected_study.get("id","")))
    prefix_record={};prefix_perspectives=[];prefix_button.disabled=true;prefix_button.text="Inspect failed prefix";prefix_button.tooltip_text="Select a failed case with an actual initialized journal prefix."
    var candidates:Array=[selected.case] if not selected.case.is_empty() else selected_capability.cases
    if not selected_study.is_empty():
        candidates=[]
        for binding in selected_study.get("recordings",[]):
            if binding.get("ready",false) and binding.has("record") and not candidates.any(func(record):return record.id==binding.record.id):candidates.append(binding.record)
    for record in candidates:
        if record.ready:recording_options.append(record);recording_picker.add_item(record.label)
    recording_picker.disabled=recording_options.is_empty();open_button.disabled=recording_options.is_empty()
    if recording_options.is_empty():recording_picker.add_item("No current recording")
    detail.text="Art: %s   ·   Scenario: %s   ·   Presentation: %s   ·   Review: %s"%[selected_capability.source_status.replace("_"," "),selected_capability.scenario_status.replace("_"," "),selected_capability.presentation_status.replace("_"," "),selected_capability.approval_status.replace("_"," ")]
    if not str(selected_capability.get("source_path","")).is_empty():detail.text+="\nSource: "+str(selected_capability.source_path)
    if selected_capability.get("inventory_origin")=="typed_source":detail.text+="\nTyped source is not listed in the server snapshot; runtime availability remains unverified."
    var witnesses:Array=selected.case.get("witnesses",[]) if not selected.case.is_empty() else selected_capability.get("witnesses",[])
    if not selected_study.is_empty():
        witnesses=[]
        for binding in selected_study.get("recordings",[]):
            if binding.get("available",false) and binding.has("record"):witnesses.append_array(binding.record.get("witnesses",[]))
    detail.tooltip_text=_evidence_text(witnesses)
    if not selected_capability.get("requirements",[]).is_empty():
        detail.text+="\n%d authored requirements · %d described studies; source details are in the tooltip and Copy details."%[selected_capability.requirements.size(),selected_capability.get("scenarios",[]).size()]
        detail.tooltip_text+="\n\nAuthored requirements (not output evidence):\n"+JSON.stringify(selected_capability.requirements,"  ")
    if not selected_study.is_empty():
        detail.text+="\nStudy: "+str(selected_study.label)+" · described expectations, not observed outcomes."
        detail.tooltip_text+="\n\n"+_study_text(selected_study)
        if not witnesses.is_empty():detail.tooltip_text+="\nLinked case receipts keep their own scopes; they do not establish this study's expected outcome."
    if not witnesses.is_empty():detail.text+="\n%d linked native/audio/safety receipts · hover Output evidence for their scope and paths."%witnesses.size()
    if not selected.case.is_empty():detail.text+="\nCaptured engine: "+str(selected.case.get("capture_engine",{}).get("commit","not recorded"))+" · "+str(selected.case.get("engine_status","unverified"))
    if not selected.case.is_empty() and not str(selected.case.get("reason","")).is_empty():detail.text+="\n"+str(selected.case.reason)
    elif recording_options.is_empty():
        for record in candidates.slice(0,3):
            if not str(record.get("reason","")).is_empty():detail.text+="\n"+record.label+": "+str(record.reason)
    if not selected.case.is_empty() and selected.case.scenario_status in ["failed","stale"]:
        var prefix:Dictionary=Library.failed_prefix(selected.case)
        prefix_button.disabled=not prefix.available
        if prefix.available:
            prefix_record=selected.case;prefix_perspectives=prefix.perspectives
            prefix_button.text="Inspect historical original" if selected.case.scenario_status=="stale" else "Inspect failed prefix"
            prefix_button.tooltip_text="Inspect this exact original through the strict current SDK reader. Its failed/stale status and missing lifecycle requirements remain unchanged."
            detail.text+="\nAn original prefix is available for inspection; scenario status remains "+str(selected.case.scenario_status)+"."
        if not prefix.errors.is_empty():
            detail.text+="\nPrefix admission: "+"; ".join(prefix.errors)
            prefix_button.tooltip_text+="\n"+"; ".join(prefix.errors)
    if open_recording:
        if not recording_options.is_empty():_open()
        else:recording_unavailable.emit()
func _open()->void:
    if recording_picker.selected<0 or recording_picker.selected>=recording_options.size():return
    var record:Dictionary=recording_options[recording_picker.selected]
    preferred_id=str(selected_capability.get("key",selected_capability.id))
    preferred_scenario=str(selected_study.get("id",record.id))
    selected_scenario=Library.scenario(record)
    if not selected_study.is_empty():
        selected_scenario=selected_study.duplicate(true)
        selected_scenario.recordings=[{"available":record.ready,"record":record}]
        selected_scenario.moments=record.get("moments",[]).duplicate(true)
        selected_scenario.recording_id=record.id
    recording_selected.emit(selected_capability,selected_scenario,record);hide()
func _inspect_prefix()->void:
    if prefix_button.disabled or prefix_record.is_empty() or prefix_perspectives.is_empty():return
    var scenario:Dictionary=Library.scenario(prefix_record)
    scenario.inspection_mode="failed_prefix";scenario.recording_status=str(prefix_record.scenario_status)
    scenario.recording_failure=str(prefix_record.get("reason",""))
    scenario.label=("Historical original · " if prefix_record.scenario_status=="stale" else "Failed prefix · ")+str(scenario.label)
    selected_scenario=scenario
    failed_prefix_selected.emit(selected_capability,scenario,prefix_record,str(prefix_perspectives[0].id));hide()
func copy_study()->void:
    if not selected_capability.is_empty():DisplayServer.clipboard_set(JSON.stringify({"capability":selected_capability.id,"kind":selected_capability.kind,"source_path":selected_capability.get("source_path",""),"inventory_origin":selected_capability.get("inventory_origin",""),"runtime_availability":selected_capability.get("runtime_availability","unknown"),"cases":selected_capability.cases,"source":selected_capability.source_status,"scenario":selected_capability.scenario_status,"presentation":selected_capability.presentation_status,"approval":selected_capability.approval_status,"witnesses":selected_capability.get("witnesses",[]),"requirements":selected_capability.get("requirements",[]),"described_studies":selected_capability.get("scenarios",[]),"selected_study":selected_study},"  "))

func _exit_tree()->void:
    generation+=1;request={}
    if worker!=null:worker.wait_to_finish();worker=null
