extends SceneTree
## Actual authored omissions remain inspectable without an executable component.
const Recording=preload("res://studio/recording.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
const TimelineView=preload("res://studio/timeline_view.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_MISSING_FAIL ",label)
func exposed(view:Control,row:Dictionary)->bool:
    if view.rows.any(func(item):return item.row.id==row.id):return true
    var display:Dictionary=view._display_row(view._display_id(row.id))
    return display.get("kind")=="missing_group" and display.members.any(func(member):return is_same(member,row))
func _initialize()->void:
    var directories:Array=[]
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directories.append(argument.trim_prefix("--recording="))
    if directories.is_empty():print("Usage: --recording=<actual SDK journal> [--recording=<another actual journal>]");quit(2);return
    var observed={"requirements":0,"authored_timing":0,"unresolved_timing":0,"missing_audio":0,"condition_lifecycle":0,"inspection_gaps":0,"unassessed_operations":0}
    for directory in directories:
        var index=Recording.read(directory)
        check(index.ok,"Actual recording compiles: "+directory)
        if not index.ok:continue
        var by_id={}
        for row in index.rows:by_id[row.id]=row
        var view=TimelineView.new();view.size=Vector2(1280,400);view.set_index(index)
        for item in index.groups:
            for event in item.group.events:
                for requirement in event.components:
                    if requirement.status!="missing" or not requirement.get("trace_track_id","").is_empty():continue
                    var matches=index.rows.filter(func(row):return row.kind=="requirement" and row.parent==event.id and is_same(row.requirement,requirement))
                    check(matches.size()==1,"Each exact authored omission gets one occurrence-owned lane: "+requirement.source)
                    if matches.size()!=1:continue
                    var row:Dictionary=matches[0];observed.requirements+=1
                    check(row.reason==requirement.reason and row.source==requirement.get("source_pointer",requirement.source),"Missing lane retains original reason and JSON pointer")
                    check(exposed(view,row),"Exact missing lane is retained by the compact missing-work summary")
                    check(row.coverage.implementation==requirement.get("implementation","missing") and row.coverage.rendered=="not_rendered","Missing lane retains declared implementation readiness without claiming rendering")
                    if requirement.has("gap_kind"):
                        check(row.gap_kind==requirement.gap_kind and row.coverage.inspection==requirement.get("inspection","missing" if requirement.gap_kind=="inspection" else "unassessed"),"Inspection and unassessed gaps remain distinct from absent renderer support")
                        if requirement.gap_kind=="inspection":
                            observed.inspection_gaps+=1
                            check(row.coverage.implementation=="implemented" and row.label.begins_with("Missing inspection"),"Existing renderer is not mislabeled as an absent implementation")
                        elif requirement.gap_kind=="unassessed":
                            observed.unassessed_operations+=1
                            check(row.coverage.implementation=="unassessed" and row.label.begins_with("Unassessed"),"Unassessed fact keeps its uncertainty instead of claiming missing rendering")
                    if requirement.get("timing",{}).get("resolved",false):
                        observed.authored_timing+=1
                        check(row.timing_status=="authored" and row.start_ms==item.start_ms+requirement.timing.start_ms and row.end_ms==item.start_ms+requirement.timing.end_ms,"Exact authored interval is preserved")
                    else:
                        observed.unresolved_timing+=1
                        check(row.timing_status=="unresolved" and row.start_ms==by_id[event.id].start_ms and row.end_ms==row.start_ms,"Unknown schedule is only an occurrence anchor, never an invented duration")
                    var key=view.thumbnails.request(row,row.start_ms,0)
                    check(key.is_empty() and view.thumbnails.pending.is_empty(),"Missing implementation never queues fake imagery")
                    evidence.append({"recording":directory,"label":row.label,"source":row.source,"reason":row.reason,"timing":row.timing_status,"start_ms":row.start_ms,"end_ms":row.end_ms})
        for row in index.rows:
            if row.kind=="requirement" and row.has("owner"):
                check(by_id[row.parent].kind=="condition" and row.owner.id==by_id[row.parent].owner.id,"Missing condition lane retains actual lifetime owner")
                check(exposed(view,row),"Missing condition mechanism remains exposed through its summary")
                if row.reason=="persistent_visual_assignment_missing":
                    check(row.missing_category=="authoring" and row.source.ends_with("/persistent"),"Missing persistent assignment is an exact JSON-authoring gap, not a lost media file")
                if row.source.ends_with("/application_asset_id") or row.source.ends_with("/removal_asset_id"):
                    check(row.coverage.source=="available" and row.coverage.implementation=="missing","Existing entry/release art is distinct from missing execution")
                    check(row.timing_status=="unresolved" and row.end_ms==row.start_ms,"Uncompiled lifecycle gets an honest unscheduled expectation")
            if row.kind!="audio" or row.status!="missing":continue
            observed.missing_audio+=1
            check(exposed(view,row) and not row.reason.is_empty() and not row.source.is_empty(),"Missing recorded bow audio remains inspectable with its reason")
            check(row.missing_category=="source" and row.coverage.implementation=="resolved" and row.coverage.source=="missing","Compiled audio distinguishes implemented mechanism from missing source")
        for owner_row in index.rows:
            if owner_row.kind!="condition":continue
            var covered=Coverage.build(index.cache,[],{owner_row.owner.condition.behavior_id:true})
            for entry in covered.entries:
                for requirement in entry.requirements:
                    if not (requirement.source.ends_with("/application_asset_id") or requirement.source.ends_with("/removal_asset_id")):continue
                    observed.condition_lifecycle+=1
                    var lanes=index.rows.filter(func(row):return row.kind=="requirement" and row.parent==owner_row.id and row.source==requirement.source)
                    check(lanes.size()==(1 if requirement.status=="missing" else 0),"Condition lifecycle worklist follows exact current source/implementation requirement: "+requirement.source)
        view.free()
    check(observed.requirements>0,"Real cases exercise explicit unresolved requirements")
    check(observed.unresolved_timing>0,"Real cases exercise unresolved timing")
    check(observed.inspection_gaps>0 and observed.unassessed_operations>0,"Real cases distinguish implemented but uninspected operations from unassessed facts")
    check(observed.condition_lifecycle>0,"Real condition entry/release requirements are checked independently of whether implementation is now present")
    var report={"checks":checks,"failures":failures,"observed":observed,"evidence":evidence,"command":"--headless --script res://tests/studio_missing_lanes_checks.gd -- "+" ".join(directories.map(func(path):return "--recording="+path)),"scope":"Normative authored omissions and actual compiled missing sources remain visible independently of available renderer components. No invented clocks or preview images."}
    FileAccess.open("res://generated/studio_missing_lanes_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_MISSING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
