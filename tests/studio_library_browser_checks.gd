extends SceneTree
## Capability discovery and case selection over the single authoring/current-recording join.
const Library=preload("res://studio/case_library.gd")
const WindowScript=preload("res://studio/study_library.gd")
var passed=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
    if value:passed+=1
    else:failures.append(message);print("FAIL "+message)
func run()->void:
    var identity={"commit":"current","protocol_version":1,"player_schema_version":16,"schema_digest":"current-schema"}
    var snapshot={"header":identity,"ids":{"spell":{"spell.fireball":{"level":3,"school":"evocation"},"spell.false_life":{"level":1,"school":"necromancy"}},"condition":{"condition.hidden":{"family":"core"}},"creature":{"creature.goblin":{}},"damage_type":{"Fire":{}}}}
    var coverage={"coverage":{"spell":{"spell.fireball":"ready","spell.false_life":"partial"},"condition":{"condition.hidden":"missing"}}}
    var records={"version":1,"engine":identity,"cases":[{"id":"fireball/hit","title":"Fireball hit","kind":"spell","subjects":{"spell":["spell.fireball"],"creature":["creature.goblin"]},"journals":{"amber":"res://test/amber","blue":"res://test/blue"},"status":"recorded","studio_checked":false,"errors":[],"moments":[{"sequence":3,"occurrence":5,"label":"impact"}]},{"id":"hide/fail","title":"Hide failed","kind":"condition","subjects":{"condition":["condition.hidden"]},"journals":{},"status":"failed","reason":"Real recorder failure"},{"id":"old","title":"Old False Life","kind":"spell","subjects":{"spell":["spell.false_life"]},"journals":{"amber":"res://test/old"},"status":"recorded","engine":{"commit":"old"}}]}
    var report=Library.build(snapshot,coverage,records,false);var keys={}
    for entry in report.entries:keys[entry.key]=true
    check(report.entries.size()==5 and keys.size()==5,"Every server ID appears once, including rule enums")
    check(report.by_key["spell:spell.fireball"].cases[0].id==report.by_key["creature:creature.goblin"].cases[0].id,"One case is reachable from every subject")
    var fire:Dictionary=report.by_key["spell:spell.fireball"]
    check(fire.scenario_status=="recorded" and fire.source_status=="ready" and fire.presentation_status=="not_assessed" and fire.approval_status=="needs_review","Recording and source presence do not claim provider or visual success")
    check(report.by_key["spell:spell.false_life"].scenario_status=="stale" and report.by_key["spell:spell.false_life"].approval_status=="rejected","Stale recordings and user rejection remain explicit")
    check(report.by_key["condition:condition.hidden"].scenario_status=="failed" and report.by_key["condition:condition.hidden"].source_status=="missing","Recorder and art failures remain separate")
    check(report.by_key["damage_type:Fire"].scenario_status=="missing","An ID without a case stays discoverable")
    check(fire.cases[0].perspectives.size()==2 and Library.scenario(fire.cases[0]).moments[0].occurrence==5,"Both original factions and native moments survive browser selection")
    var event={"sequence":3,"event_uuid":"5","lineage_uuid":"2","versions":[{"occurrence":4}]}
    var moments=Library.resolve_moments({"rows":[{"id":"3:5","kind":"event","event":event,"start_ms":250}]},[{"sequence":3,"occurrence":5,"lineage":2},{"sequence":3,"occurrence":4,"lineage":2},{"sequence":4,"occurrence":5,"lineage":2},{"sequence":3,"occurrence":5,"lineage":9}])
    check(moments[0].available and moments[0].at_ms==250 and moments[0].row_id=="3:5","A native moment resolves its exact packet occurrence and lineage")
    check(moments[1].available,"A retained occurrence version resolves the same actual event")
    check(not moments[2].available and not moments[3].available,"Missing or wrong-lineage moments never retarget to another event")
    var window=WindowScript.new();root.add_child(window);window.report=report;window._refresh()
    var capability=window.tree.get_root().get_first_child().get_first_child().get_first_child()
    var emitted:Array=[];window.recording_selected.connect(func(entry,scenario,record):emitted.append({"entry":entry.id,"scenario":scenario.id,"record":record.id}))
    # Directly select the actual Fireball tree row by its data, independent of group layout.
    var pending:Array=[window.tree.get_root()]
    while not pending.is_empty():
        var item:TreeItem=pending.pop_back();var data:Variant=item.get_metadata(0)
        if data is Dictionary and data.capability.id=="spell.fireball" and data.case.is_empty():item.select(0);break
        var child=item.get_first_child()
        while child!=null:pending.append(child);child=child.get_next()
    window._selected()
    check(emitted.size()>=1 and emitted[-1].entry=="spell.fireball" and emitted[-1].record=="fireball/hit","Selecting a capability emits its actual recording immediately")
    window.free()
    var actual=Library.catalog();var expected=0
    for kind in actual.counts:expected+=actual.counts[kind]
    check(actual.entries.size()>=expected and expected>1000,"Current official catalog is fully discoverable")
    print(JSON.stringify({"passed":passed,"failures":failures,"current_ids":expected,"current_cases":actual.records.size()}));quit(0 if failures.is_empty() else 1)
