extends Window
## A study exists independently of its recording and presentation implementation.
signal recording_selected(capability:Dictionary,scenario:Dictionary,record:Dictionary)
signal recording_unavailable
const Catalog=preload("res://studio/study_catalog.gd")
var report:Dictionary={}
var worker:Thread
var request:Dictionary={}
var generation=0
var installed_generation=-1
var search:LineEdit
var kind_picker:OptionButton
var tree:Tree
var title_label:Label
var purpose:Label
var sequence:RichTextLabel
var expectations:Tree
var requirements:Tree
var recording_picker:OptionButton
var open_button:Button
var recording_note:Label
var summary:Label
var selected_capability:Dictionary={}
var selected_scenario:Dictionary={}
var recording_options:Array=[]
var filtered:Array=[]
var pending_rows:Array=[]
var row_cursor=0
var preferred_id=""
var preferred_scenario=""
var refresh_pending=false
var error=""

func _ready()->void:
    title="Studio library · capabilities and study sequences"
    size=Vector2i(1140,680);min_size=Vector2i(820,500)
    close_requested.connect(hide)
    var outer=MarginContainer.new();outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(outer)
    for side in ["left","right","top","bottom"]:outer.add_theme_constant_override("margin_"+side,10)
    var box=VBoxContainer.new();outer.add_child(box)
    var tools=HBoxContainer.new();box.add_child(tools)
    kind_picker=OptionButton.new();tools.add_child(kind_picker)
    for kind in ["All","Action","Spell","Condition","Mechanic","VFX"]:kind_picker.add_item(kind)
    kind_picker.item_selected.connect(func(_i):refresh_pending=true)
    search=LineEdit.new();search.placeholder_text="Find a capability or interaction";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tools.add_child(search)
    search.text_changed.connect(func(_text):refresh_pending=true)
    var copy=Button.new();copy.text="Copy study";tools.add_child(copy);copy.pressed.connect(copy_study)
    summary=Label.new();summary.add_theme_font_size_override("font_size",12);box.add_child(summary)
    var split=HSplitContainer.new();split.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(split)
    tree=Tree.new();tree.hide_root=true;tree.columns=2;tree.column_titles_visible=true;tree.select_mode=Tree.SELECT_ROW;tree.allow_reselect=true
    tree.set_column_title(0,"Capability / interaction");tree.set_column_title(1,"Study / recording")
    tree.set_column_expand_ratio(0,3);tree.set_column_expand_ratio(1,2)
    tree.custom_minimum_size.x=350;tree.size_flags_horizontal=Control.SIZE_FILL;split.add_child(tree)
    tree.item_selected.connect(_selection)
    var details=VBoxContainer.new();details.custom_minimum_size.x=410;details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(details)
    title_label=Label.new();title_label.add_theme_font_size_override("font_size",18);title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(title_label)
    purpose=Label.new();purpose.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;purpose.add_theme_font_size_override("font_size",12);details.add_child(purpose)
    var tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;details.add_child(tabs)
    var study=VBoxContainer.new();study.name="Study sequence";tabs.add_child(study)
    sequence=RichTextLabel.new();sequence.custom_minimum_size.y=105;sequence.size_flags_vertical=Control.SIZE_EXPAND_FILL;study.add_child(sequence)
    expectations=Tree.new();expectations.hide_root=true;expectations.columns=3;expectations.column_titles_visible=true
    for i in 3:expectations.set_column_title(i,["Phase","Participant","Expected presentation"][i])
    expectations.set_column_expand_ratio(0,1);expectations.set_column_expand_ratio(1,1);expectations.set_column_expand_ratio(2,3)
    expectations.custom_minimum_size.y=180;expectations.size_flags_vertical=Control.SIZE_EXPAND_FILL;study.add_child(expectations)
    requirements=Tree.new();requirements.name="Authoring";requirements.hide_root=true;requirements.columns=2;requirements.column_titles_visible=true
    requirements.set_column_title(0,"Declared requirement");requirements.set_column_title(1,"Authoring / implementation")
    requirements.set_column_expand_ratio(0,3);requirements.set_column_expand_ratio(1,2);tabs.add_child(requirements)
    var recordings=HBoxContainer.new();details.add_child(recordings)
    recording_picker=OptionButton.new();recording_picker.fit_to_longest_item=false;recording_picker.clip_text=true;recording_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;recordings.add_child(recording_picker)
    recording_picker.item_selected.connect(func(choice):_recording_changed(choice);open_selected_recording())
    open_button=Button.new();open_button.text="Open recording";open_button.disabled=true;recordings.add_child(open_button);open_button.pressed.connect(open_selected_recording)
    recording_note=Label.new();recording_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;recording_note.add_theme_font_size_override("font_size",12);details.add_child(recording_note)
    show_selection({}, {})

func open(cache:Dictionary,records:Array,capability_id:String="",scenario_id:String="")->void:
    generation+=1;preferred_id=capability_id;preferred_scenario=scenario_id
    request={"generation":generation,"cache":cache.duplicate(),"records":records}
    report={};error="";pending_rows=[];row_cursor=0;tree.clear();show_selection({}, {})
    summary.text="Reading capability definitions, study sequences and authoring…"
    popup_centered(Vector2i(mini(1140,DisplayServer.window_get_size().x-40),mini(680,DisplayServer.window_get_size().y-40)))
    _start()

func _start()->void:
    if worker!=null or request.is_empty():return
    var job=request;request={};worker=Thread.new()
    var started=worker.start(_build.bind(job))
    if started!=OK:worker=null;error=error_string(started);summary.text=error

static func _build(job:Dictionary)->Dictionary:
    return {"generation":job.generation,"report":Catalog.build(job.cache,job.records)}

func _process(_delta:float)->void:
    if worker!=null and not worker.is_alive():
        var result=worker.wait_to_finish();worker=null
        if result.generation==generation:
            report=result.report;installed_generation=generation
            error="; ".join(report.get("errors",[]));refresh_pending=true
        _start()
    if refresh_pending and installed_generation==generation:
        refresh_pending=false;_filter()
    var started=Time.get_ticks_usec();var count=0
    while row_cursor<pending_rows.size() and count<24 and Time.get_ticks_usec()-started<2000:
        var entry:Dictionary=pending_rows[row_cursor];row_cursor+=1;count+=1
        var item=tree.create_item(entry.get("parent",tree.get_root()))
        item.set_text(0,entry.scenario.get("label",entry.capability.label));item.set_metadata(0,entry)
        if entry.scenario.is_empty():
            item.set_text(1,"Study needed" if entry.capability.scenarios.is_empty() else "%d studies"%entry.capability.scenarios.size())
            item.set_tooltip_text(0,str(entry.capability.id)+"\n"+str(entry.capability.get("source","")))
            item.collapsed=search.text.is_empty() and entry.capability.id!=preferred_id
            for scenario in entry.capability.scenarios:
                if search.text.is_empty() or _matches(entry.capability,scenario,search.text.to_lower()):
                    pending_rows.append({"capability":entry.capability,"scenario":scenario,"parent":item})
        else:
            item.set_text(1,recording_state(entry.scenario))
        if entry.capability.id==preferred_id and ((preferred_scenario.is_empty() and entry.scenario.is_empty()) or (not preferred_scenario.is_empty() and entry.scenario.get("id","")==preferred_scenario)):
            # Restoring a highlighted row is not a new user navigation request.
            tree.set_block_signals(true);item.select(0);tree.set_block_signals(false)
            show_selection(entry.capability,entry.scenario)
    if row_cursor==pending_rows.size() and not pending_rows.is_empty():pending_rows=[];row_cursor=0

func is_prepared()->bool:
    return installed_generation==generation and worker==null and request.is_empty() and pending_rows.is_empty() and not refresh_pending

static func _matches(capability:Dictionary,scenario:Dictionary,query:String)->bool:
    return query in (str(capability.id)+" "+str(capability.label)+" "+str(scenario.get("label",""))+" "+str(scenario.get("purpose",""))).to_lower()

func _filter()->void:
    filtered=[];pending_rows=[];row_cursor=0;tree.clear();tree.create_item()
    show_selection({}, {})
    var kind=kind_picker.get_item_text(kind_picker.selected);var query=search.text.to_lower()
    for capability in report.get("capabilities",[]):
        if kind!="All" and capability.kind!=kind:continue
        if not query.is_empty() and not _matches(capability,{},query) and not capability.scenarios.any(func(s):return _matches(capability,s,query)):continue
        filtered.append(capability);pending_rows.append({"capability":capability,"scenario":{}})
    summary.text="%d capabilities · %d studies · %d need a study sequence"%[report.capabilities.size(),report.counts.scenarios,report.counts.study_needed]
    if not error.is_empty():summary.text+=" · Catalogue issues: "+error

static func recording_state(scenario:Dictionary)->String:
    var available=scenario.get("recordings",[]).filter(func(r):return r.get("available",false))
    if available.is_empty():return "Needs recording"
    return "Recorded" if available.any(func(r):return r.get("evidence")=="recorded") else "Partial recording"

func _selection()->void:
    var selected=tree.get_selected()
    if selected==null:return
    var data:Dictionary=selected.get_metadata(0)
    show_selection(data.capability,data.scenario)
    if data.scenario.is_empty():selected.collapsed=false
    elif not recording_options.is_empty():open_selected_recording()
    else:recording_unavailable.emit()

func show_selection(capability:Dictionary,scenario:Dictionary)->void:
    selected_capability=capability;selected_scenario=scenario
    title_label.text=scenario.get("label",capability.get("label","Choose a capability"))
    purpose.text=scenario.get("purpose", "Study sequences have not been authored yet." if not capability.is_empty() and capability.scenarios.is_empty() else "Select an interaction to inspect its sequence and expected presentation.")
    sequence.clear();expectations.clear();requirements.clear();recording_picker.clear();recording_options=[];open_button.disabled=true
    if scenario.is_empty():
        sequence.text="" if capability.is_empty() else "This capability remains visible independently of recordings or renderer support."
    else:
        var lines:Array[String]=[]
        var setup=scenario.get("setup","")
        if not str(setup).is_empty():lines.append("Setup: "+str(setup))
        for i in scenario.get("sequence",[]).size():lines.append(str(i+1)+". "+str(scenario.sequence[i]))
        sequence.text="\n".join(lines)
    var expected_root=expectations.create_item()
    for expected in scenario.get("expectations",[]):
        var item=expectations.create_item(expected_root)
        item.set_text(0,str(expected.get("phase","")));item.set_text(1,", ".join(expected.get("participants",[])));item.set_text(2,str(expected.label))
        var pointers=expected.get("authoring_sources",[])+expected.get("rule_sources",[])
        for i in 3:item.set_tooltip_text(i,str(expected.label)+"\n"+str(expected.get("description",""))+"\nParticipants: "+", ".join(expected.get("participants",[]))+"\n"+"\n".join(pointers))
        item.set_metadata(0,expected)
    var requirement_root=requirements.create_item()
    for requirement in capability.get("requirements",[]):
        var item=requirements.create_item(requirement_root)
        item.set_text(0,str(requirement.get("label",requirement.get("id",""))))
        var gap:String=requirement.get("gap_kind",requirement.get("status","unexercised"))
        var labels={"unexercised":"Assigned · unqualified","authoring_assignment":"Needs assignment","authoring_review":"Needs authoring decision","renderer":"Renderer missing","inspection":"Studio track missing","unassessed":"Not assessed","source":"Source missing","native_migration":"Native integration needed","explicit_none":"Explicitly disabled"}
        item.set_text(1,labels.get(gap,gap.replace("_"," ")))
        for i in 2:item.set_tooltip_text(i,str(requirement.get("source",""))+"\n"+str(requirement.get("reason","")))
        item.set_metadata(0,requirement)
    for binding in scenario.get("recordings",[]):
        if not binding.get("available",false):continue
        recording_options.append(binding)
        recording_picker.add_item(str(binding.record.label)+(" · partial" if binding.evidence=="partial" else ""))
    recording_picker.disabled=recording_options.is_empty()
    if recording_options.is_empty():
        recording_picker.add_item("No recording")
        recording_note.text="Record this sequence before evaluating its presentation." if not scenario.is_empty() else "Source assignments and a completed animation model are separate from a study sequence."
    else:_recording_changed(0)

func _recording_changed(choice:int)->void:
    open_button.disabled=choice<0 or choice>=recording_options.size()
    if open_button.disabled:return
    var selected:Dictionary=recording_options[choice]
    recording_note.text="\n".join(selected.get("gaps",[])) if selected.evidence=="partial" else "Recorded behavior; presentation implementation and visual qualification remain separate."

func open_selected_recording()->void:
    var i=recording_picker.selected
    if i<0 or i>=recording_options.size():return
    recording_selected.emit(selected_capability,selected_scenario,recording_options[i].record)
    hide()

func copy_study()->void:
    if selected_capability.is_empty():return
    var selected={"capability":selected_capability.id,"scenario":selected_scenario,"requirements":selected_capability.requirements}
    DisplayServer.clipboard_set(JSON.stringify(selected,"  "))

func _exit_tree()->void:
    if worker!=null:worker.wait_to_finish();worker=null
