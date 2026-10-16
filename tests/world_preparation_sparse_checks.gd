extends SceneTree
const World = preload("res://presentation/world.gd")
const Preparation = preload("res://presentation/world_preparation.gd")
const Ground = preload("res://presentation/ground_data.gd")
var checks = 0
var failures: Array = []
var cache = {"world.json":{"terrain":{"stone":{}},"props":{},"stone_wall_straight":{},"wall_corner_faces":{}},
    "environment/index.json":{"doors":{},"props":{},"traps":{}}}
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("WORLD_PREPARATION_SPARSE_FAIL ",label)
func _initialize() -> void:
    for count in [64,8192]: exercise(count)
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual WorldPreparation worker with an unchanged unrelated floor; sparse routing, no live base mutation, cancelled worker completion and source adoption. No rendered-scene/timing acceptance."}))
    quit(0 if failures.is_empty() else 1)
func exercise(count: int) -> void:
    var state = {"tiles":{},"objects":{},"actors":{},"senses":{"visible":[[0,0]],"objects":{},"light_sources":{}}}
    for i in count:
        state.tiles[str(i)+",0"] = {"tile_uuid":"tile-"+str(i),"position":[i,0],"elevation_steps":0,"surface":{"base_material":"stone"}}
    state.objects["wall"] = {"placement":{"kind":"boundary","position":[0,1],"base_height_steps":0,"top_height_steps":3,"boundary_direction":"north"},
        "item":{"item_id":"wall","boundary_structure":{"structure":"wall","material":"stone"}}}
    var base = {}
    World.update_rows(state,cache,base,{"full":true})
    var cells = {}; var visibility = World.current_ids(state,base.boundaries,cells)
    var original = var_to_bytes(base)
    var changed: Dictionary = state.objects["wall"].duplicate(true)
    changed.placement.top_height_steps = 4
    state.objects["wall"] = changed
    var input = {"state":state,"changes":{"full":false,"tiles":{},"objects":{"wall":true},"senses":false,"order":[]},
        "actor_state":state,"staged_actors":{},"actor_samples":{},"actor_loadouts":{},"existing_actors":{},
        "cache":cache.duplicate(),"retained":base,"ground":{},"quarter":0,"basis":Basis.IDENTITY,
        "background":true,"global_rows":false,"visibility":visibility,"visible_cells":cells}
    var task = Preparation.new()
    var worker = WorkerThreadPool.add_task(task._derive.bind(input))
    # Cancellation changes only ownership intent; retain the borrowed base until
    # the task completes, then discard its result without touching publication.
    task.stale = true
    WorkerThreadPool.wait_for_task_completion(worker)
    check(var_to_bytes(base)==original,"Cancelled worker leaves all retained rows/cells untouched at size "+str(count))
    var prepared: Dictionary = task.result
    check(prepared.complete and not prepared.full_membership and prepared.wanted.keys()==["wall"],"Only changed static group is routed at size "+str(count))
    check(prepared.ground.is_empty() and prepared.packets.is_empty() and prepared.geometry.is_empty(),"Unchanged floor and wall bucket directory are not rebuilt at size "+str(count))
    check(prepared.row_patch.resolved==1 and prepared.row_patch.writes.object_rows.size()==1,"One dirty object projected at size "+str(count))
    check(is_same(prepared.visibility,visibility) and is_same(prepared.visible_cells,cells) and prepared.visibility_changes.is_empty(),"Unchanged sight borrows immutable owner sets")
    World.apply_changes(base,prepared.row_patch)
    check(base.result==World.rows(state,cache),"Completed projection matches exhaustive independent source rows")
    task.free()
