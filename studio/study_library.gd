extends Window
## Authoring IDs and their actual current cases. One compact browser; production owns playback.
signal recording_selected(capability:Dictionary,scenario:Dictionary,record:Dictionary)
signal recording_unavailable
const Library=preload("res://studio/case_library.gd")
var report:Dictionary={}
var search:LineEdit
var kind_picker:OptionButton
var tree:Tree
var summary:Label
var detail:Label
var recording_picker:OptionButton
var open_button:Button
var selected_capability:Dictionary={}
var selected_scenario:Dictionary={}
var recording_options:Array=[]
var rebuilding=false
func _ready()->void:
    title="Studio library";size=Vector2i(920,640);min_size=Vector2i(680,420);close_requested.connect(hide)
    var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
    for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,10)
    var box=VBoxContainer.new();margin.add_child(box);var tools=HBoxContainer.new();box.add_child(tools)
    kind_picker=OptionButton.new();kind_picker.add_item("All")
    for category in Library.CAPABILITIES:kind_picker.add_item(category)
    tools.add_child(kind_picker);kind_picker.item_selected.connect(func(_choice):_refresh())
    search=LineEdit.new();search.placeholder_text="Find a spell, condition, action or object";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tools.add_child(search);search.text_changed.connect(func(_value):_refresh())
    var reload=Button.new();reload.text="Refresh";tools.add_child(reload);reload.pressed.connect(func():report=Library.catalog();_refresh())
    summary=Label.new();summary.add_theme_font_size_override("font_size",12);box.add_child(summary)
    tree=Tree.new();tree.hide_root=true;tree.columns=3;tree.column_titles_visible=true;tree.select_mode=Tree.SELECT_ROW;tree.allow_reselect=true;tree.size_flags_vertical=Control.SIZE_EXPAND_FILL;tree.set_column_title(0,"Capability / case");tree.set_column_title(1,"Art");tree.set_column_title(2,"Recording");tree.set_column_expand_ratio(0,6);tree.set_column_expand_ratio(1,1);tree.set_column_expand_ratio(2,2);box.add_child(tree)
    tree.item_selected.connect(_selected);tree.item_activated.connect(_open)
    detail=Label.new();detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",12);box.add_child(detail)
    var bottom=HBoxContainer.new();box.add_child(bottom);recording_picker=OptionButton.new();recording_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;recording_picker.fit_to_longest_item=false;recording_picker.clip_text=true;bottom.add_child(recording_picker)
    recording_picker.item_selected.connect(func(_choice):_open())
    open_button=Button.new();open_button.text="Play";open_button.disabled=true;bottom.add_child(open_button);open_button.pressed.connect(_open)
func open(_cache:Dictionary,_records:Array,preferred:String="",_scenario:String="")->void:
    report=Library.catalog();search.text="";kind_picker.select(0);_refresh(preferred)
    popup_centered(Vector2i(mini(920,DisplayServer.window_get_size().x-40),mini(640,DisplayServer.window_get_size().y-40)))
func _refresh(preferred:String="")->void:
    rebuilding=true;tree.clear();var root=tree.create_item();var categories={};var groups={};var count=0;var recorded=0
    var query=search.text.strip_edges().to_lower();var category=kind_picker.get_item_text(kind_picker.selected);selected_capability={};selected_scenario={};recording_options=[];recording_picker.clear();open_button.disabled=true;detail.text=""
    for entry in report.get("entries",[]):
        if kind_picker.selected>0 and entry.category!=category:continue
        if not query.is_empty() and not query in (entry.id+" "+entry.label+" "+entry.group).to_lower():continue
        if not categories.has(entry.category):
            var heading=tree.create_item(root);heading.set_text(0,entry.category);heading.set_selectable(0,false);categories[entry.category]=heading
        var group_key=entry.category+":"+entry.group
        if not groups.has(group_key):
            var heading=tree.create_item(categories[entry.category]);heading.set_text(0,entry.group);heading.set_selectable(0,false);heading.collapsed=query.is_empty() and entry.kind!="spell";groups[group_key]=heading
        var item=tree.create_item(groups[group_key]);item.set_text(0,entry.label);item.set_text(1,entry.source_status.replace("_"," "));item.set_text(2,entry.scenario_status.replace("_"," "));item.set_tooltip_text(0,entry.id);item.set_metadata(0,{"capability":entry,"case":{}})
        item.collapsed=query.is_empty();count+=1
        if entry.scenario_status=="recorded":recorded+=1
        for record in entry.cases:
            var child=tree.create_item(item);child.set_text(0,record.label);child.set_text(2,record.scenario_status.replace("_"," "));child.set_metadata(0,{"capability":entry,"case":record})
        if entry.id==preferred:item.select(0)
    summary.text="%d capabilities · %d recorded · %d without a current recording"%[count,recorded,count-recorded];rebuilding=false
func _selected()->void:
    if rebuilding:return
    var item=tree.get_selected()
    if item==null:return
    var selected:Variant=item.get_metadata(0)
    if not selected is Dictionary:return
    selected_capability=selected.capability;recording_options=[];recording_picker.clear();selected_scenario={}
    var candidates:Array=[selected.case] if not selected.case.is_empty() else selected_capability.cases
    for record in candidates:
        if record.ready:recording_options.append(record);recording_picker.add_item(record.label)
    recording_picker.disabled=recording_options.is_empty();open_button.disabled=recording_options.is_empty()
    if recording_options.is_empty():recording_picker.add_item("No current recording")
    detail.text="Art: %s   ·   Scenario: %s   ·   Presentation: %s   ·   Review: %s"%[selected_capability.source_status.replace("_"," "),selected_capability.scenario_status.replace("_"," "),selected_capability.presentation_status.replace("_"," "),selected_capability.approval_status.replace("_"," ")]
    if not selected.case.is_empty() and not str(selected.case.get("reason","")).is_empty():detail.text+="\n"+str(selected.case.reason)
    if not recording_options.is_empty():_open()
    else:recording_unavailable.emit()
func _open()->void:
    if recording_picker.selected<0 or recording_picker.selected>=recording_options.size():return
    var record:Dictionary=recording_options[recording_picker.selected];selected_scenario=Library.scenario(record);recording_selected.emit(selected_capability,selected_scenario,record);hide()
func copy_study()->void:
    if not selected_capability.is_empty():DisplayServer.clipboard_set(JSON.stringify({"capability":selected_capability.id,"cases":selected_capability.cases,"source":selected_capability.source_status,"presentation":selected_capability.presentation_status,"approval":selected_capability.approval_status},"  "))
