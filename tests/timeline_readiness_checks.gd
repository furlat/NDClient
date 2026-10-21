extends SceneTree
## Timeline input/output contracts. No old scheduler or callback-count oracle.
const Timeline=preload("res://presentation/timeline.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Cues=preload("res://presentation/audio_cues.gd")
const Audio=preload("res://presentation/audio_presenter.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("TIMELINE_READINESS_FAIL ",label)
func initial()->Dictionary:
    return {"actors":{},"tiles":{},"objects":{},"senses":{"spatial_effects":{}},
        "spatial_commit_cursors":{},"combat_log_appends":[],"marker":"initial"}
func setup(state:Dictionary,groups:Array)->RefCounted:
    var result=Timeline.new()
    result.accept({"kind":"initialization","state":state.duplicate(true),"sequence":0})
    result.accept({"kind":"operation","groups":groups})
    result.world_ready=func(_candidate):return true
    return result
func group(id:String,ordinal:int,duration:float,last:bool=false,parent:String="")->Dictionary:
    # Small compiler-output fixtures enter through Timeline's public accept boundary.
    var event={"id":"1:"+id,"sequence":1,"event_uuid":id,"source_index":ordinal,
        "first_source_index":ordinal,"parent_id":parent,"components":[],"status":"state_only",
        "reasons":[],"committed":false,"completed":false,"_end_ms":duration,
        "_log":{"text":id,"sub_entries":[]},"_log_parent_id":parent}
    return {"id":id,"operation_sequence":1,"operation_end":last,"duration_ms":duration,
        "actor_tracks":[],"components":[],"staged_actors":{},"staged_tiles":{},"events":[event],
        "commits":[{"at_ms":0.0,"delta":{"set":{"marker":id}},"event_uuid":id}]}
func ids(rows:Array)->Array:
    return rows.map(func(row):return row.id)
func observed(timeline:RefCounted)->Dictionary:
    return {"state":timeline.state.duplicate(true),"display_ms":timeline.display_ms,
        "sequence":timeline.sequence,"events":timeline.event_trace(2000).events,
        "logs":timeline.event_log(2000).entries,"completed":timeline.completed_group_count}
func ready_groups()->void:
    var groups=[group("z-parent",0,0),group("a-child",1,2,false,"1:z-parent"),group("tail",2,3,true)]
    var original=groups.duplicate(true)
    var timeline=setup(initial(),groups)
    timeline.advance(10)
    check(timeline.display_ms==10 and not timeline.busy(),"Ready [0,2,3] groups consume the original 10 ms target")
    check(timeline.state.marker=="tail" and timeline.sequence==1,"Ready completion publishes last ordered state and operation end")
    check(ids(timeline.event_trace().events)==["1:z-parent","1:a-child","1:tail"],"Same-call parent/child order follows source order despite UUID order")
    check(ids(timeline.event_log().entries)==["1:z-parent","1:a-child","1:tail"],"Ordered logs publish once across ready groups")
    timeline.advance(0)
    check(timeline.completed_group_count==3 and timeline.event_log().entries.size()==3,"Repeated zero advance cannot duplicate commits or logs")
    check(groups==original,"Advancement keeps accepted compiler data immutable")
    timeline=setup(initial(),[group("zero-a",0,0),group("zero-b",1,0),group("long",2,100,true)])
    timeline.advance(16)
    check(timeline.display_ms==16 and timeline.completed_group_count==2 and timeline.sequence==0,"Two zero-time groups do not consume the animated group's 16 ms")
    timeline.advance(-20)
    check(timeline.display_ms==16,"Negative delta cannot rewind displayed time")
    timeline=setup(initial(),[group("short",0,2),group("zero-tail",1,0,true)])
    timeline.advance(2)
    check(timeline.display_ms==2 and timeline.sequence==1 and not timeline.busy(),"Exact target includes the ordered zero-time tail")
func media_wait()->void:
    var timeline=setup(initial(),[group("first",0,2),group("second",1,100,true)])
    var gate={"ready":false,"wrong_owner":false}
    timeline.media_ready=func(next):
        if next.get("id")=="second":
            if timeline.state.marker!="first" or timeline.completed_group_count!=1:gate.wrong_owner=true
            return gate.ready
        return true
    timeline.advance(10)
    check(timeline.display_ms==2 and timeline.state.marker=="first" and timeline.waiting_for_media,"Missing next source holds at the completed prefix")
    check(not gate.wrong_owner,"Next source readiness observes preceding group's completed ownership")
    check(ids(timeline.event_trace().events)==["1:first"] and timeline.sequence==0,"Blocked group exposes no event or operation-end cursor")
    var before=observed(timeline)
    timeline.advance(10000)
    check(observed(timeline)==before,"Long media wait cannot publish future state, logs or elapsed time")
    gate.ready=true;timeline.advance(3)
    check(timeline.display_ms==5 and timeline.state.marker=="second" and not timeline.waiting_for_media,"Resume uses only new 3 ms without wait or discarded target debt")
    timeline.media_ready=Callable()
func world_groups()->Array:
    var groups=[group("world-a",0,0),group("world-b",1,0),group("tail",2,0,true)]
    groups[0].commits[0].delta.tiles={"0,0":{"tile_uuid":"a","elevation_steps":0}}
    groups[1].commits[0].delta.tiles={"1,0":{"tile_uuid":"b","elevation_steps":0}}
    return groups
func world_wait()->void:
    var timeline=setup(initial(),world_groups())
    var gate={"ready":false}
    timeline.world_ready=func(_candidate):return gate.ready
    var before=observed(timeline)
    timeline.advance(10);timeline.advance(10000)
    check(observed(timeline)==before and timeline.waiting_for_world,"Unprepared world keeps old coherent prefix through repeated waits")
    gate.ready=true;timeline.advance(3)
    check(timeline.display_ms==0 and timeline.state.marker=="world-a" and timeline.completed_group_count==1,"Zero-time world publication yields before next world cut")
    timeline.advance(3)
    check(timeline.display_ms==0 and timeline.state.marker=="world-b" and timeline.sequence==0,"Second world publication preserves its own ordered draw boundary")
    timeline.advance(3)
    check(timeline.display_ms==3 and timeline.state.marker=="tail" and timeline.sequence==1,"Ready tail resumes without debt from world waits")
func replay_wait()->void:
    var timeline=setup(initial(),world_groups())
    var gate={"media":false,"world":false}
    timeline.replay_media_ready=func(_plan):return gate.media
    timeline.world_ready=func(_candidate):return gate.world
    var before=observed(timeline)
    var plan=timeline.replay_plan(10)
    check(not timeline.replay_prepare(plan) and not timeline.replay_publish(plan),"Unprepared replay cannot publish")
    check(observed(timeline)==before and timeline.component_samples().is_empty(),"Missing replay source exposes no intermediate state, trace or audio")
    gate.media=true
    check(not timeline.replay_prepare(plan) and observed(timeline)==before,"Replay retains target through exact world preparation wait")
    gate.world=true
    check(timeline.replay_prepare(plan) and observed(timeline)==before,"Prepared replay stays private until publication")
    check(timeline.replay_publish(plan) and timeline.display_ms==10 and timeline.sequence==1 and timeline.state.marker=="tail","Replay publishes two world boundaries and zero-time tail at requested cut")
    check(ids(timeline.event_log().entries)==["1:world-a","1:world-b","1:tail"],"Atomic replay retains ordered logs")
    check(not timeline.replay_publish(plan),"Published replay cannot commit twice")
    var stale=timeline.replay_plan(20)
    check(timeline.replay_prepare(stale),"Replay target prepares before a new initialization")
    timeline.accept({"kind":"initialization","state":initial(),"sequence":0})
    check(not timeline.replay_publish(stale) and timeline.state.marker=="initial","New initialization rejects old prepared replay")
func crossed_audio()->void:
    var groups=[group("zero",0,0),group("middle",1,500),group("last",2,0,true)]
    var cues:Array=[]
    for i in groups.size():
        var cue=Cues.resolve("footstep",groups[i].id,i,0,-1,{"world_position":Vector3.ZERO})
        groups[i].components=[cue];cues.append(cue)
    var timeline=setup(initial(),groups)
    var presenter=Audio.new();var host=Node3D.new();root.add_child(host)
    # An empty error list is not worker/voice completion. Establish the same
    # real readiness boundary as the audio presenter gate before the clock run.
    var deadline:int=Time.get_ticks_msec()+30000
    var errors:Array=presenter.prepare(cues,host)
    while not presenter.ready(cues) and errors.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
        errors=presenter.prepare(cues,host)
    var prepared:bool=errors.is_empty() and presenter.ready(cues)
    check(prepared,"Actual authored audio sources prepare")
    if not prepared:presenter.close();host.free();return
    presenter.sample(host,[],0,1,false,0)
    timeline.advance(510)
    var samples=timeline.component_samples()
    check(samples.size()==3 and samples.all(func(row):return row.absolute_start_ms in [0.0,500.0]),"Completed groups retain each crossed audio onset for one sampling pass")
    presenter.sample(host,samples,timeline.display_ms,1,false,0)
    check(presenter.counters.shots==1 and presenter.counters.expired==2,"Only still-live crossed cue starts; fully expired cues skip")
    presenter.sample(host,timeline.component_samples(),timeline.display_ms,1,false,0)
    check(presenter.counters.shots==1 and presenter.counters.expired==2,"Same-time sampling cannot duplicate crossed voices")
    presenter.close();host.free()
func membership_order()->void:
    var state=initial()
    state.tiles={"old":{"tile_uuid":"old"}}
    state.objects={"a":{"uuid":"a"},"b":{"uuid":"b"}}
    var groups=[group("replace",0,0),group("remove",1,0),group("readd",2,0,true)]
    groups[0].commits[0].delta={"objects_removed":["a","a","absent"],
        "tiles":{"old":state.tiles.old,"new":{"tile_uuid":"new"}},
        "objects":{"a":state.objects.a,"b":state.objects.b}}
    groups[1].commits[0].delta={"objects_removed":["b"],"objects":{"c":{"uuid":"c"}}}
    groups[2].commits[0].delta={"objects":{"b":state.objects.b}}
    var expected=[{"kind":"objects","id":"a","remove":true},
        {"kind":"tiles","id":"new","remove":false},{"kind":"objects","id":"a","remove":false},
        {"kind":"objects","id":"b","remove":true},{"kind":"objects","id":"c","remove":false},
        {"kind":"objects","id":"b","remove":false}]
    for prepared in [false,true]:
        var timeline=setup(state,groups)
        if not prepared:timeline.world_ready=Callable()
        var base=timeline.world_revision
        timeline.take_world_changes(-1)
        for i in 3:timeline.advance(0)
        var changes=timeline.take_world_changes(base)
        check(not changes.full and changes.order==expected,"Live membership preserves exact remove/readd order; prepared="+str(prepared))
        check(timeline.state.objects.keys()==["a","c","b"],"Live order matches canonical dictionary mutation")
        check(timeline.take_world_changes(timeline.world_revision).order.is_empty(),"Consumed membership operations do not repeat")
    var timeline=setup(state,groups);var captured={"order":[]}
    timeline.world_ready=func(candidate):captured.order=candidate.changes.order;return true
    var plan=timeline.replay_plan(0)
    check(timeline.replay_prepare(plan) and captured.order==expected,"Prepared replay carries exact ordered membership across its full cut")
    check(timeline.state.objects.keys()==["a","b"],"Candidate membership preparation does not mutate the displayed base")
    check(timeline.replay_publish(plan) and timeline.state.objects.keys()==["a","c","b"],"Prepared membership and published canonical order agree")
func recording_cases(directory:String)->Array:
    var protocol=Protocol.new();var cache:Dictionary={};var results:Array=[]
    var decoded=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory+"/0000000000000000.json"))
    check(decoded.ok,"Actual initialization admits: "+directory+" "+JSON.stringify(decoded.get("error",{})))
    if not decoded.ok:return results
    var normalized=protocol.normalize("InitializationResponse",decoded.value)
    var initialized=Reducer.reduce_initialization(normalized.initialization,normalized.content_additions)
    check(initialized.ok,"Actual initialization reduces")
    if not initialized.ok:return results
    var state:Dictionary=initialized.value
    for sequence in range(1,7):
        var path=directory+"/%016d.json"%sequence
        if not FileAccess.file_exists(path):break
        decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(path))
        check(decoded.ok,"Actual operation admits "+str(sequence)+" "+JSON.stringify(decoded.get("error",{})))
        if not decoded.ok:break
        normalized=protocol.normalize("PlayerOperation",decoded.value)
        var reduced=Reducer._reduce_operation_recorded(state,normalized)
        check(reduced.ok,"Actual canonical transitions reduce "+str(sequence))
        if not reduced.ok:break
        var compiled=Compiler.compile_recorded(state,normalized,cache,reduced.value,reduced.transitions)
        check(compiled.ok,"Actual transitions compile "+str(sequence))
        if not compiled.ok:break
        var groups:Array=compiled.value.groups
        var original=groups.duplicate(true)
        var timeline=setup(state,groups)
        var gate={"media":false,"world":false}
        timeline.media_ready=func(_group):return gate.media
        timeline.world_ready=func(_candidate):return gate.world
        var before=observed(timeline)
        timeline.advance(9000)
        check(observed(timeline)==before,"Actual blocked operation reveals no future prefix "+str(sequence))
        gate.media=true
        var attempts=0
        while timeline.busy() and attempts<4000:
            gate.world=attempts%3==2
            before=observed(timeline)
            timeline.advance([0.0,7.0,19.0,9000.0][attempts%4])
            check(timeline.display_ms>=before.display_ms,"Actual displayed clock remains monotonic "+str(sequence))
            attempts+=1
        check(not timeline.busy(),"Actual operation drains without lost commits "+str(sequence))
        check(timeline.state==reduced.value and groups==original,"Exact canonical final state and immutable groups "+str(sequence))
        var expected_committed:Array=[]
        for value in groups:
            for commit in value.commits:
                if commit.has("event_uuid"):expected_committed.append("%s:%s"%[value.operation_sequence,commit.event_uuid])
        var events:Array=timeline.event_trace(2000).events
        var committed=ids(events.filter(func(event):return event.committed))
        check(committed.size()==expected_committed.size() and expected_committed.all(func(id):return id in committed),"Every real event commits exactly once "+str(sequence))
        var event_ids=ids(events)
        check(events.all(func(event):return event.parent_id.is_empty() or event_ids.find(event.parent_id)<event_ids.find(event.id)),"Real hierarchical trace retains parent/descendant order "+str(sequence))
        var logs=ids(timeline.event_log(2000).entries);var unique={}
        for id in logs:unique[id]=true
        check(unique.size()==logs.size(),"Real log entries never duplicate across waits "+str(sequence))
        results.append({"sequence":sequence,"groups":groups.size(),"steps":attempts,"events":events.size(),"logs":logs.size()})
        state=reduced.value
    check(not results.is_empty(),"Recording exercises at least one admitted operation")
    return results
func _initialize()->void:run.call_deferred()
func run()->void:
    var recordings:Array=[]
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):recordings.append(arg.trim_prefix("--recording="))
    if recordings.is_empty():
        printerr("Usage: --recording=<current-schema journal> [--recording=<another journal>]")
        quit(2);return
    ready_groups();media_wait();world_wait();replay_wait()
    await crossed_audio()
    membership_order()
    var records={}
    for directory in recordings:records[directory]=recording_cases(directory)
    var report={"checks":checks,"failures":failures,"records":records,
        "scope":"Timeline accept/advance/replay semantics, independent named clock/order/wait expectations, actual recorded reducer results and authored headless audio voices. No transport ACK, GPU graphics or live performance claim."}
    FileAccess.open("res://.runtime/timeline-readiness-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TIMELINE_READINESS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
