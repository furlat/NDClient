extends SceneTree
const Order=preload("res://grid_order.gd")
const Placement=preload("res://placement.gd")
const World=preload("res://presentation/world.gd")
var failures=0
var checks=0
func expect(value: bool,label: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(label)
func _initialize() -> void:
    var origin=Vector2(-0.489921,-0.489921)
    for q in range(4):
        var floor={"position":[origin.x,origin.y],"base_height_steps":2,"layer":0}
        var actor=floor.duplicate(true);actor.base_height_steps=0
        expect(Order.less(Order.key(actor,"body",0,q),Order.key(floor,"terrain",0,q)),"Lower actor remains under its own upper floor")
        var front=origin+Placement.rotate_grid(Vector2(2,0),posmod(4-q,4))
        actor.position=[front.x,front.y]
        expect(Order.less(Order.key(floor,"terrain",0,q),Order.key(actor,"body",0,q)),"Lower foreground actor covers a distant upper floor")
        actor=floor.duplicate(true)
        expect(Order.less(Order.key(floor,"terrain",0,q),Order.key(actor,"body",0,q)),"Actor above a floor covers that floor")
        expect(Order.less(Order.key(actor,"shadow",0,q),Order.key(actor,"body",1,q)),"Painted ground shadow precedes body")
    var authored=JSON.parse_string(FileAccess.get_file_as_string("res://scenes.json"))
    var supports=0
    for scene in authored.scenes:
        var rows={}
        for row in scene.placements:rows[row.id]=row
        for row in scene.placements:
            if not row.has("upper_support_id"):continue
            supports+=1
            expect(rows.has(row.upper_support_id),"Authored upper support exists: "+row.id)
            if not rows.has(row.upper_support_id):continue
            var floor: Dictionary=rows[row.upper_support_id]
            var cell:String=World.cell_key(floor.position)
            var state:Dictionary={"tiles":{cell:{"tile_uuid":floor.id,"position":floor.position,"elevation_steps":floor.base_height_steps,"surface":{"base_material":floor.material}}},
                "objects":{row.id:{"placement":{"position":row.position,"kind":"boundary","boundary_direction":row.orientation,"base_height_steps":row.base_height_steps,"top_height_steps":floor.base_height_steps},
                    "item":{"item_id":"environment.cliff_face","boundary_structure":{"structure":"cliff","material":"stone"}}}},"senses":{}}
            var before:Dictionary=state.duplicate(true)
            var cache:Dictionary={}
            var projected:Dictionary=World.rows(state,cache)
            expect(projected.unresolved.is_empty() and projected.rows.size()==2,"Canonical upper support and cliff resolve: "+row.id)
            if not projected.unresolved.is_empty() or projected.rows.size()!=2:continue
            var upper:Dictionary=projected.rows[0];var cliff:Dictionary=projected.rows[1]
            expect(cliff.base_height_steps==row.base_height_steps and cliff.get("top_height_steps")==floor.base_height_steps,"Cliff source placement preserves both disclosed heights: "+row.id)
            var role:String=cliff.kind if cliff.kind in ["wall","cliff"] else "body"
            for q in range(4):
                expect(Order.less(Order.key(upper,"terrain",int(upper.layer)*10+2,q),Order.key(cliff,role,int(cliff.layer)*10+2,q)),"Canonical upper rim covers its registered support: "+row.id)
            expect(state==before,"Sorting projection preserves canonical cliff/support values: "+row.id)
            if supports==1:
                expect(cliff.kind=="cliff" and cliff.source_kind=="prop" and cliff.asset=="environment.cliff_face","Cliff normalization retains physical semantics and its existing authored stand-in source")
                var retained:Dictionary={}
                expect(World.cached_rows(state,cache,retained).rows==projected.rows,"Cached canonical rows retain the same real cliff/top-height ordering")
                var base:Dictionary={}
                var patch:Dictionary=World.prepare_changes(state,cache,base,{"full":true})
                World.apply_changes(base,patch)
                expect(base.result.rows==projected.rows,"Prepared sparse-world owner publishes the same cliff/top-height rows")
                var changed:Dictionary=state.duplicate(true)
                changed.objects[row.id].placement.top_height_steps+=1
                patch=World.prepare_changes(changed,cache,base,{"objects":{row.id:true}})
                World.apply_changes(base,patch)
                expect(base.object_rows[row.id].sort_height_steps==floor.base_height_steps+1 and base.object_rows[row.id].base_height_steps==row.base_height_steps,
                    "An authoritative upper-height change updates sparse sort height without moving the cliff base")
                var wall:Dictionary=state.duplicate(true)
                wall.objects[row.id].item.boundary_structure.structure="wall"
                var wall_row:Dictionary=World.rows(wall,cache).rows[1]
                expect(not wall_row.has("sort_height_steps") and wall_row.base_height_steps==row.base_height_steps,"The same source used as an ordinary wall retains base ordering")
                var bank:Dictionary=state.duplicate(true)
                bank.objects[row.id].item.boundary_structure.structure="embankment"
                expect(World.rows(bank,cache).rows[1].sort_height_steps==floor.base_height_steps,"Embankments retain the same disclosed upper-rim ordering")
    expect(supports>0,"Checked-in elevation scenes exercise actual registered upper rims")
    print("GRID_ORDER_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"supports":supports}))
    quit(1 if failures else 0)
