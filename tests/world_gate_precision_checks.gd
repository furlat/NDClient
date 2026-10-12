extends SceneTree
const Timeline=preload("res://presentation/timeline.gd")
const Journal=preload("res://sdk/journal.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label)
func _initialize()->void:
    var journal=Journal.new();var opened=journal.open("res://.runtime/gallery-route/journal",true,false)
    if not opened.ok:print(opened);quit(1);return
    var loaded=journal.replay(0)
    if not loaded.ok:print(loaded);quit(1);return
    var state:Dictionary=journal.state.duplicate(true)
    var key:String=state.tiles.keys()[0];var tile:Dictionary=state.tiles[key];state.tiles.erase(key)
    var timeline=Timeline.new();timeline.accept({"kind":"initialization","state":state,"sequence":0})
    var decision={"ready":false,"calls":0}
    timeline.world_ready=func(_candidate):decision.calls+=1;return decision.ready
    timeline.accept({"kind":"operation","groups":[{"id":"precise-staged-support","operation_sequence":1,"operation_end":true,"duration_ms":20.0,
        "actor_tracks":[],"commits":[],"events":[],"staged_tiles":{key:tile},"staged_tile_at_ms":{key:5.0000005}}]})
    timeline.advance(5.0000001)
    check(decision.calls==0 and timeline.staged_tiles().is_empty(),"Ordinary clock stops before exact source staging timestamp")
    timeline.advance(0.000001)
    check(decision.calls==1 and timeline.waiting_for_world and timeline.display_ms==5.0000001 and timeline.staged_tiles().is_empty(),"Sub-microsecond prior sample cannot bypass preparation barrier")
    var candidate:Dictionary=timeline.pending_world
    check(candidate.display_ms==5.0000005 and candidate.presentation_state.tiles.has(key),"Prospective support uses exact authored timestamp")
    decision.ready=true;timeline.advance(5000)
    check(timeline.display_ms==candidate.display_ms and timeline.staged_tiles().has(key),"Delayed acceptance publishes exact point without catch-up")
    timeline.advance(5000)
    check(timeline.display_ms==20.0 and timeline.staged_tiles().is_empty() and not timeline.busy(),"Independent end removal still publishes at group duration")
    FileAccess.open("res://generated/world_gate_precision_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
    print("WORLD_GATE_PRECISION ",checks," ",failures);quit(0 if failures.is_empty() else 1)
