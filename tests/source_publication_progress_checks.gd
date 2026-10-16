extends SceneTree
## Ordered source publication can continue one proposed clock; actual world
## publication and unavailable preparation keep their existing atomic holds.
const Timeline=preload("res://presentation/timeline.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("SOURCE_PROGRESS_FAIL ",label)
func _initialize()->void:run.call_deferred()
func fixture(world_change:bool=false)->Dictionary:
    var middle={"set":{"reducer_cursor":2}}
    if world_change:middle.set.senses={"visible":[]}
    return {"id":"source-progress","operation_sequence":1,"operation_end":true,"duration_ms":100.0,
        "actor_tracks":[],"actor_source_times":[0.0,40.0],"actor_structure_times":[],
        "commits":[{"at_ms":0.0,"delta":{"set":{"reducer_cursor":1}}},
            {"at_ms":40.0,"delta":middle},{"at_ms":100.0,"delta":{"set":{"reducer_cursor":3}}}],
        "staged_actors":{},"staged_at_ms":{},"staged_tiles":{},"staged_tile_at_ms":{},"components":[]}
func initial()->Dictionary:
    return {"actors":{},"tiles":{},"objects":{},"senses":{},"audience":{},"reducer_cursor":0,
        "spatial_commit_cursors":{},"combat_log_appends":[]}
func run()->void:
    var timeline=Timeline.new()
    timeline.accept({"kind":"initialization","state":initial(),"sequence":0})
    var initial_revision:int=timeline.revision
    timeline.accept({"kind":"operation","groups":[fixture()],"sequence":1})
    var control={"ready":false,"candidate":{},"published":[]}
    timeline.world_ready=func(candidate:Dictionary)->bool:
        if control.candidate.is_empty():control.candidate=candidate
        return control.ready
    timeline.world_published=func(candidate:Dictionary)->bool:
        control.published.append([timeline.display_ms,timeline.state.reducer_cursor,candidate.revision])
        return true
    timeline.advance(25)
    check(timeline.waiting_for_world and timeline.display_ms==0 and timeline.state.reducer_cursor==0,
        "Unprepared source cannot publish state or consume animation time")
    var retained:Dictionary=timeline.pending_world
    timeline.advance(25)
    check(is_same(retained,timeline.pending_world) and control.published.is_empty(),
        "An unfinished source retains its exact ordered candidate without publication")
    control.ready=true
    timeline.advance(25)
    check(timeline.display_ms==25 and timeline.state.reducer_cursor==1 and not timeline.waiting_for_world,
        "Ready source at zero publishes and reaches the original frame target")
    check(control.published==[[0.0,1,initial_revision+1]],"Publication callback sees only the already committed source cut")
    timeline.advance(50)
    check(timeline.display_ms==75 and timeline.state.reducer_cursor==2,
        "An internal source edge retains the unused target remainder")
    check(control.published==[[0.0,1,initial_revision+1],[40.0,2,initial_revision+2]],
        "Source callbacks preserve exact clock and commit order without repeating zero")
    timeline.advance(25)
    check(not timeline.busy() and timeline.display_ms==100 and timeline.state.reducer_cursor==3 and timeline.sequence==1,
        "Source preparation does not delay the operation-end cursor")
    var world=Timeline.new()
    world.accept({"kind":"initialization","state":initial(),"sequence":0})
    var initial_world_revision:int=world.world_revision
    world.accept({"kind":"operation","groups":[fixture(true)],"sequence":1})
    var seen:Array=[]
    world.world_ready=func(_candidate:Dictionary)->bool:return true
    world.world_published=func(candidate:Dictionary)->bool:
        seen.append([world.display_ms,world.state.reducer_cursor,world.world_revision])
        return not candidate.changes.senses
    world.advance(75)
    check(world.display_ms==40 and world.state.reducer_cursor==2 and world.world_revision==initial_world_revision+1,
        "A coincident real world change retains its atomic scene publication yield")
    check(seen==[[0.0,1,initial_world_revision],[40.0,2,initial_world_revision+1]],"Mixed source/world cuts keep their ordered prefix")
    world.advance(35)
    check(world.display_ms==75 and seen.size()==2,
        "Resuming a real world yield does not replay its source edge")
    timeline.world_ready=Callable();timeline.world_published=Callable()
    world.world_ready=Callable();world.world_published=Callable()
    var report={"checks":checks,"failures":failures,"scope":"Exact source/real-world ordered cuts, held preparation, single-target progress and operation cursor."}
    FileAccess.open("res://.runtime/source-publication-progress-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SOURCE_PUBLICATION_PROGRESS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
