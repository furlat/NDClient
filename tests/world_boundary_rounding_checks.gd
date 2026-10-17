extends SceneTree
## A world commit reached by a clock one rounding below its authored time keeps
## the boundary the preview prepared: same preparation key and display time, and
## the cue reuses the preview's candidate instead of rebuilding it.
const Timeline=preload("res://presentation/timeline.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("WORLD_BOUNDARY_ROUNDING_FAIL ",label)
func _initialize()->void:
    var timeline=Timeline.new()
    timeline.display_ms=1523.683
    timeline.accept({"kind":"initialization","state":{"actors":{},"tiles":{},"objects":{},"senses":{}},"sequence":0})
    var tile={"position":[0,0],"elevation_steps":0}
    var group={"id":"door","operation_sequence":1,"operation_end":true,"duration_ms":500.0,"actor_tracks":[],"events":[],
        "commits":[{"at_ms":250.0,"delta":{"tiles":{"0,0":tile}}}]}
    var decision={"ready":false,"candidates":[]}
    timeline.world_ready=func(candidate):decision.candidates.append(candidate);return decision.ready
    timeline.accept({"kind":"operation","groups":[group]})
    var preview:Dictionary=timeline.preview_world()
    check(not preview.is_empty() and preview.source_local_ms==250.0,"Preview plans the commit at its authored time")
    # The proposed clock lands a rounding below the commit, inside the commit tolerance.
    var local:float=(timeline.display_ms+249.999999999996)-timeline.display_ms
    timeline.advance(249.999999999996)
    check(timeline.waiting_for_world and decision.candidates.size()==1,"The commit inside the tolerance is the world boundary")
    var candidate:Dictionary=decision.candidates.back() if not decision.candidates.is_empty() else {}
    check(local<250.0 and local>=250.0-0.000001,"Proposed clock is one rounding below the commit: "+str(local))
    check(candidate.get("preparation_key")==preview.preparation_key,"Cue candidate keeps the prepared preview's key")
    check(candidate.get("display_ms")==preview.display_ms,"Cue candidate keeps the prepared display time")
    check(is_same(candidate,preview),"Cue reuses the preview candidate")
    decision.ready=true;timeline.advance(0.0)
    check(not timeline.waiting_for_world and timeline.state.tiles.has("0,0") and timeline.display_ms==preview.display_ms,"Publishes the prepared commit at its authored time")
    print("WORLD_BOUNDARY_ROUNDING ",checks," ",failures)
    quit(0 if failures.is_empty() else 1)
