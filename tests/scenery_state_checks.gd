extends SceneTree
# Typed subjective-state boundary fixtures. No native encounter is fabricated.
const World = preload("res://presentation/world.gd")
const Order = preload("res://grid_order.gd")
const Placement = preload("res://placement.gd")
const Reveal = preload("res://presentation/wall_reveal.gd")
const Cells = preload("res://sdk/fold_cells.gd")
var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
func object(position: Array, boundary: Variant = null, supported: Variant = null) -> Dictionary:
    return {"placement":{"position":position,"boundary_direction":boundary},"item":{
        "supported_by_uuid":supported,"boundary_structure":{"structure":"wall"} if boundary != null else null}}
func _initialize() -> void:
    var state = {"tiles":{"0,0":{"tile_uuid":"current","position":[0,0],"elevation_steps":0},
        "1,0":{"tile_uuid":"remembered","position":[1,0],"elevation_steps":0}},
        "objects":{"seen":object([0,0]),"old":object([1,0]),"wall":object([1,0],"west"),
            "insert":object([1,0],"west","wall"),"special":object([0,0])},
        "actors":{},"audience":{"controlled":[]},
        "senses":{"visible":Cells.mask([[0,0]]),"objects":{"seen":{"visual":true},"special":{"visual":false}},"entities":{}}}
    var original = state.duplicate(true)
    var actual = World.visibility(state)
    check(actual=={"current":true,"remembered":false,"seen":true,"old":false,"wall":true,"insert":false,"special":false},"Sight and incident-support grants style only known scenery; a hidden insert does not inherit its wall's sight")
    check(not actual.has("unknown") and actual.size()==7,"Visibility styling does not synthesize unknown scenery")
    check(state==original,"Styling leaves exact remembered/canonical after-values untouched")
    state.senses = null
    check(World.visibility(state).values().all(func(value):return not value),"Absent senses never become full sight")
    state = original.duplicate(true)
    state.senses.visible=Cells.mask([]); state.senses.objects={}
    check(World.visibility(state).values().all(func(value):return not value),"Lost sight dims known ground and objects without reviving flames")
    check(World.ground_background(state),"Nonnegative known supports admit the background batching fast path")
    state.tiles["0,0"].elevation_steps=-1
    check(not World.ground_background(state),"Remembered below-zero support disables globally-background floor ordering")
    state.tiles["0,0"].elevation_steps=0
    check(World.ground_background(state),"Removing the lower support restores batch eligibility")
    state.objects.old.placement.base_height_steps=-1
    check(not World.ground_background(state),"A disclosed below-floor object also needs interleaved support ordering")
    state.objects.old.placement.erase("base_height_steps")
    var actor={"uuid":"hidden","present":true,"last_visual_position":[0,0]}
    check(not World.visible_actor(actor,state),"A remembered uncontrolled actor remains absent")
    check(World.visible_actor(actor,state,true),"An admitted staged actor is independently permitted")
    for q in range(4):
        var p=Placement.rotate_grid(Vector2(1,1),posmod(4-q,4))
        var floor={"position":[p.x,p.y],"base_height_steps":0,"layer":0}
        var low={"position":[0,0],"base_height_steps":-1,"layer":1}
        check(Placement.project(Vector2.ZERO,-1,q)==Placement.project(p,0,q),"q%d repro contacts overlap exactly"%q)
        check(Order.less(Order.key(low,"body",0,q,false),Order.key(floor,"terrain",0,q,false)),"q%d front base-zero floor paints over a below-floor actor"%q)
        low.position=floor.position
        check(Order.less(Order.key(low,"body",0,q,false),Order.key(floor,"terrain",0,q,false)),"q%d own upper floor covers lower actor"%q)
        low.base_height_steps=0
        check(Order.less(Order.key(floor,"terrain",0,q,false),Order.key(low,"body",0,q,false)),"q%d standing actor remains above its support"%q)
    var a={"id":"a"};var b={"id":"b"};var source={"wall_members":[a,b]}
    for mode in ["solid","translucent","hidden"]:
        check(Reveal.variants(source,{},mode,{"a":true,"b":false})=={"a":1.0,"b":1.0},"%s mixed-current corner uses exact separate originals"%mode)
        check(Reveal.variants(source,{},mode,{"a":false,"b":false})=={"joined":1.0},"%s equally remembered corner keeps exact joined original"%mode)
    # The server's projector (dnd/player/projection.py _DELTAS) puts north at +y:
    # a north boundary at (0,0) is also observed from (0,1), a south one from (0,-1).
    var edges={"tiles":{},"actors":{},"audience":{"controlled":[]},"objects":{"north":object([0,0],"north"),"south":object([0,0],"south")},
        "senses":{"visible":Cells.mask([[0,1]]),"objects":{},"entities":{}}}
    check(World.visibility(edges)=={"north":true,"south":false},"North boundary is observed from its +y incident cell, like the server's projector")
    check(World.boundary_index(edges).get("0,1",[])==["north"] and World.boundary_index(edges).get("0,-1",[])==["south"],"Boundary incident cells follow the server's north = +y")
    # An engaged trap selects the server's "activated" state, which its owner has.
    var Catalog=load("res://source_catalog.gd");var cache={}
    var trap={"placement":{"position":[0,0],"base_height_steps":0,"kind":"center"},"item":{"item_id":"environment.trap.crusher.stone.workshop","is_engaged":true}}
    var row:Dictionary=World.rows({"tiles":{},"objects":{"trap":trap}},cache).rows[0]
    var owner:Dictionary=Catalog.owner_for(row,cache)
    check(row.state=="activated" and owner.state_frames.has(row.state) and Catalog.environment(row,0,cache).frame==int(owner.state_frames.activated),"Engaged trap rests on its activated frame")
    var report={"checks":checks,"failures":failures,"scope":"Pure current-versus-remembered grants, negative-floor painter relation, and original wall member assembly; native pixels tested separately."}
    var file=FileAccess.open("res://generated/scenery_state_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("SCENERY_STATE_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
