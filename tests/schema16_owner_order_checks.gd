extends SceneTree
## Native row captures must survive through the shared compiler, owner clocks
## and Studio history; native child arrays, not receipt indices, order the tree.
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Recording=preload("res://studio/recording.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const BODY="res://tests/fixtures/schema16/fold/v1_a_first_record_carries_the_birth_held_from_then_on.json"
const OWNER="00000000-0000-4000-8000-00000000c001"
const TRANSIENT="00000000-0000-4000-8000-00000000c002"
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("SCHEMA16_OWNER_ORDER_FAIL ",label)

static func member(identity:String)->Dictionary:
    var value={"condition_uuid":identity,"name":"Native owner test","category":"status","behavior_id":"condition.schema16_owner_test"}
    value.state={"condition_uuid":identity,"name":value.name,"category":value.category,"behavior_id":value.behavior_id,
        "semantic_key":value.behavior_id,"tags":[],"removal_triggers":[],"agency_denial":"none","outcome_protections":[],
        "duration":{"duration_type":"rounds","remaining_rounds":2}}
    return value

static func operation(state:Dictionary,actor:String,rows:Array,sequence:int)->Dictionary:
    var at:int=int(state.reducer_cursor)
    return {"generation":state.generation,"observer_uuid":state.observer_uuid,"cursor":{"sequence":sequence},
        "lineages":[{"lineage":at,"root":0,"start_cursor":at,"end_cursor":at+1,
            "events":[{"occurrence":at,"phase":"effect","fact":{"kind":"actor_change","actors":[{"actor_uuid":actor,"rows":rows}]}}],
            "version_rows":{"occurrences":[at],"lineages":[at]}}],"hud":null,"content_additions":[],"combat_log_appends":[]}

func publish(state:Dictionary,packet:Dictionary,timeline:RefCounted,cache:Dictionary,history:Dictionary,intervals:Dictionary,parents:Dictionary)->Dictionary:
    var frozen:Dictionary=state.duplicate(true)
    var folded:Dictionary=Reducer._reduce_operation_retained(state,packet,true)
    check(folded.ok,"Native owner rows fold")
    if not folded.ok:return state
    check(state==frozen,"Folding leaves the earlier owner cut immutable")
    var compiled:Dictionary=Compiler.compile_recorded(state,packet,cache,folded.value,folded.transitions)
    check(compiled.ok,"Native owner rows compile through production presentation")
    if not compiled.ok:return state
    var rows:Array=folded.transitions.lineages[0].events[0].condition_rows
    var group:Dictionary=compiled.value.groups[0]
    check(group.commits[0].get("condition_rows",[])==rows,"Published commit retains every ordered condition row")
    timeline.accept({"kind":"operation","groups":compiled.value.groups})
    timeline.advance(float(group.duration_ms))
    check(timeline.state==folded.value,"Shared timeline publishes the canonical folded after-state")
    var event:String="%s:%s"%[packet.cursor.sequence,group.commits[0].event_uuid]
    Recording._observe_condition_history(history,intervals,parents,group.commits[0].delta.actors,
        timeline.display_ms,event,false,group.commits[0].get("condition_rows",[]))
    return folded.value

func owners()->void:
    var vector:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BODY))
    var state:Dictionary=vector.initial.duplicate(true)
    check(Reducer.enter_body(state,vector.steps[0].input.body).ok,"Original reference body admitted")
    state.senses={"spatial_effects":{}}
    var actor:String=state.actors.keys()[0]
    var timeline=Timeline.new()
    timeline.accept({"kind":"initialization","state":state.duplicate(true),"sequence":0})
    var history:Dictionary={};var intervals:Dictionary={};var parents:Dictionary={};var cache:Dictionary={}
    Recording._observe_condition_history(history,intervals,parents,state.actors,0.0,"",true)
    timeline.advance(100.0)
    var packet:Dictionary=operation(state,actor,[{"field":"condition","condition_uuid":OWNER,"member":member(OWNER)}],1)
    state=publish(state,packet,timeline,cache,history,intervals,parents)
    check(timeline.condition_owners.has(OWNER) and timeline.condition_owners[OWNER].start_ms==100.0,"Application starts the actual displayed owner clock")
    check(history.has(OWNER) and intervals.get(OWNER,[]).size()==1,"Studio records the applied lifetime")
    timeline.advance(150.0)
    packet=operation(state,actor,[{"field":"condition","condition_uuid":OWNER,"consumed":true},
        {"field":"condition","condition_uuid":OWNER,"member":member(OWNER)}],2)
    state=publish(state,packet,timeline,cache,history,intervals,parents)
    var owner:Dictionary=timeline.condition_owners.get(OWNER,{})
    check(owner.get("start_ms")==250.0 and is_inf(owner.get("end_ms",0.0)) and not owner.get("initial",true),"Remove then reapply resets an existing owner clock in native row order")
    check(history.get(OWNER,{}).get("start_ms")==250.0,"Studio uses the same reapplied clock")
    var spans:Array=intervals.get(OWNER,[])
    check(spans.size()==2 and spans[0].start_ms==100.0 and spans[0].end_ms==250.0 and spans[1].start_ms==250.0 and is_inf(spans[1].end_ms),"Studio closes and reopens equal-state intervals on actual remove/reapply")
    check(parents.get(OWNER,{}).get("event_id")=="2:1","Reapplied Studio owner belongs to its real second application")
    timeline.advance(150.0)
    packet=operation(state,actor,[{"field":"condition","condition_uuid":TRANSIENT,"member":member(TRANSIENT)},
        {"field":"condition","condition_uuid":TRANSIENT,"consumed":true}],3)
    state=publish(state,packet,timeline,cache,history,intervals,parents)
    var transient:Dictionary=timeline.condition_owners.get(TRANSIENT,{})
    check(transient.get("start_ms")==400.0 and transient.get("end_ms")==400.0 and transient.get("consumed",false),"Transient application/removal survives its empty final actor snapshot")
    spans=intervals.get(TRANSIENT,[])
    check(history.has(TRANSIENT) and spans.size()==1 and spans[0].start_ms==400.0 and spans[0].end_ms==400.0,"Studio retains the zero-duration real transient lifetime")
    check(parents.get(TRANSIENT,{}).get("event_id")=="3:2" and parents.get(TRANSIENT,{}).get("removal_event")=="3:2","Transient history retains its real application and removal source")
    timeline.advance(150.0)
    packet=operation(state,actor,[{"field":"condition_duration","key":OWNER,"duration":{"duration_type":"rounds","remaining_rounds":1}}],4)
    state=publish(state,packet,timeline,cache,history,intervals,parents)
    check(timeline.condition_owners[OWNER].condition.state.duration.remaining_rounds==1,"Duration-only row actually updates the retained owner member")
    check(timeline.condition_owners[OWNER].start_ms==250.0 and intervals[OWNER].size()==2,"Duration-only update does not restart or append a lifetime")
    timeline.advance(150.0)
    packet=operation(state,actor,[{"field":"condition","condition_uuid":OWNER,"consumed":false}],5)
    state=publish(state,packet,timeline,cache,history,intervals,parents)
    check(timeline.condition_owners[OWNER].start_ms==250.0 and timeline.condition_owners[OWNER].end_ms==700.0,"Later removal closes the new lifetime without changing its start")
    check(intervals[OWNER].back().end_ms==700.0 and parents[OWNER].removal_event=="5:4","Studio closes the reapplied interval at the actual later removal")

func child_order()->void:
    var state:Dictionary=Reducer.empty_state("owner-order","observer")
    state.senses={"spatial_effects":{}}
    var packet={"generation":state.generation,"observer_uuid":state.observer_uuid,"cursor":{"sequence":7},
        "lineages":[{"lineage":0,"root":0,"start_cursor":0,"end_cursor":3,"events":[
            {"occurrence":0,"phase":"effect","fact":null,"children_lineages":[2,1]},
            {"occurrence":1,"phase":"effect","fact":null},
            {"occurrence":2,"phase":"effect","fact":null}],
            "version_rows":{"occurrences":[0,1,2],"lineages":[0,1,2]}}],"hud":null,"content_additions":[],"combat_log_appends":[]}
    var original:Dictionary=packet.duplicate(true)
    var compiled:Dictionary=Compiler.compile(state,packet,{})
    check(compiled.ok,"Nonmonotonic native child group folds and compiles")
    if not compiled.ok:return
    var source:Dictionary=Occurrences.group(packet.lineages[0])
    var graph={"nodes":{},"first":{"0":0,"1":1,"2":2}}
    for node in source.events:graph.nodes[node.lineage_id]=node
    check(Compiler._children(source.root,graph).map(func(node):return node.lineage_id)==["2","1"],"Compiler preserves child-array order instead of first receipt order")
    var timeline=Timeline.new()
    timeline.accept({"kind":"initialization","state":state.duplicate(true),"sequence":0})
    timeline.accept({"kind":"operation","groups":compiled.value.groups})
    timeline.advance(1.0)
    var rows:Array=timeline.event_trace().events
    check(rows.map(func(row):return row.event_uuid)==["0","2","1"],"Public EventTrace presents the native nonmonotonic hierarchy")
    check(rows.size()==3 and rows[1].parent_id==rows[0].id and rows[2].parent_id==rows[0].id,"Reordered public children retain the actual parent identity")
    check(packet==original,"Presentation child metadata does not mutate the native packet")

func run()->void:
    owners();child_order()
    print(JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
