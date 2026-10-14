extends Window
## Read-only worklist. Native conversion, JSON assignment and render proof differ.
const Conditions=preload("res://presentation/condition_coverage.gd")
const AuthoringAudit=preload("res://studio/authoring_audit.gd")
const BUCKETS={"All":"","Missing authoring":"authoring_assignment","Missing sources":"source","Native migration":"native_migration","Renderer gaps":"renderer","Missing tracks":"inspection","Not assessed":"unassessed","Unexercised":"unexercised"}
const NEXT={"authoring_assignment":"Assign the required presentation in its authoring owner.","authoring_review":"Decide which authoring owner should supply this presentation.","source":"Restore or select the referenced source.","native_migration":"Qualify and select a native counterpart.","renderer":"Implement the authored mechanism in the shared renderer.","inspection":"Expose the existing renderer operation in Studio.","unassessed":"Trace the existing renderer before claiming support or absence.","unexercised":"Record and qualify this requirement.","explicit_none":"Intentionally disabled or authored without presentation."}
var tree:Tree
var details:TextEdit
var filter:LineEdit
var bucket:OptionButton
var group_picker:OptionButton
var summary:Label
var detail_toggle:CheckButton
var entries:Array=[]
var filtered:Array=[]
var report:Dictionary={}
var worker:Thread
var pending:Dictionary={}
var generation=0
var installed_generation=-1
var tree_pending:Array=[]
var tree_groups:Dictionary={}
var tree_cursor=0
var build_error=""
var refresh_pending=false
var selected_record:Dictionary={}
func _ready()->void:
    title="Authored presentation · work remaining"
    size=Vector2i(1120,650);min_size=Vector2i(760,440)
    close_requested.connect(hide)
    var box=VBoxContainer.new();box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(box)
    var tools=HBoxContainer.new();box.add_child(tools)
    group_picker=OptionButton.new();group_picker.fit_to_longest_item=false;group_picker.custom_minimum_size.x=130;tools.add_child(group_picker)
    group_picker.add_item("All capabilities");group_picker.set_item_metadata(0,"")
    group_picker.item_selected.connect(func(_i):refresh_pending=true)
    bucket=OptionButton.new();bucket.fit_to_longest_item=false;bucket.custom_minimum_size.x=165;tools.add_child(bucket)
    for label in BUCKETS:bucket.add_item(label);bucket.set_item_metadata(bucket.item_count-1,BUCKETS[label])
    bucket.item_selected.connect(func(_i):refresh_pending=true)
    filter=LineEdit.new();filter.placeholder_text="Find capability, component or source field";filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tools.add_child(filter)
    filter.text_changed.connect(func(_value):refresh_pending=true)
    for label in ["Copy selected","Copy filtered"]:
        var button=Button.new();button.text=label;tools.add_child(button)
        button.pressed.connect(_copy_selected if label=="Copy selected" else _copy_filtered)
    detail_toggle=CheckButton.new();detail_toggle.text="Technical detail";tools.add_child(detail_toggle)
    summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;summary.add_theme_font_size_override("font_size",12);box.add_child(summary)
    var split=VSplitContainer.new();split.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(split)
    tree=Tree.new();tree.hide_root=true;tree.columns=3;tree.column_titles_visible=true
    for i in 3:tree.set_column_title(i,["Capability / requirement","Next step","Exact source / field"][i])
    tree.set_column_expand_ratio(0,3);tree.set_column_expand_ratio(1,3);tree.set_column_expand_ratio(2,4)
    tree.size_flags_vertical=Control.SIZE_EXPAND_FILL;tree.custom_minimum_size.y=220;split.add_child(tree)
    tree.item_selected.connect(_inspect)
    details=TextEdit.new();details.editable=false;details.custom_minimum_size.y=140;details.visible=false;split.add_child(details)
    detail_toggle.toggled.connect(func(value):details.visible=value)
func open(cache:Dictionary,recorded_rows:Array=[],_capability:String="")->void:
    generation+=1;pending={"generation":generation,"cache":cache.duplicate(),"rows":recorded_rows}
    summary.text="Reading current authoring and exact source requirements…"
    entries=[];filtered=[];tree_pending=[];tree_cursor=0;selected_record={};tree.clear();details.text="";build_error=""
    filter.text="";bucket.select(1);group_picker.select(0);refresh_pending=false
    popup_centered(Vector2i(mini(1120,DisplayServer.window_get_size().x-40),mini(650,DisplayServer.window_get_size().y-40)))
    _start()
func _start()->void:
    if worker!=null or pending.is_empty():return
    var request=pending;pending={};worker=Thread.new()
    var error=worker.start(_build.bind(request))
    if error!=OK:
        worker=null;build_error="Cannot start authoring audit: "+error_string(error);summary.text=build_error
static func _gap(requirement:Dictionary)->String:
    if requirement.has("gap_kind"):return requirement.gap_kind
    if requirement.get("availability")=="missing":return "source"
    if requirement.get("implementation")=="missing":return "renderer"
    if requirement.get("status")=="explicit_none":return "explicit_none"
    return "unexercised"
static func _entry(original:Dictionary,group:String)->Dictionary:
    var entry=original.duplicate();entry.group=group;entry.requirements=[]
    for original_requirement in original.get("requirements",[]):
        var row:Dictionary=original_requirement.duplicate();row.gap_kind=_gap(row)
        row.label=row.get("label",str(row.get("phase",""))+" · "+str(row.get("mechanism",row.get("id",""))))
        if row.get("reason")=="persistent_visual_assignment_missing":row.label="Persistent indicator unassigned"
        if row.gap_kind=="authoring_review":row.label="Needs authoring decision · "+row.label
        row.next_step=row.get("next_step",NEXT.get(row.gap_kind,"Inspect the exact source requirement."))
        entry.requirements.append(row)
    return entry
static func _build(request:Dictionary)->Dictionary:
    var all:Array=[]
    var authored=AuthoringAudit.build(request.cache)
    for entry in authored.entries:all.append(_entry(entry,entry.group))
    var conditions=Conditions.build(request.cache,request.rows)
    for entry in conditions.entries:all.append(_entry(entry,"Conditions"))
    var path="res://generated/native_migration_inventory.json"
    var migration:Dictionary={}
    if FileAccess.file_exists(path):
        var read=JSON.parse_string(FileAccess.get_file_as_string(path))
        if read is Dictionary:migration=read
    for asset in migration.get("assets",[]):
        var native:Dictionary=asset.get("native",{});var native_status:String=native.get("status","source_not_mapped")
        var requirements:Array=[]
        for ref in asset.get("references",[]):
            var enabled:bool=ref.get("enabled",true)
            var gap="explicit_none" if not enabled else ("unexercised" if native_status=="imported" else "native_migration")
            requirements.append({"id":str(asset.asset_id)+":"+str(ref.source),"label":native_status.replace("_"," "),"source":ref.source,"status":"explicit_none" if not enabled else "unexercised","gap_kind":gap,"reason":"Existing authored media reference; native source mapping is separate from missing authoring.","next_step":NEXT[gap],"native_status":native_status,"native_source_ids":native.get("source_ids",[]),"registration_status":asset.get("registration",{}).get("status",""),"migration_asset_id":asset.asset_id,"reference_kind":ref.get("kind",""),"gaps":asset.get("gaps",[])})
        all.append({"id":asset.asset_id,"label":asset.asset_id,"group":"Native migration","source":"generated/native_migration_inventory.json","requirements":requirements})
    all.sort_custom(_entry_before)
    var totals={}
    for entry in all:
        entry.requirements.sort_custom(func(a,b):return str(a.source)<str(b.source) if a.source!=b.source else str(a.id)<str(b.id))
        for row in entry.requirements:totals[row.gap_kind]=totals.get(row.gap_kind,0)+1
    var result={"entries":all,"totals":totals,"scope":"Current JSON / native Resource assignments, source presence, renderer support and unexercised work are separate. Native migration is a saved source audit, never an absent-authoring count or a rendered claim.","authoring_scope":authored.scope,"condition_recipes":conditions.entries.size(),"referenced_media_identities":migration.get("assets",[]).size(),"authored_references":migration.get("totals",{}).get("authored_references",0),"registration_references":migration.get("totals",{}).get("registration_references",0),"generation":request.generation}
    # Serialize off the UI thread; only the accepted generation is written.
    return {"report":result,"serialized":JSON.stringify(result,"  "),"generation":request.generation}
static func _entry_before(a:Dictionary,b:Dictionary)->bool:
    for key in ["group","label","id"]:
        if str(a[key])!=str(b[key]):return str(a[key]).nocasecmp_to(str(b[key]))<0
    return false
func _process(_delta:float)->void:
    if worker!=null and not worker.is_alive():
        var built=worker.wait_to_finish();worker=null
        if built is Dictionary and built.get("generation")==generation and built.has("report"):
            report=built.report;entries=report.entries;installed_generation=generation;refresh_pending=true
            group_picker.clear();group_picker.add_item("All capabilities");group_picker.set_item_metadata(0,"")
            var groups={}
            for entry in entries:groups[entry.group]=true
            for group in groups:
                group_picker.add_item(group);group_picker.set_item_metadata(group_picker.item_count-1,group)
            var file=FileAccess.open("res://generated/studio_authoring_worklist.json",FileAccess.WRITE)
            if file!=null:file.store_string(built.serialized)
        elif pending.is_empty():
            build_error="Authoring audit did not return a usable report.";summary.text=build_error
        _start()
    if refresh_pending and installed_generation==generation:_refresh();refresh_pending=false
    var started=Time.get_ticks_usec();var units=0
    while tree_cursor<tree_pending.size() and units<24 and Time.get_ticks_usec()-started<2000:
        var task:Dictionary=tree_pending[tree_cursor]
        var entry:Dictionary=task.entry
        if not tree_groups.has(entry.group):
            var group=tree.create_item(tree.get_root());group.set_text(0,entry.group);group.set_selectable(0,false);tree_groups[entry.group]=group
        elif not task.has("parent"):
            var parent=tree.create_item(tree_groups[entry.group]);parent.set_text(0,entry.label);parent.set_text(1,"Explicit state-only" if entry.get("disposition")=="state_only" and entry.requirements.is_empty() else "%d requirements"%entry.requirements.size());parent.set_metadata(0,entry)
            parent.set_tooltip_text(0,str(entry.id));parent.collapsed=entry.requirements.size()>4
            task.parent=parent;task.next=0
        elif task.next<entry.requirements.size():
            var requirement:Dictionary=entry.requirements[task.next];task.next+=1
            var row=tree.create_item(task.parent);row.set_text(0,_human_label(requirement.label));row.set_text(1,requirement.next_step);row.set_text(2,requirement.source)
            row.set_tooltip_text(0,str(requirement.get("reason","")));row.set_tooltip_text(1,requirement.next_step);row.set_tooltip_text(2,requirement.source);row.set_metadata(0,requirement)
            if requirement.gap_kind in ["authoring_assignment","authoring_review","source","renderer"]:row.set_custom_color(0,Color("eeaa9c"))
        else:tree_cursor+=1
        units+=1
    if tree_cursor==tree_pending.size():tree_pending.clear();tree_cursor=0
static func _human_label(value:String)->String:
    return value.replace("_"," ").capitalize()
func is_prepared()->bool:
    return installed_generation==generation and worker==null and pending.is_empty() and tree_pending.is_empty() and not refresh_pending
static func _in_bucket(row:Dictionary,gap:String)->bool:
    return gap.is_empty() or row.gap_kind==gap or (gap=="authoring_assignment" and row.gap_kind=="authoring_review")
func _refresh()->void:
    tree.clear();tree.create_item();tree_groups.clear();tree_pending.clear();tree_cursor=0;filtered.clear();selected_record={};details.text=""
    var query=filter.text.to_lower();var gap:String=bucket.get_item_metadata(bucket.selected)
    var group:String=group_picker.get_item_metadata(group_picker.selected)
    for entry in entries:
        if not group.is_empty() and entry.group!=group:continue
        var shown:Dictionary=entry.duplicate();shown.requirements=[]
        for row in entry.requirements:
            if not _in_bucket(row,gap):continue
            if not query.is_empty() and query not in (entry.group+" "+entry.label+" "+row.label+" "+row.source+" "+row.get("reason","")).to_lower():continue
            shown.requirements.append(row)
        if shown.requirements.is_empty():
            if not entry.requirements.is_empty() or not gap.is_empty():continue
            if not query.is_empty() and query not in (entry.group+" "+entry.label+" "+entry.id).to_lower():continue
        filtered.append(shown);tree_pending.append({"entry":shown})
    var count=0
    for entry in filtered:count+=entry.requirements.size()
    summary.text="%d matching requirements · %d owners. All %d condition recipes and %d referenced media identities are inventoried. Source availability is not render qualification."%[count,filtered.size(),report.get("condition_recipes",0),report.get("referenced_media_identities",0)]
func _inspect()->void:
    var row=tree.get_selected()
    if row!=null and row.get_metadata(0) is Dictionary:selected_record=row.get_metadata(0);details.text=JSON.stringify(selected_record,"  ")
func _copy_selected()->void:
    if not selected_record.is_empty():DisplayServer.clipboard_set(JSON.stringify(selected_record,"  "))
func _copy_filtered()->void:
    DisplayServer.clipboard_set(JSON.stringify(filtered_report(),"  "))
func filtered_report()->Dictionary:
    return {"capability":group_picker.get_item_text(group_picker.selected),"filter":bucket.get_item_text(bucket.selected),"search":filter.text,"entries":filtered,"scope":report.get("scope","")}
func _exit_tree()->void:
    if worker!=null:worker.wait_to_finish()
