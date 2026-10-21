extends Window
## Authoring IDs and their actual current cases. One compact browser; production owns playback.
signal recording_selected(capability:Dictionary,scenario:Dictionary,record:Dictionary)
signal recording_unavailable
signal failed_prefix_selected(capability:Dictionary,scenario:Dictionary,record:Dictionary,perspective_id:String)
const Library=preload("res://studio/case_library.gd")
const FILTERS={"All statuses":"","Recorded":"recorded","No recording":"missing_recording","Failed / stale":"recording_failure","Evidence linked":"evidence","No output evidence":"unwitnessed","Source gaps":"source_gap","Awaiting art review":"needs_review","Rejected art":"rejected","Current engine/package receipts":"current_evidence","Matching package receipts":"package_evidence","Historical / unknown receipts":"historical_evidence","Reader safety receipts":"reader_evidence","Issued-command receipts":"command_evidence","Audio receipts":"audio_evidence"}
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
var recording_options:Array=[]
var rebuilding=false
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
    var reload=Button.new();reload.text="Refresh";tools.add_child(reload);reload.pressed.connect(func():report=Library.catalog();_refresh())
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
    report=Library.catalog();search.text="";kind_picker.select(0);status_picker.select(0);_refresh(preferred,scenario)
    popup_centered(Vector2i(mini(1120,DisplayServer.window_get_size().x-40),mini(640,DisplayServer.window_get_size().y-40)))
func _refresh(preferred:String="",scenario:String="")->void:
    if preferred.is_empty() and tree.get_selected()!=null:
        var previous:Variant=tree.get_selected().get_metadata(0)
        if previous is Dictionary:
            preferred=str(previous.capability.get("key",previous.capability.id));scenario=str(previous.case.get("id",""))
    var preferred_item:TreeItem=null
    rebuilding=true;tree.clear();var root=tree.create_item();var categories={};var groups={};var count=0;var recorded=0;var evidenced=0;var awaiting_review=0
    var query=search.text.strip_edges().to_lower();var category=kind_picker.get_item_text(kind_picker.selected);selected_capability={};selected_scenario={};recording_options=[];recording_picker.clear();open_button.disabled=true;prefix_button.disabled=true;prefix_record={};prefix_perspectives=[];detail.text=""
    for entry in report.get("entries",[]):
        if not Library.matches(entry,query,category if kind_picker.selected>0 else "",str(status_picker.get_item_metadata(status_picker.selected))):continue
        if not categories.has(entry.category):
            var heading=tree.create_item(root);heading.set_text(0,entry.category);heading.set_selectable(0,false);categories[entry.category]=heading
        var group_key=entry.category+":"+entry.group
        if not groups.has(group_key):
            var heading=tree.create_item(categories[entry.category]);heading.set_text(0,entry.group);heading.set_selectable(0,false);heading.collapsed=query.is_empty() and entry.kind!="spell";groups[group_key]=heading
        var item=tree.create_item(groups[group_key]);item.set_text(0,entry.label);item.set_text(1,entry.source_status.replace("_"," "));item.set_text(2,entry.scenario_status.replace("_"," "));item.set_text(3,_output_label(entry));item.set_text(4,entry.approval_status.replace("_"," "))
        item.set_tooltip_text(3,_evidence_text(entry.get("witnesses",[])))
        if entry.approval_status=="rejected":item.set_custom_color(4,Color("eeaa9c"))
        if entry.approval_status=="needs_review":awaiting_review+=1
        item.set_tooltip_text(0,entry.id+("\nTyped source; not listed in the server snapshot. Runtime availability unverified." if entry.get("inventory_origin")=="typed_source" else ""));item.set_metadata(0,{"capability":entry,"case":{}})
        item.collapsed=query.is_empty();count+=1
        if entry.scenario_status=="recorded":recorded+=1
        if not entry.get("output_witnesses",[]).is_empty():evidenced+=1
        for record in entry.cases:
            var child=tree.create_item(item);child.set_text(0,record.label);child.set_text(2,record.scenario_status.replace("_"," "));child.set_text(3,_output_label(record));child.set_tooltip_text(3,_evidence_text(record.witnesses));child.set_metadata(0,{"capability":entry,"case":record})
            if preferred in [str(entry.key),str(entry.id)] and record.id==scenario:preferred_item=child;item.collapsed=false
        if preferred in [str(entry.key),str(entry.id)] and preferred_item==null:preferred_item=item
    summary.text="%d / %d capabilities · %d recorded · %d with linked evidence · %d awaiting art review"%[count,report.get("entries",[]).size(),recorded,evidenced,awaiting_review];rebuilding=false
    if preferred_item!=null:
        var ancestor:TreeItem=preferred_item.get_parent()
        while ancestor!=null:ancestor.collapsed=false;ancestor=ancestor.get_parent()
        rebuilding=true;preferred_item.select(0);rebuilding=false
        _selected(false);tree.scroll_to_item(preferred_item)

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
    selected_capability=selected.capability;recording_options=[];recording_picker.clear();selected_scenario={}
    prefix_record={};prefix_perspectives=[];prefix_button.disabled=true;prefix_button.text="Inspect failed prefix";prefix_button.tooltip_text="Select a failed case with an actual initialized journal prefix."
    var candidates:Array=[selected.case] if not selected.case.is_empty() else selected_capability.cases
    for record in candidates:
        if record.ready:recording_options.append(record);recording_picker.add_item(record.label)
    recording_picker.disabled=recording_options.is_empty();open_button.disabled=recording_options.is_empty()
    if recording_options.is_empty():recording_picker.add_item("No current recording")
    detail.text="Art: %s   ·   Scenario: %s   ·   Presentation: %s   ·   Review: %s"%[selected_capability.source_status.replace("_"," "),selected_capability.scenario_status.replace("_"," "),selected_capability.presentation_status.replace("_"," "),selected_capability.approval_status.replace("_"," ")]
    if not str(selected_capability.get("source_path","")).is_empty():detail.text+="\nSource: "+str(selected_capability.source_path)
    if selected_capability.get("inventory_origin")=="typed_source":detail.text+="\nTyped source is not listed in the server snapshot; runtime availability remains unverified."
    var witnesses:Array=selected.case.get("witnesses",[]) if not selected.case.is_empty() else selected_capability.get("witnesses",[])
    detail.tooltip_text=_evidence_text(witnesses)
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
    var record:Dictionary=recording_options[recording_picker.selected];selected_scenario=Library.scenario(record);recording_selected.emit(selected_capability,selected_scenario,record);hide()
func _inspect_prefix()->void:
    if prefix_button.disabled or prefix_record.is_empty() or prefix_perspectives.is_empty():return
    var scenario:Dictionary=Library.scenario(prefix_record)
    scenario.inspection_mode="failed_prefix";scenario.recording_status=str(prefix_record.scenario_status)
    scenario.recording_failure=str(prefix_record.get("reason",""))
    scenario.label=("Historical original · " if prefix_record.scenario_status=="stale" else "Failed prefix · ")+str(scenario.label)
    selected_scenario=scenario
    failed_prefix_selected.emit(selected_capability,scenario,prefix_record,str(prefix_perspectives[0].id));hide()
func copy_study()->void:
    if not selected_capability.is_empty():DisplayServer.clipboard_set(JSON.stringify({"capability":selected_capability.id,"kind":selected_capability.kind,"source_path":selected_capability.get("source_path",""),"inventory_origin":selected_capability.get("inventory_origin",""),"runtime_availability":selected_capability.get("runtime_availability","unknown"),"cases":selected_capability.cases,"source":selected_capability.source_status,"scenario":selected_capability.scenario_status,"presentation":selected_capability.presentation_status,"approval":selected_capability.approval_status,"witnesses":selected_capability.get("witnesses",[])},"  "))
