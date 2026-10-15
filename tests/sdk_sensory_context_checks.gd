extends "res://tests/sdk_retained_transaction_checks.gd"
# Internal Journal ownership acceptance, compared against detached exhaustive
# public reduction. No artwork, rendering or performance claim.
# godot --headless --path <client> --script res://tests/sdk_sensory_context_checks.gd
#   -- --cases=<existing Python reducer oracle>

func _sensory(template: Dictionary, observer: String, added: Array, removed: Array = []) -> Dictionary:
    var event: Dictionary = template.duplicate(true)
    event.observer_uuid=observer
    for key in ["entity_contacts_changed","spatial_effects_changed","object_contacts_changed","effective_light_levels_changed","hazardous_cells_changed"]: event[key]={}
    for key in ["entity_contacts_removed","spatial_effects_removed","object_contacts_removed"]: event[key]=[]
    event.visible_cells_added=added;event.visible_cells_removed=removed;event.seen_cells_added=added
    event.observer_position_changed=false
    return event

func _same_result(actual: Dictionary, expected: Dictionary, label: String) -> void:
    check(actual.ok and expected.ok,label+" accepted")
    if not actual.ok or not expected.ok: return
    check(actual.value==expected.value,label+" complete canonical value")
    check(actual.transitions==expected.transitions,label+" every event-time capture")
    check(actual.value.senses.visible==expected.value.senses.visible,label+" exact visible ordering")
    check(actual.value.senses.seen==expected.value.senses.seen,label+" exact seen ordering")
    check(actual.value.senses.objects.keys()==expected.value.senses.objects.keys(),label+" exact contact insertion ordering")

func _initialize() -> void:
    var path="res://.runtime/sdk-study/reducer-oracle.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--cases="): path=arg.trim_prefix("--cases=")
    var parsed=StrictJSON.new().parse(FileAccess.get_file_as_string(path))
    check(parsed.ok,"Independent Python oracle loads")
    if not parsed.ok: quit(1); return
    var cases={}
    for row in parsed.value.cases: cases[row.name]=row
    var fixture: Dictionary=cases["contract/fact/10_item_charge"]
    var state: Dictionary=fixture.arguments[0].duplicate(true)
    var template: Dictionary=fixture.arguments[1]
    var sensory: Dictionary=cases["contract/audience_observe_1"].arguments[2]
    var observers: Array=state.perception.members.keys();observers.sort()
    # Multiple y-values in a column expose a missing nested map fork. Large exact
    # integer coordinates also ensure the retained index never narrows to floats.
    for observer in observers:
        var points=[]
        for x in range(30):
            for y in range(4): points.append([x,y])
        points.append([9007199254740993,7])
        state.perception.members[observer].visible=points
        state.perception.members[observer].seen=points.duplicate(true)
    state.senses=Audience.view(state.perception,state.observer_uuid)
    var cold_packet=_operation(state,template,[_sensory(sensory,observers[0],[[31,0]],[[0,0]])])
    var cold=Reducer._reduce_operation_retained(state,cold_packet,true)
    _same_result(cold,Reducer._reduce_operation_recorded(state,cold_packet),"Cold context")
    if not cold.ok: quit(1);return
    var context: Dictionary=cold.sensory_context
    state=cold.value
    var held=[cold]
    var frozen=[cold.duplicate(true)]
    var spatial: Dictionary=cases["contract/fact/terminal_departure"].arguments[1].events[0].fact
    var steps=[
        [_sensory(sensory,observers[0],[[0,0],[31,1]],[[0,1],[9007199254740993,7]]),_sensory(sensory,observers[1],[[32,2]],[[0,0],[0,1]])],
        [spatial],
        [_sensory(sensory,observers[1],[[0,0],[9007199254740993,7]],[[31,1],[32,2]])],
        [_sensory(sensory,observers[0],[]),_sensory(sensory,observers[1],[])]
    ]
    for i in range(steps.size()):
        var packet=_operation(state,template,steps[i])
        var actual=Reducer._reduce_operation_retained(state,packet,true,null,context)
        _same_result(actual,Reducer._reduce_operation_recorded(state,packet),"Warm operation "+str(i))
        if not actual.ok: continue
        for j in range(held.size()): check(held[j]==frozen[j],"Accepted later operation preserves committed indexes and snapshots "+str(i)+"/"+str(j))
        if i==1:
            check(is_same(actual.value.senses.visible,state.senses.visible),"Non-sensory operation preserves cell array ownership")
            check(is_same(actual.sensory_context.cells.view.source,actual.value.senses),"Copied spatial senses shell becomes committed index source")
        held.append(actual);frozen.append(actual.duplicate(true))
        state=actual.value;context=actual.sensory_context
    # Failed candidates and successful-but-uncommitted candidates must not alter
    # the last accepted context. Retry from that same owner must be exhaustive-equal.
    var packet=_operation(state,template,[_sensory(sensory,observers[0],[[35,2]],[[2,2],[2,3]]),_sensory(sensory,observers[1],[[36,1]],[[2,2]])])
    var bad=packet.duplicate(true)
    bad.hud={"generation":state.generation,"observer_uuid":state.observer_uuid,"revision":packet.lineages[-1].end_cursor+1}
    var before=context.duplicate(true)
    var rejected=Reducer._reduce_operation_retained(state,bad,true,null,context)
    check(not rejected.ok and not rejected.has("sensory_context") and not rejected.has("transitions"),"Late HUD rejects candidate state, context and captures")
    check(context==before,"Late failure leaves all prior index columns and arrays intact")
    var discarded=Reducer._reduce_operation_retained(state,packet,true,null,context)
    check(discarded.ok,"Candidate can finish before external durable commit")
    check(context==before,"Uncommitted success leaves last committed context intact")
    var retry=Reducer._reduce_operation_retained(state,packet,true,null,context)
    _same_result(retry,Reducer._reduce_operation_recorded(state,packet),"Retry from committed context")
    # Same cursor/values are not source ownership. A caller can construct a state
    # whose aggregate view differs from perception; the public full fold is oracle.
    var foreign=state.duplicate(true)
    foreign.senses.visible.append([700,700]);foreign.senses.seen.append([701,701])
    var fallback=Reducer._reduce_operation_retained(foreign,packet,true,null,context)
    _same_result(fallback,Reducer._reduce_operation_recorded(foreign,packet),"Different state owner forces exhaustive composition")
    check(context==before,"Fallback cannot mutate unrelated context")
    # Observer initialization replaces its entire contribution, including seen.
    var reset=_sensory(sensory,observers[0],[[41,4]])
    reset.initial=true;reset.passive_perception=10;reset.visual_access=true
    var reset_packet=_operation(state,template,[reset])
    var reset_result=Reducer._reduce_operation_retained(state,reset_packet,true,null,context)
    _same_result(reset_result,Reducer._reduce_operation_recorded(state,reset_packet),"Observer reset")
    if reset_result.ok:
        var next_packet=_operation(reset_result.value,template,[_sensory(sensory,observers[1],[[42,4]],[[1,1]])])
        _same_result(Reducer._reduce_operation_retained(reset_result.value,next_packet,true,null,reset_result.sensory_context),Reducer._reduce_operation_recorded(reset_result.value,next_packet),"Warm operation after observer reset")
    # Reuse crosses lineage boundaries inside an operation without changing any
    # per-event snapshots or trailing cursor/HUD records.
    var first=_operation(state,template,[_sensory(sensory,observers[0],[[44,0]],[[4,0]])])
    var intermediate=Reducer.reduce_operation(state,first)
    var second=_operation(intermediate.value,template,[_sensory(sensory,observers[1],[[44,1]],[[4,1]])])
    first.lineages.append(second.lineages[0])
    _same_result(Reducer._reduce_operation_retained(state,first,true,null,context),Reducer._reduce_operation_recorded(state,first),"Multi-lineage operation")
    for j in range(held.size()): check(held[j]==frozen[j],"All accepted snapshots survive resets, rejected, discarded and retried candidates "+str(j))
    var report={"checks":checks,"failures":failures,"oracle":path,"scope":"Exact canonical/event-time values and transactional ownership across retained sensory contexts; no timing or rendering claim."}
    FileAccess.open("res://generated/sdk_sensory_context_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_SENSORY_CONTEXT_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
