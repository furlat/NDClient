extends SceneTree
## Real case inventory and timeline layout, without a renderer or fabricated events.
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
const View=preload("res://studio/timeline_view.gd")
const Studio=preload("res://studio/studio.gd")
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
    if directory.is_empty():print("Usage: --recording=<real SDK case journal>");quit(2);return
    var records=Library.read()
    var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_case_inventory.json"))
    check(records.size()==inventory.cases.size(),"Every qualified inventory case is discoverable through its planned capability")
    var blue=0
    for record in records:
        check(Library.CAPABILITIES.has(record.capability) and not record.interaction.is_empty(),"Case belongs to an explicit plan capability / interaction: "+record.id)
        check(not "seed" in record.label and not record.label.is_empty(),"User label describes the case instead of its capture seed: "+record.id)
        for perspective in record.perspectives:
            check(FileAccess.file_exists(perspective.journal.path_join("0000000000000000.json")),"Faction selection points to an actual recorded initialization")
            if perspective.id=="blue":blue+=1
    check(blue>0,"Recorded opposing factions are present in the case browser")
    check(Library.CAPABILITIES.has("Combined regression"),"Required unrecorded capabilities remain named in the browser")
    var data=Recording.read(directory)
    check(data.ok,"Actual source recording compiles")
    if not data.ok:finish(directory);return
    var parents={};var direct={}
    for row in data.rows:
        parents[row.id]=row.parent
        if row.kind!="event":direct[row.parent]=true
    var view=View.new();view.thumbnails.suspended=true;view.size=Vector2(1280,480);root.add_child(view)
    view.set_index(data)
    for id in view.collapsed:view.collapsed[id]=false
    view.rebuild_rows()
    var compact=view.rows.size()
    check(compact<data.rows.size(),"Default timeline compresses undisclosed / sensory / turn scaffolding")
    for item in view.rows:
        var row:Dictionary=item.row
        check(parents[row.id]==row.parent,"Display hierarchy never rewrites causal source parent")
        if row.kind=="event" and row.event.kind in ["undisclosed","sensory","spatial","turn"]:
            check(direct.has(row.id),"Raw scaffolding only remains when it owns a concrete component or missing requirement")
    for row in data.rows:
        if row.kind!="event":check(view.rows.any(func(item):return item.row.id==row.id),"Every source component / required omission survives metadata filtering: "+row.kind)
    view.fit()
    check(is_equal_approx(view._x(data.presentation_end_ms),view.size.x-24),"Explicit Fit uses the complete available timeline width")
    view.size=Vector2(1920,540);await process_frame
    check(is_equal_approx(view._x(data.presentation_end_ms),view.size.x-24),"Fit responds to final layout width after resize")
    view.fit_enabled=false;view.pixels_per_second=123;view.size=Vector2(1280,400);await process_frame
    check(view.pixels_per_second==123,"User zoom survives later resize")
    view.show_metadata=true;view.rebuild_rows()
    check(view.rows.size()==data.rows.size(),"Full original hierarchy is still inspectable on request")
    view.queue_free();await process_frame
    finish(directory)
func finish(directory:String)->void:
    var report={"checks":checks,"failures":failures,"command":"--headless --script res://tests/studio_browser_checks.gd -- --recording="+directory,"scope":"Plan-organized real case inventory and display-only timeline compression/fit. Native layout and faction publication are separate acceptance."}
    FileAccess.open("res://generated/studio_browser_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_BROWSER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
