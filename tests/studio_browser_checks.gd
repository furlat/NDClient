extends SceneTree
## Real case inventory and timeline layout, without a renderer or fabricated events.
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
const View=preload("res://studio/timeline_view.gd")
const Studio=preload("res://studio/studio.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Report=preload("res://studio/capability_report.gd")
const Effects=preload("res://presentation/effect_package.gd")
var checks=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_BROWSER_FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var directory=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):directory=arg.trim_prefix("--recording=")
    if directory.is_empty():directory=Fixtures.journal("gallery")
    # The complete durable original-case corpus, independent of whichever live
    # runtime library the human currently has open. Catalog aliases are not new cases.
    var originals:Dictionary={}
    for key in Fixtures.catalog():
        var record:Dictionary=Fixtures.public_case(key)
        if not originals.has(record.id):originals[record.id]=record
    var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Library.SERVER_IDS))
    var coverage:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Library.COVERAGE))
    var typed:Dictionary=Library.declared(load(Library.ABILITIES))
    var inventory:Dictionary=Library.build(snapshot,coverage,{"engine":snapshot.header,"cases":originals.values()},true,typed)
    var records:Array=inventory.records
    check(records.size()==originals.size(),"Every preserved original scenario remains discoverable through its planned capability")
    for kind in typed:
        for id in typed[kind]:
            check(inventory.by_key.has(kind+":"+id),"All typed capabilities stay discoverable, including package-only/internal non-recipes: "+id)
    var blue=0
    for record in records:
        check(Library.CAPABILITIES.has(record.capability) and not record.interaction.is_empty(),"Case belongs to an explicit plan capability / interaction: "+record.id)
        check(not "seed" in record.label and not record.label.is_empty(),"User label describes the case instead of its capture seed: "+record.id)
        for perspective in record.perspectives:
            check(FileAccess.file_exists(perspective.journal.path_join("0000000000000000.json")),"Faction selection points to an actual recorded initialization")
            if perspective.id=="blue":blue+=1
    check(blue>0,"Recorded opposing factions are present in the case browser")
    check(Library.CAPABILITIES.has("Interactions") and inventory.categories.has("Conditions"),"Behavioral interactions and condition capabilities retain their own browser categories")
    var data=Recording.read(directory)
    check(data.ok,"Actual source recording compiles")
    if not data.ok:finish(directory);return
    var acid=Recording.read("res://tests/fixtures/schema16/production-condition-handover/spell.acid_arrow__baseline/20261019T141826.056415Z/amber/journal")
    check(acid.ok,"Actual Acid Arrow original compiles for selected-source inspection")
    if acid.ok:
        var deliveries:Array=acid.rows.filter(func(row):return row.get("component",{}).get("native_clip",{}).get("id")=="bg3-36/acid-arrow/delivery")
        check(not deliveries.is_empty(),"Actual Acid Arrow supplies its authored heavy delivery approach")
        for row in deliveries:
            var component:Dictionary=row.component;var method:Dictionary=Report.native_method(component)
            var selected:Dictionary=Effects.choice(Effects.occurrence_clip(component))
            check(method.approach.id=="runtime-prepared-heavy-effects-20261020" \
                and method.approach.id==component.native_cue.approach,"Inspector names the actual authored Acid approach override")
            check(method.approach.path==selected.approaches[0].path \
                and method.approach.source_phase==selected.approaches[0].source_phase,"Inspector exposes the exact current renderer constructor and source phase")
            check(method.runtime_binding=="not_examined","Correct source inspection does not promote current rendered output")
    var original_rows:Array=data.rows.duplicate(true)
    var parents={};var direct={};var by_id={}
    for row in data.rows:
        parents[row.id]=row.parent;by_id[row.id]=row
    for row in data.rows:
        if row.kind=="event":continue
        var parent:String=row.parent
        while by_id.has(parent):direct[parent]=true;parent=by_id[parent].parent
    var view=View.new();view.thumbnails.suspended=true;view.size=Vector2(1280,480);root.add_child(view)
    view.set_index(data)
    for id in view.collapsed:
        if not str(id).begins_with("display:details:"):view.collapsed[id]=false
    view.rebuild_rows()
    var compact=view.rows.size()
    check(compact<data.rows.size(),"Default timeline compresses undisclosed / sensory / turn scaffolding")
    for item in view.rows:
        var row:Dictionary=item.row
        if parents.has(row.id):check(parents[row.id]==row.parent,"Display hierarchy never rewrites causal source parent")
        if row.kind=="event" and row.event.kind in ["undisclosed","sensory","spatial","turn"]:
            check(direct.has(row.id),"Raw scaffolding only remains when it owns a concrete component or missing requirement")
    for row in data.rows:
        if row.kind not in View.PREVIEW_KINDS and row.get("status")!="missing":continue
        if row.kind=="part" and row.get("status")!="missing":continue # Original equipment hierarchy remains in Details.
        var display:Dictionary=view._display_row(view._display_id(row.id))
        check(not display.is_empty() and (display.id==row.id or (display.get("clips",[])+display.get("cues",[])+display.get("members",[])).any(func(member):return is_same(member,row))),"Every source clip / required omission survives compact grouping unchanged: "+row.kind)
    view.fit()
    check(is_equal_approx(view._x(data.presentation_end_ms),view.size.x-24),"Explicit Fit uses the complete available timeline width")
    view.size=Vector2(1920,540);await process_frame
    check(is_equal_approx(view._x(data.presentation_end_ms),view.size.x-24),"Fit responds to final layout width after resize")
    view.fit_enabled=false;view.pixels_per_second=123;view.size=Vector2(1280,400);await process_frame
    check(view.pixels_per_second==123,"User zoom survives later resize")
    view.show_metadata=true;view.show_lighting_tracks=true
    view.rebuild_rows() # Disclosure creates its own initially folded light headers.
    for id in view.collapsed:view.collapsed[id]=false
    view.rebuild_rows()
    var shown={}
    for item in view.rows:
        var row:Dictionary=item.row
        if parents.has(row.id):shown[row.id]=shown.get(row.id,0)+1;check(row.parent==parents[row.id],"Full hierarchy retains original parent "+row.id)
    check(shown.size()==data.rows.size() and shown.values().all(func(count):return count==1),"Full original hierarchy remains inspectable once per native row, alongside optional display-only light headers")
    check(data.rows==original_rows,"Browser grouping, fit and expansion never mutate original causal rows")
    view.queue_free();await process_frame
    finish(directory)
func finish(directory:String)->void:
    var report={"checks":checks,"failures":failures,"command":"--headless --script res://tests/studio_browser_checks.gd -- --recording="+directory,"scope":"Plan-organized real case inventory and display-only timeline compression/fit. Native layout and faction publication are separate acceptance."}
    FileAccess.open("res://generated/studio_browser_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_BROWSER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
