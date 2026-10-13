extends SceneTree
# Typed point variations reuse the existing Python-oracle operation/observer
# fixtures. No protocol schema, server, artwork or recorded journal is invented.
const Reducer = preload("res://sdk/reducer.gd")
const Audience = preload("res://sdk/audience.gd")
const StrictJSON = preload("res://sdk/strict_json.gd")
var checks = 0
var failures: Array = []
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("SDK_CELL_FAIL ",label)

func _initialize() -> void:
    var path = ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--cases="): path=arg.trim_prefix("--cases=")
    if path.is_empty():
        check(false,"Usage: --cases=<Python reducer oracle JSON>")
        finish(path); return
    var parsed = StrictJSON.new().parse(FileAccess.get_file_as_string(path))
    check(parsed.ok,"Existing Python oracle loads")
    if not parsed.ok: finish(path); return
    var cases={}
    for row in parsed.value.cases: cases[row.name]=row
    var args: Array = cases["contract/operation_with_lineage"].arguments.duplicate(true)
    var state: Dictionary=args[0]
    var operation: Dictionary=args[1]
    var observation: Array=cases["contract/audience_observe_1"].arguments.duplicate(true)
    state.perception=observation[0]
    var observer: String=observation[2].observer_uuid
    var member: Dictionary=state.perception.members[observer]
    var high_a=[9007199254740993,-4294967311]
    var high_b=[-4294967400,9007199254740995]
    member.visible=[high_a,[7,-2],high_b,[7,-2],[0,0]]
    member.seen=[high_a,[99,99],high_b,[7,-2],[0,0],[99,99]]
    state.senses=Audience.view(state.perception,state.observer_uuid)
    var lineage: Dictionary=operation.lineages[0]
    var template: Dictionary=lineage.events[0].duplicate(true)
    lineage.events=[]; lineage.version_rows=[]; lineage.observations=[]; lineage.world_updates=[]
    lineage.hud_snapshot=null
    operation.hud=null; operation.combat_log_appends=[]
    var events: Array=[]
    for index in range(5):
        var fact: Dictionary=observation[2].duplicate(true)
        fact.visible_cells_added=[]; fact.visible_cells_removed=[]; fact.seen_cells_added=[]
        fact.effective_light_levels_changed={}; fact.hazardous_cells_changed={}
        if index==0:
            fact.visible_cells_removed=[[7,-2]]
            fact.visible_cells_added=[high_a,[1,1],[1,1]]
            fact.seen_cells_added=[[1,1]]
        elif index==1:
            fact.visible_cells_added=[high_a]
            fact.visible_cells_removed=[[123,456]]
        elif index==2:
            fact.visible_cells_removed=[high_b]
            fact.visible_cells_added=[[7,-2]]
        elif index==3:
            fact.initial=true
            fact.passive_perception=member.passive_perception
            fact.visual_access=member.visual_access
            fact.visible_cells_added=[[8,8]]; fact.seen_cells_added=[[8,8]]
        else:
            fact.visible_cells_removed=[[8,8]]; fact.visible_cells_added=[[8,8]]
        var node: Dictionary=template.duplicate(true)
        node.uuid="00000000-0000-0000-0000-%012d" % (1000+index)
        node.fact=fact; node.canceled=false
        lineage.events.append(node); events.append(fact)
        lineage.version_rows.append({"event_uuid":node.uuid,"source_index":state.reducer_cursor+index+1,"lineage_uuid":node.lineage_uuid})
    lineage.root=lineage.events[-1].duplicate(true)
    lineage.end_cursor=state.reducer_cursor+events.size()+1
    var frozen_state=state.duplicate(true)
    var frozen_operation=operation.duplicate(true)
    var plain=Reducer.reduce_operation(state,operation)
    var recorded=Reducer._reduce_operation_recorded(state,operation)
    check(plain.ok and recorded.ok,"Typed point sequence is accepted by plain and recording boundaries")
    if not plain.ok or not recorded.ok: finish(path); return
    check(plain.value==recorded.value,"Event capture preserves final canonical result")
    check(state==frozen_state and operation==frozen_operation,"Owned fold preserves unsorted caller arrays and facts")
    var expected_visible=[
        [high_b,[0,0],[1,1],high_a],
        [high_b,[0,0],[1,1],high_a],
        [[0,0],[1,1],[7,-2],high_a],[[8,8]],[[8,8]]]
    var expected_seen=[high_b,[0,0],[1,1],[7,-2],[99,99],high_a]
    var reference: Dictionary=state.perception.duplicate(true)
    var captures: Array=recorded.transitions.lineages[0].events
    check(captures.size()==events.size(),"Every sensory boundary retained")
    for index in range(events.size()):
        var step=Audience.observe(reference,state.audience,events[index],state.reducer_cursor+index+1)
        check(step.ok,"Independent public observer fold accepts event")
        if not step.ok: continue
        reference=step.value
        var delta: Dictionary=captures[index].delta
        check(delta.set.perception==reference,"Captured observer version equals independent public fold")
        check(delta.set.senses==Audience.view(reference,state.observer_uuid),"Captured composed version equals exhaustive public view")
        var actual: Dictionary=delta.set.perception.members[observer]
        check(actual.visible==expected_visible[index],"Sorted full-precision visible coordinates at boundary "+str(index))
        check(actual.seen==(expected_seen if index<3 else [[8,8]]),"Seen monotonicity then initial reset at boundary "+str(index))
    # Public calls have no retained context. Reusing and editing a caller-owned
    # snapshot between calls must neither reuse stale lookups nor affect output.
    var public_prior: Dictionary=frozen_state.perception.duplicate(true)
    var first_public=Audience.observe(public_prior,state.audience,events[1],state.reducer_cursor+1)
    check(first_public.ok,"First independent no-context observer call accepts")
    var held_public: Dictionary=first_public.value.duplicate(true)
    public_prior.members[observer].visible.append([41,42])
    public_prior.members[observer].seen.append([41,42])
    var second_public=Audience.observe(public_prior,state.audience,events[1],state.reducer_cursor+1)
    check(second_public.ok and [41,42] in second_public.value.members[observer].visible,"Repeated public call sees caller's edited prior snapshot")
    check(first_public.value==held_public,"Repeated public call leaves its prior returned snapshot detached")
    var frozen_captures=recorded.transitions.duplicate(true)
    state.perception.members[observer].visible.clear()
    operation.lineages[0].events[0].fact.visible_cells_added.clear()
    check(recorded.transitions==frozen_captures,"Caller edits cannot change held event-time point versions")
    var invalid: Dictionary=frozen_operation.duplicate(true)
    invalid.lineages[0].events[-1].fact.effective_light_levels_changed["91,92"]=8
    var rejected_input=frozen_state.duplicate(true)
    var rejected_packet=invalid.duplicate(true)
    var denied=Reducer._reduce_operation_recorded(frozen_state,invalid)
    check(not denied.ok and not denied.has("transitions"),"Late invalid value publishes no partial point history")
    check(frozen_state==rejected_input and invalid==rejected_packet,"Late rejection preserves public state and packet inputs")
    var retry=Reducer._reduce_operation_recorded(frozen_state,frozen_operation)
    check(retry.ok and retry.transitions==frozen_captures,"Valid retry after late rejection preserves exact point history")
    finish(path)

func finish(path: String) -> void:
    var report={"checks":checks,"failures":failures,"oracle":path,
        "command":"Godot --headless --path \"%s\" --script res://tests/sdk_cell_checks.gd -- --cases=\"%s\"" % [ProjectSettings.globalize_path("res://"),path],
        "scope":"Typed existing-fixture sensory deltas, unsorted/duplicate full-precision points, changed/unchanged/reset/readd boundaries, held transition versions and rejection/retry; no rendering or timing claim"}
    FileAccess.open("res://generated/sdk_cell_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_CELL_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
