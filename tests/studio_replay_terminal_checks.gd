extends SceneTree
## Exact recorded terminal cuts must drain without advancing beyond the clip.
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("REPLAY_TERMINAL_FAIL ",label)
func fresh(index:Dictionary)->RefCounted:
    var timeline=Recording.restore(index,0)
    timeline.paused=false
    timeline.world_ready=func(_candidate):return true
    return timeline
func run()->void:
    var index=Recording.read("res://.runtime/studio-cases/walk_diagonal-seed3-v2/amber/journal")
    check(index.ok,"Actual diagonal Move journal admitted")
    if index.ok:
        var end=float(index.presentation_end_ms)
        var oracle=Recording.restore(index,end)
        for step_ms in [8.333333333333334,16.67,100.0,end]:
            var timeline=fresh(index)
            for frame in 1000:
                timeline.advance(minf(step_ms,maxf(0,end-timeline.display_ms)))
                if timeline.display_ms==end and not timeline.busy():break
            check(timeline.display_ms==end and not timeline.busy(),"Clamped movement drains at exact terminal cut: "+str(step_ms))
            check(timeline.state==oracle.state and timeline.sequence==oracle.sequence,"Terminal state/cursor matches direct restore: "+str(step_ms))
            check(timeline.completed_group_count==index.groups.size(),"Each actual group completes exactly once: "+str(step_ms))
        var before=fresh(index)
        for frame in 1000:
            before.advance(maxf(0,end-.0001-before.display_ms))
            if before.display_ms>=end-.0001:break
        check(before.busy(),"A cut strictly before the endpoint cannot finish the movement")
        var before_plan=before.replay_plan(end-.0001)
        check(not before_plan.segments.back().complete,"Cumulative replay also retains the strictly earlier prefix")
        var end_plan=before.replay_plan(end)
        check(end_plan.segments.back().complete,"Cumulative replay recognizes the exact absolute endpoint")
        check(before.replay_prepare(end_plan) and before.replay_publish(end_plan),"Exact endpoint prepares and publishes through existing world gate")
        check(not before.busy() and before.state==oracle.state,"Replay endpoint drains and matches direct restore")
    var result={"checks":checks,"failures":failures,"scope":"Real Move journal exact terminal cut across frame sizes, strictly-before cut and cumulative replay; native audio transport is qualified separately."}
    FileAccess.open("res://generated/studio_replay_terminal_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("STUDIO_REPLAY_TERMINAL ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
