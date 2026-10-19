extends SceneTree
## Both independent replay reducers publish every due real-journal prefix at one
## common clock. Readiness holds must publish neither clock, trace nor state.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Timeline=preload("res://presentation/timeline.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("REPLAY_PREFIX_FAIL ",label)
func fresh(index:Dictionary)->RefCounted:
    var timeline=Timeline.new()
    var initial=index.initialization.duplicate(true)
    timeline.accept(initial)
    timeline.accept({"kind":"operation","groups":index.groups.map(func(item):return item.group)})
    return timeline
func observable(timeline:RefCounted)->Dictionary:
    return {"state":timeline.state.duplicate(true),"clock":timeline.display_ms,"sequence":timeline.sequence,
        "revision":timeline.revision,"world_revision":timeline.world_revision,"completed":timeline.completed_group_count,
        "active":timeline.current.get("id",""),"prefix":timeline.commit_index,"queued":timeline.queue.size(),
        "staged_tiles":timeline.staged_tiles(),"staged_actors":timeline.staged_actors(),
        "poses":timeline.actor_samples(),"conditions":timeline.condition_owners.duplicate(true),
        "retained_components":timeline.retained_components,"retained_directions":timeline.retained_directions.duplicate(),
        "crossed_audio":timeline.crossed_audio,
        "trace":timeline.trace.duplicate(true)}
func read_case(name:String)->Dictionary:
    return Recording.compare_case(Recording.read_case(Fixtures.case_record(name)))

func points(bundle:Dictionary)->Array:
    var times={0.0:true,bundle.presentation_end_ms:true}
    for cut in bundle.schedule:
        times[cut.common_ms]=true
        if cut.common_ms>.01:times[cut.common_ms-.01]=true
    for index in bundle.views.values():
        var previous=0.0
        for item in index.groups:
            times[item.start_ms]=true;times[item.start_ms+item.group.duration_ms]=true
            if item.start_ms>previous:times[(previous+item.start_ms)/2.0]=true
            previous=item.start_ms+item.group.duration_ms
            for at in item.group.get("staged_tile_at_ms",{}).values():times[item.start_ms+at]=true
    var result=times.keys();result.sort();return result
func verify_prefix(actual:RefCounted,index:Dictionary,time:float,label:String)->void:
    var expected=Recording.restore(index,time)
    var a=observable(actual);var b=observable(expected)
    # The trace's invalidation counter depends on how many intermediate ticks
    # admitted rows before their commit. The actual rows, ordering and logs must
    # match a direct seek; the number of UI invalidations need not.
    a.trace.erase("revision");b.trace.erase("revision")
    for field in a:
        check(a[field]==b[field],label+": exact common-cut "+field)
func run()->void:
    for name in ["hide","invisibility","oa-jump","oa-jump-lethal","oa-jump-late-lethal"]:
        var bundle=read_case(name)
        check(bundle.ok and bundle.get("comparison",false),name+": actual independent recordings and shared causal schedule: "+str(bundle.get("error","")))
        if not bundle.ok or not bundle.get("comparison",false):continue
        var actors={};var max_segments=0;var zero_groups=0;var prepared_worlds=0
        for id in bundle.views:
            actors[id]=fresh(bundle.views[id])
            for item in bundle.views[id].groups:
                if item.group.duration_ms==0:zero_groups+=1
        var times=points(bundle)
        for time in times:
            var plans={};var before={}
            for id in actors:
                var timeline:RefCounted=actors[id]
                before[id]=observable(timeline)
                plans[id]=timeline.replay_plan(time)
                max_segments=maxi(max_segments,plans[id].segments.size())
                check(plans[id].display_ms==time,name+" "+id+": planner reaches common clock without stopping at one group")
                check(observable(timeline)==before[id],name+" "+id+": planning leaves canonical state/trace/clock untouched")
                check(not timeline.replay_publish(plans[id]),name+" "+id+": unprepared prefix cannot publish")
            # Hold only the second pane's source closure. The first may prepare,
            # but neither independent reducer is published until both are ready.
            var gate={"ready":false}
            actors.blue.replay_media_ready=func(_plan):return gate.ready
            check(actors.amber.replay_prepare(plans.amber),name+": first pane can prepare independently")
            check(not actors.blue.replay_prepare(plans.blue),name+": peer source hold is respected")
            check(not actors.blue.replay_publish(plans.blue),name+": media-held prefix cannot publish")
            for id in actors:check(observable(actors[id])==before[id],name+" "+id+": a peer wait does not expose partial prefix")
            gate.ready=true
            for id in actors:
                var timeline:RefCounted=actors[id]
                if plans[id].boundary:
                    var world_gate={"ready":false,"seen":{}}
                    timeline.world_ready=func(candidate):world_gate.seen=candidate;return world_gate.ready
                    check(not timeline.replay_prepare(plans[id]),name+" "+id+": final world preparation holds publication")
                    var oracle=Recording.restore(bundle.views[id],time)
                    check(world_gate.seen.state==oracle.state and world_gate.seen.presentation_state==oracle.presentation_state(),name+" "+id+": candidate includes final canonical prefix and final staging")
                    check(world_gate.seen.replay and world_gate.seen.replay_groups==plans[id].groups,name+" "+id+": world closure carries every actual due source group")
                    world_gate.ready=true;prepared_worlds+=1
                check(timeline.replay_prepare(plans[id]),name+" "+id+": complete source/world prefix prepares")
            for id in actors:
                check(actors[id].replay_publish(plans[id]),name+" "+id+": both prepared prefixes publish")
                verify_prefix(actors[id],bundle.views[id],time,name+" "+id+" @"+str(time))
                check(not actors[id].replay_publish(plans[id]),name+" "+id+": prefix cannot publish twice")
        for id in actors:
            check(not actors[id].busy(),name+" "+id+": terminal clock drains all equal-time final groups")
            # A single jump must fold the same real staging, removals, condition
            # changes and retained tails as incrementally crossing every cut.
            var jump=fresh(bundle.views[id]);var plan=jump.replay_plan(bundle.presentation_end_ms)
            check(jump.replay_prepare(plan) and jump.replay_publish(plan),name+" "+id+": multi-group jump publishes atomically")
            verify_prefix(jump,bundle.views[id],bundle.presentation_end_ms,name+" "+id+" terminal jump")
        evidence.append({"case":name,"common_cuts":times.size(),"zero_duration_groups":zero_groups,"max_groups_in_cut":max_segments,"world_candidates":prepared_worlds})
    var bundle=read_case("hide")
    if not bundle.ok or not bundle.get("comparison",false):finish();return
    var timeline=fresh(bundle.views.amber)
    var plan=timeline.replay_plan(bundle.presentation_end_ms)
    var calls={"live":0}
    timeline.media_ready=func(_group):calls.live+=1;return true
    check(not timeline.replay_prepare(plan) and calls.live==0,"Replay fails closed without closure proof and never invokes live current-group pins for future groups")
    timeline.replay_media_ready=func(_plan):return true
    check(timeline.replay_prepare(plan),"Explicit replay source proof admits the complete received prefix")
    check(timeline.replay_can_publish(plan),"Pair preflight observes the prepared prefix witness")
    var releases={"count":0}
    timeline.replay_media_release=func():releases.count+=1
    timeline.replay_cancel_preparation()
    check(not timeline.replay_can_publish(plan) and not timeline.replay_publish(plan) and releases.count==1,"Cancellation invalidates prepared publication and releases replay source pins")
    check(timeline.replay_prepare(plan),"Canceled plan can be explicitly prepared again while its prefix is current")
    timeline.accept(bundle.views.amber.initialization.duplicate(true))
    check(not timeline.replay_plan_current(plan) and not timeline.replay_publish(plan),"New initialization invalidates old prepared replay prefix")
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Headless actual-journal paired cumulative planning, readiness holds and exact Recording.restore prefix parity; native host/media closure integration is separate."}
    FileAccess.open("res://generated/studio_replay_prefix_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_REPLAY_PREFIX ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
