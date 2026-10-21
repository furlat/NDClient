extends SceneTree
## Actual authored catalogs and public on-demand UI; no invented missing recipes.
const Inventory=preload("res://studio/source_inventory.gd")
const Catalog=preload("res://source_catalog.gd")
var checks=0
var failures:Array=[]
var images:Array=[]
var native=false
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_INVENTORY_FAIL ",label)
func prepared(panel:Window)->bool:
    var deadline=Time.get_ticks_msec()+60000
    while not panel.is_prepared() and panel.build_error.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
    var okay=panel.is_prepared()
    check(okay,"Audit and bounded visible rows finish: "+panel.build_error)
    return okay
func choose(panel:Window,index:int,query:String="")->bool:
    panel.bucket.select(index);panel.bucket.item_selected.emit(index)
    panel.filter.text=query;panel.filter.text_changed.emit(query)
    return await prepared(panel)
func rows(panel:Window)->Array:
    var result:Array=[]
    for entry in panel.filtered:result.append_array(entry.requirements)
    return result
func capture(panel:Window,name:String)->void:
    if not native:return
    await process_frame;await RenderingServer.frame_post_draw
    var path="res://.captures/studio/inventory/"+name+".png"
    panel.get_texture().get_image().save_png(path);images.append(path)
func clipboard_matches(expected:String)->bool:
    var deadline=Time.get_ticks_msec()+1500
    while Time.get_ticks_msec()<deadline:
        # Clipboard-change listeners may briefly own the Windows clipboard.
        await create_timer(.125).timeout
        if DisplayServer.clipboard_get().replace("\r\n","\n")==expected:return true
    return false
func run()->void:
    native=DisplayServer.get_name()!="headless"
    if native:DisplayServer.window_set_size(Vector2i(1280,720))
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/inventory")
    var panel=Inventory.new();root.add_child(panel)
    panel.open({})
    check(panel.worker!=null and not panel.is_prepared(),"Opening returns with a private audit worker, without synchronous catalog/UI construction")
    panel.open({}) # New request while old read is running must own the result.
    var latest=panel.generation
    if not await prepared(panel):await finish(panel);return
    check(panel.installed_generation==latest and panel.report.generation==latest,"Superseded audit result cannot replace latest request")
    check(panel.bucket.get_item_text(panel.bucket.selected)=="Missing authoring","Worklist opens at absent authoring decisions/assignments")
    check(not panel.details.visible and not panel.detail_toggle.button_pressed,"No full JSON dump occupies the default worklist")
    var recipes:Dictionary=Catalog.read_file("catalog/condition_recipes.json",{})
    check(panel.report.condition_recipes==recipes.size(),"Every current condition recipe is audited independently of recordings")
    var movement_owners:Array=["condition.dashing","condition.spell.expeditious_retreat","condition.spell.haste","condition.spell.jump"]
    var movement_methods:Array=[]
    for entry in panel.report.entries:
        if entry.id in movement_owners:movement_methods.append_array(entry.requirements.filter(func(row):return row.get("phase")=="movement"))
    check(movement_methods.size()==16 and movement_methods.all(func(row):return row.gap_kind=="unexercised" and row.status=="unexercised" and row.implementation=="implemented" and not row.rendered and row.evidence.is_empty()),"Every actual conditional movement assignment reaches the unexercised bucket; an empty optional override is not a category or draw witness")
    check(Inventory._gap({"gap_kind":"","availability":"missing","implementation":"implemented"})=="source" and Inventory._gap({"gap_kind":"","availability":"available","implementation":"missing"})=="renderer","Empty optional category never hides genuine missing source or renderer facts")
    check(Inventory._gap({"gap_kind":"authoring_review","implementation":"implemented"})=="authoring_review" and Inventory._gap({"gap_kind":"","status":"explicit_none"})=="explicit_none","Explicit ownership decisions and disabled methods retain their own categories")
    var migration:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/native_migration_inventory.json"))
    check(panel.report.referenced_media_identities==migration.assets.size(),"Distinct media identities retain the migration report's exact count")
    check(panel.report.authored_references==migration.totals.authored_references and panel.report.registration_references==migration.totals.registration_references,"Authored and registration references retain separate counts")
    check(rows(panel).all(func(row):return row.gap_kind in ["authoring_assignment","authoring_review"]),"Missing authoring never includes an unmapped native source or renderer limitation")
    var assignments=rows(panel).filter(func(row):return row.get("reason")=="persistent_visual_assignment_missing")
    var missing:Array=[]
    for entry in panel.filtered:
        if entry.requirements.any(func(row):return row.get("reason")=="persistent_visual_assignment_missing"):missing.append(entry.id)
    missing.sort()
    check(missing.is_empty() and assignments.is_empty(),"Actual typed native/delegated decisions are not left in the absent-indicator bucket")
    var resolved_ids:Array=["condition.spell.blindness_deafness","condition.spell.color_spray","class_feature.sorcerer.draconic_presence",
        "condition.concentrating","condition.spell.divine_word","condition.spell.ice_storm.terrain","trait.skeleton_archer_marked",
        "condition.spell.prismatic_spray.restrained","condition.spell.silence.deafened","condition.underwater","condition.environment.wet"]
    var decisions:Array=panel.report.entries.filter(func(entry):return entry.group=="Conditions" and entry.id in resolved_ids)
    check(decisions.size()==resolved_ids.size() and decisions.all(func(entry):return not entry.requirements.any(func(row):return row.get("reason")=="persistent_visual_assignment_missing")),"All eleven existing condition decisions remain in the full browser inventory")
    var marked:Array=decisions.filter(func(entry):return entry.id=="trait.skeleton_archer_marked")
    check(marked.size()==1 and marked[0].requirements.any(func(row):return row.get("source_id")=="condition_guiding_mark_native" and row.source=="res://authoring/abilities/conditions/trait.skeleton_archer_marked.tres::lifecycle_selections/0" and not row.rendered and row.evidence.is_empty()),"Browser exposes the real explicit marker method and its owning Resource without rendered evidence")
    check(rows(panel).any(func(row):return row.gap_kind=="authoring_review" and row.label.begins_with("Needs authoring decision")),"Unresolved ownership is explicitly a decision, not an invented missing effect")
    await capture(panel,"missing-authoring")
    var selected=panel.tree.get_root().get_first_child().get_first_child().get_first_child()
    check(selected!=null,"Default worklist exposes readable requirement children")
    if selected!=null:
        selected.select(0);panel.tree.item_selected.emit()
        check(not panel.selected_record.is_empty() and selected.get_text(2)==panel.selected_record.source and not selected.get_text(1).is_empty(),"Selecting a requirement retains exact pointer and readable next step")
        check(not panel.details.visible,"Selection preserves compact view until technical detail is requested")
        if native:
            var clipboard=DisplayServer.clipboard_get()
            panel._copy_selected()
            check(await clipboard_matches(JSON.stringify(panel.selected_record,"  ")),"Copy selected exports machine keys and exact source requirement")
            panel._copy_filtered()
            check(await clipboard_matches(JSON.stringify(panel.filtered_report(),"  ")),"Copy filtered exports precisely the visible capability-sorted worklist")
            DisplayServer.clipboard_set(clipboard)
    for i in range(2,panel.bucket.item_count):
        if not await choose(panel,i):await finish(panel);return
        var gap:String=panel.bucket.get_item_metadata(i)
        check(rows(panel).all(func(row):return row.gap_kind==gap),"Exact bucket: "+panel.bucket.get_item_text(i))
        check(rows(panel).all(func(row):return not row.source.is_empty() and not row.next_step.is_empty()),"Every child has an actionable pointer: "+gap)
    if not await choose(panel,0):await finish(panel);return
    var all_conditions=panel.filtered.filter(func(entry):return entry.group=="Conditions")
    var state_only=all_conditions.filter(func(entry):return entry.get("disposition")=="state_only")
    var expected_state_only:Array=recipes.keys().filter(func(id):return recipes[id].get("disposition")=="state_only")
    var actual_state_only:Array=state_only.map(func(entry):return entry.id)
    expected_state_only.sort();actual_state_only.sort()
    check(not expected_state_only.is_empty() and actual_state_only==expected_state_only,
        "All includes every exact current state-only owner without inventing or dropping a VFX assignment: "+JSON.stringify(actual_state_only))
    var conditions_group=range(panel.group_picker.item_count).filter(func(i):return panel.group_picker.get_item_metadata(i)=="Conditions")[0]
    panel.group_picker.select(conditions_group);panel.group_picker.item_selected.emit(conditions_group)
    if not await prepared(panel):await finish(panel);return
    check(panel.filtered.all(func(entry):return entry.group=="Conditions") and panel.filtered.size()>160,"Capability filter uses the whole current authoring denominator, including unrecorded backend conditions")
    panel.group_picker.select(0);panel.group_picker.item_selected.emit(0)
    if not await prepared(panel):await finish(panel);return
    var pairs=[]
    for entry in panel.filtered:pairs.append(entry.group+"/"+entry.label)
    var expected=pairs.duplicate();expected.sort_custom(func(a,b):return a.nocasecmp_to(b)<0)
    check(pairs==expected,"Displayed/exported owners are sorted by capability and human label")
    var selected_pointer:String="res://authoring/abilities/conditions/trait.skeleton_archer_marked.tres::lifecycle_selections/0"
    if not await choose(panel,0,selected_pointer):await finish(panel);return
    check(not rows(panel).is_empty() and rows(panel).all(func(row):return row.source==selected_pointer) and rows(panel).any(func(row):return row.get("source_id")=="condition_guiding_mark_native" and not row.rendered),"Exact authored pointer search reaches the actual selected marker method without an obsolete missing-source premise")
    await capture(panel,"persistent-assignments")
    if not await choose(panel,0,selected_pointer+"-not-present"):await finish(panel);return
    check(rows(panel).is_empty() and panel.filtered.is_empty(),"Absent exact pointer search does not manufacture a matching owner or source")
    if native:
        check(panel.tree.get_rect().size.x<=panel.size.x and panel.tree.get_rect().size.y<=panel.size.y,"Compact audit tree fits the native panel")
    var saved=FileAccess.get_file_as_string("res://generated/studio_authoring_worklist.json")
    check(saved==JSON.stringify(panel.report,"  "),"Saved report is the accepted current audit, independent of selected filter")
    await finish(panel)
func finish(panel:Window)->void:
    panel.queue_free();await process_frame
    var report={"checks":checks,"failures":failures,"captures":images,"scope":"Actual live authoring and passive source reports; exact gap categories, pointers, filtering, copy and bounded on-demand UI. No source imports or rendered-coverage claim.","native":native,"command":"--script res://tests/studio_inventory_checks.gd"}
    var path="res://generated/studio_inventory_"+("native" if native else "headless")+"_checks.json"
    FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_INVENTORY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
