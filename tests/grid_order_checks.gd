extends SceneTree
const Order=preload("res://grid_order.gd")
const Placement=preload("res://placement.gd")
var failures=0
func expect(value: bool,label: String) -> void:
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
    var map=JSON.parse_string(FileAccess.get_file_as_string("res://generated/unity_map.json"))
    var rows={}
    for row in map.placements:rows[row.id]=row
    var supports=0
    for row in map.placements:
        if not row.has("upper_support_id"):continue
        supports+=1
        var floor: Dictionary=rows[row.upper_support_id]
        for q in range(4):
            expect(Order.less(Order.key(floor,"terrain",int(floor.layer)*10+2,q),Order.key(row,"cliff",int(row.layer)*10+2,q)),"Original upper rim covers its registered support: "+row.id)
    print("GRID_ORDER_CHECKS supports=",supports," failures=",failures)
    quit(1 if failures else 0)
