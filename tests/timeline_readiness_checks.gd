extends SceneTree
const Timeline=preload("res://presentation/timeline.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Components=preload("res://presentation/component_renderer.gd")
const Profile=preload("res://frame_profile.gd")
class ClosureHost extends Node:
    var timeline:RefCounted
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func aligned(a:RefCounted,b:RefCounted,label:String)->void:
    check(a.state==b.state and a.display_ms==b.display_ms and a.sequence==b.sequence,label+" state/clock/sequence")
    check(a.trace==b.trace and a.revision==b.revision and a.world_revision==b.world_revision,label+" exact trace/order/revisions")
    check(a.actor_samples()==b.actor_samples() and a.staged_tiles()==b.staged_tiles() and a.staged_actors()==b.staged_actors(),label+" exact authored actor/support samples")
    check(a.waiting_for_media==b.waiting_for_media and a.waiting_for_world==b.waiting_for_world,label+" exact hold flags")
func setup(script:Script,state:Dictionary,groups:Array)->RefCounted:
    var result=script.new()
    result.accept({"kind":"initialization","state":state.duplicate(true),"sequence":0})
    result.accept({"kind":"operation","groups":groups})
    result.world_ready=func(_candidate):return true
    return result
func compare_cpu(state:Dictionary,groups:Array,before:Script,cache:Dictionary)->Dictionary:
    # Exercise the actual pure persistent-closure planning portion of readiness.
    # GPU/resource admission is deliberately excluded; this is not a live result.
    var timings:Array=[[],[]];var callback_times:Array=[[],[]]
    for iteration in 9:
        for index in ([0,1] if iteration%2==0 else [1,0]):
            var host=ClosureHost.new()
            host.timeline=setup(before if index==0 else Timeline,state,groups)
            var renderer=Components.new()
            var callback_usec={"value":0}
            host.timeline.media_ready=func(group):
                var began:int=Time.get_ticks_usec()
                var required=renderer._native_closure([group],host,cache)
                renderer._native_closure(renderer._native_prefetch(required.groups,host),host,cache)
                Components.due_groups(required.groups,host,host.timeline.media_target_ms)
                callback_usec.value+=Time.get_ticks_usec()-began
                return true
            var began:int=Time.get_ticks_usec()
            host.timeline.advance(7)
            timings[index].append((Time.get_ticks_usec()-began)/1000.0)
            callback_times[index].append(callback_usec.value/1000.0)
            host.timeline.media_ready=Callable();host.free()
    return {"before_ms":Profile.distribution(timings[0]),"after_ms":Profile.distribution(timings[1]),
        "before_closure_callbacks_ms":Profile.distribution(callback_times[0]),"after_closure_callbacks_ms":Profile.distribution(callback_times[1]),
        "scope":"Alternating actual first advance plus original pure persistent-closure/due-group callback work; excludes native resource/GPU admission and live scheduling"}
func _initialize()->void:run.call_deferred()
func run()->void:
    var recording="";var oracle_path="";var benchmark:bool=false
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):recording=arg.trim_prefix("--recording=")
        if arg.begins_with("--timeline-oracle="):oracle_path=arg.trim_prefix("--timeline-oracle=")
        if arg=="--benchmark":benchmark=true
    if recording.is_empty() or oracle_path.is_empty():printerr("Requires retained journal and immediate timeline oracle");quit(2);return
    var before:Script=load(oracle_path)
    var protocol=Protocol.new();var cache:Dictionary={}
    var decoded=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(recording+"/0000000000000000.json"))
    check(decoded.ok,"Actual initialization admits")
    var normalized=protocol.normalize("InitializationResponse",decoded.value)
    var state:Dictionary=Reducer.reduce_initialization(normalized.initialization,normalized.content_additions).value
    var records:Array=[];var saved_state:Dictionary={};var saved_groups:Array=[]
    for sequence in range(1,7):
        decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(recording+"/%016d.json"%sequence))
        check(decoded.ok,"Actual operation admits "+str(sequence))
        normalized=protocol.normalize("PlayerOperation",decoded.value)
        var reduced=Reducer._reduce_operation_recorded(state,normalized)
        check(reduced.ok,"Actual canonical transitions reduce "+str(sequence))
        var compiled=Compiler.compile_recorded(state,normalized,cache,reduced.value,reduced.transitions)
        check(compiled.ok,"Actual transitions compile "+str(sequence))
        if sequence==5:saved_state=state;saved_groups=compiled.value.groups
        var source_bytes=var_to_bytes(compiled.value.groups)
        var a=setup(Timeline,state,compiled.value.groups);var b=setup(before,state,compiled.value.groups)
        var calls={"new":0,"old":0,"allowed":false,"world":false}
        a.media_ready=func(_group):calls.new+=1;return calls.allowed
        b.media_ready=func(_group):calls.old+=1;return calls.allowed
        a.world_ready=func(_candidate):return calls.world
        b.world_ready=func(_candidate):return calls.world
        a.advance(7);b.advance(7)
        check(calls.new==1 and calls.old==1,"False readiness/error stops before planner and publication")
        aligned(a,b,"Blocked actual operation "+str(sequence))
        calls.allowed=true
        var attempts:int=0
        while a.busy() and attempts<4000:
            calls.world=attempts%3==2
            var old_new:int=calls.new;var old_old:int=calls.old
            var delta:float=[0.0,7.0,19.0,9000.0][attempts%4]
            a.advance(delta);b.advance(delta)
            check(calls.new-old_new==1,"One readiness call per live advance including pending world")
            check(calls.old-old_old in [1,2],"Original planner checks once or twice")
            aligned(a,b,"Actual operation "+str(sequence)+" step "+str(attempts))
            attempts+=1
        check(not a.busy() and not b.busy(),"Actual operation drains without lost commits")
        check(a.state==reduced.value and var_to_bytes(compiled.value.groups)==source_bytes,"Exact canonical final state and immutable groups")
        records.append({"sequence":sequence,"new_callbacks":calls.new,"old_callbacks":calls.old,"steps":attempts})
        if benchmark and sequence in [5,6]:records.back().cpu=compare_cpu(state,compiled.value.groups,before,cache)
        state=reduced.value
    # Private planner calls do not inherit proof from any previous advance.
    var manual=setup(Timeline,saved_state,saved_groups)
    var calls={"media":0,"allow":false,"replay":0}
    manual.media_ready=func(_group):calls.media+=1;return calls.allow
    var plan=manual._plan_world_advance(7)
    check(calls.media==1 and plan.media_wait,"Independent planner still checks failed readiness")
    plan=manual._plan_world_advance(7,saved_groups[0],8)
    check(calls.media==2 and plan.media_wait,"Different proposed clock cannot reuse proof")
    plan=manual._plan_world_advance(7,saved_groups[0].duplicate(),7)
    check(calls.media==3 and plan.media_wait,"Equal but different group owner cannot reuse proof")
    manual.replay_media_ready=func(_plan):calls.replay+=1;return calls.allow
    var replay=manual.replay_plan(9000)
    check(not manual.replay_prepare(replay) and calls.replay==1,"Replay retains independent failed closure gate")
    calls.allow=true
    check(manual.replay_prepare(replay) and calls.replay==2,"Replay independently retries successful closure")
    check(manual.replay_publish(replay),"Approved replay publishes exact prospective plan")
    var reference=setup(before,saved_state,saved_groups)
    reference.replay_media_ready=func(_plan):return true
    var old_replay=reference.replay_plan(9000)
    check(reference.replay_prepare(old_replay) and reference.replay_publish(old_replay),"Original replay publishes same cut")
    aligned(manual,reference,"Replay exact original output")
    var report={"checks":checks,"failures":failures,"records":records,"scope":"Actual retained six-operation Gallery journal; immediate original timeline state/clock/trace/log/samples; false readiness, held world boundaries, exact-owner/target proof and independent replay gates"}
    FileAccess.open("res://.runtime/timeline-readiness-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TIMELINE_READINESS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
