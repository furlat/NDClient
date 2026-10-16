extends SceneTree
# Independent exhaustive projection is the oracle; patch layout is checked only
# for the ownership/scaling contract, never as an expected rendering result.
const World = preload("res://presentation/world.gd")
var checks = 0
var failures: Array = []
var cache = {"world.json":{"terrain":{"stone":{},"grass":{}},"props":{},"stone_wall_straight":{},"stone_wall_corner":{},
    "wall_corner_faces":{"ne":["north","east"],"nw":["north","west"],"se":["south","east"],"sw":["south","west"]}},
    "environment/index.json":{"doors":{},"props":{},"traps":{}}}
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("WORLD_PROJECTION_FAIL ",label)
func tile(id: String, x: int, elevation: int = 0) -> Dictionary:
    return {"tile_uuid":id,"position":[x,0],"elevation_steps":elevation,"surface":{"base_material":"stone"}}
func wall(id: String, direction: String, x: int = 0, destroyed: bool = false) -> Dictionary:
    return {"placement":{"kind":"boundary","position":[x,1],"base_height_steps":0,"top_height_steps":3,"boundary_direction":direction},
        "item":{"item_id":id,"boundary_structure":{"structure":"wall","material":"stone"},
        "integrity":"destroyed" if destroyed else "intact","destruction_outcome":"rubble"}}
func compare(state: Dictionary, base: Dictionary, label: String) -> void:
    check(base.result==World.rows(state,cache),label+": rows and original wall assembly")
    check(base.boundaries==World.boundary_index(state),label+": incident-cell membership and order")
    check(base.negative.is_empty()==World.ground_background(state),label+": negative support eligibility")
func adopt(state: Dictionary, base: Dictionary, changes: Dictionary, label: String) -> Dictionary:
    var before = var_to_bytes(base)
    var patch = World.prepare_changes(state,cache,base,changes)
    check(var_to_bytes(base)==before,label+": preparation leaves base and nested cells untouched")
    World.apply_changes(base,patch)
    compare(state,base,label)
    return patch
func _initialize() -> void:
    for size in [64,8192]: scaling(size)
    var state = {"tiles":{"0,0":tile("floor",0)},"objects":{"b":wall("b","east"),"a":wall("a","north"),"c":wall("c","east",5)},"senses":{}}
    var base = {}
    adopt(state,base,{"full":true},"initial joined wall")
    var snapshot = var_to_bytes(base)
    var candidate = state.duplicate(true)
    candidate.objects["a"] = wall("a","north",0,true)
    var discarded = World.prepare_changes(candidate,cache,base,{"objects":{"a":true}})
    check(discarded.visual_changes.has("a") and discarded.visual_changes.has("b"),"Breaking a joined edge includes the unchanged sibling's visual row")
    check(var_to_bytes(base)==snapshot,"Discarded/cancelled candidate has no effect on retained published data")
    adopt(candidate,base,{"objects":{"a":true}},"broken edge separates corner")
    state = candidate
    var original: Dictionary = state.objects["b"]
    state.objects.erase("b"); state.objects["b"] = original
    adopt(state,base,{"objects":{"b":true},"order":[{"kind":"objects","id":"b","remove":true},{"kind":"objects","id":"b","remove":false}]},"equal remove/readd")
    check(base.object_rows.keys()==["a","c","b"],"Equal final value retains canonical remove/re-add order")
    state.objects.erase("a")
    adopt(state,base,{"objects":{"a":true},"order":[{"kind":"objects","id":"a","remove":true}]},"remove one incident edge")
    state.objects["b"] = wall("b","west",2)
    adopt(state,base,{"objects":{"b":true}},"move edge between cells")
    state.tiles["1,0"] = tile("second",1)
    adopt(state,base,{"tiles":{"1,0":true},"order":[{"kind":"tiles","id":"1,0","remove":false}]},"new tile inserted before object rows")
    state.tiles["0,0"] = tile("replacement-floor",0,-1)
    adopt(state,base,{"tiles":{"0,0":true}},"tile UUID and negative elevation change")
    var unsupported = state.tiles["1,0"].duplicate(true); unsupported.surface.base_material = "unavailable"
    state.tiles["1,0"] = unsupported
    adopt(state,base,{"tiles":{"1,0":true}},"unresolved terrain removes row")
    state.tiles["1,0"] = tile("second",1)
    adopt(state,base,{"tiles":{"1,0":true}},"resolved terrain restores ordered row")
    # Several accepted membership mutations can have equal final sets and values.
    var a = wall("a","north"); state.objects["a"] = a
    adopt(state,base,{"objects":{"a":true},"order":[{"kind":"objects","id":"a","remove":false}]},"append boundary")
    var b: Dictionary = state.objects["b"]
    state.objects.erase("b"); state.objects.erase("a"); state.objects["b"] = b; state.objects["a"] = a
    adopt(state,base,{"objects":{"a":true,"b":true},"order":[{"kind":"objects","id":"b","remove":true},{"kind":"objects","id":"a","remove":true},{"kind":"objects","id":"b","remove":false},{"kind":"objects","id":"a","remove":false}]},"multiple mutation order")
    # The compatibility wrapper alone discovers order for old source fixtures.
    state.objects.erase("c"); state.objects["c"] = wall("c","east",5)
    World.update_rows(state,cache,base,{"objects":{"c":true}})
    compare(state,base,"compatibility full order discovery")
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Pure sparse preparation, cancellation, owner adoption, exhaustive rows/boundary oracles, wall siblings, exact order and scale-independent content delta. No GPU/frame timing claim."}))
    quit(0 if failures.is_empty() else 1)
func scaling(size: int) -> void:
    var state = {"tiles":{},"objects":{},"senses":{}}
    for i in size: state.tiles[str(i)+",0"] = tile("tile-"+str(i),i)
    var base = {}
    adopt(state,base,{"full":true},"large base "+str(size))
    var result_rows: Array = base.result.rows
    var visual_rows: Array = base.result.visual_rows
    var unrelated: Dictionary = base.tile_rows["1,0"]
    var next = tile("tile-0",0,1); state.tiles["0,0"] = next
    var patch = World.prepare_changes(state,cache,base,{"tiles":{"0,0":true}})
    check(patch.resolved==1 and patch.canonical_changes.size()==1 and patch.visual_changes.size()==1,"One changed row at size "+str(size))
    var writes = 0
    for values in patch.writes.values(): writes += values.size()
    check(writes==1 and not patch.rebuild_rows and not patch.rebuild_visual,"One changed index entry with stable row slots at size "+str(size))
    check(World.projected_row(base,patch,"tiles","0,0").base_height_steps==1 and base.tile_rows["0,0"].base_height_steps==0,"Candidate read and published read stay separate")
    World.apply_changes(base,patch)
    check(is_same(result_rows,base.result.rows) and is_same(visual_rows,base.result.visual_rows) and is_same(unrelated,base.tile_rows["1,0"]),"Adoption keeps existing arrays and unrelated row ownership at size "+str(size))
    compare(state,base,"one-row adoption "+str(size))
