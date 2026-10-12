extends SceneTree
const Walking = preload("res://walking.gd")
const Placement = preload("res://placement.gd")
const Catalog = preload("res://source_catalog.gd")
var failures = 0
var checks = 0
func expect(value: bool, label: String) -> void:
    checks += 1
    if not value: failures += 1; push_error(label)
func traverse(actor: Dictionary, destination: Vector2, cells: Dictionary, definition: Dictionary) -> bool:
    var start = Vector2(actor.position[0],actor.position[1])
    for i in range(1,101):
        var p = start.lerp(destination,i/100.0)
        var support = Walking.destination(actor,p,cells,definition)
        if support.is_empty(): return false
        actor.position = [p.x,p.y]
        actor.base_height_steps = support.base_height_steps
        actor.support_id = support.id
    return true
func _initialize() -> void:
    var definition = Catalog.read_file("world.json",{}).terrain_stairs
    for direction in ["east","north","west","south"]:
        for height in [-2.0,0.0,4.0]:
            var stairs = {"id":"flight","kind":"stairs","position":[0,0],"base_height_steps":height,"orientation":direction}
            var points = Walking.contacts(stairs,definition)
            var axis = Vector2(points[-1].x,points[-1].z).normalized()
            var low = -axis
            var high = axis*3
            var rows = [stairs,
                {"id":"lower","kind":"terrain","position":[low.x,low.y],"base_height_steps":height},
                {"id":"upper","kind":"terrain","position":[high.x,high.y],"base_height_steps":height+2}]
            var cells = Walking.index(rows,definition)
            var actor = {"id":"actor","kind":"actor","position":[low.x,low.y],"base_height_steps":height,"support_id":"lower"}
            expect(traverse(actor,high,cells,definition) and is_equal_approx(actor.base_height_steps,height+2),"Ascend %s at %s" % [direction,height])
            expect(traverse(actor,low,cells,definition) and is_equal_approx(actor.base_height_steps,height),"Descend %s at %s" % [direction,height])
            for q in range(4):
                var view = Placement.pose(direction,q)
                var pixel_contacts: Array = definition.contacts_px[view]
                for i in range(points.size()):
                    var projection = Placement.project(Vector2(points[i].x,points[i].z),points[i].y-height,q)
                    var pixels = Vector2(pixel_contacts[i][0]-pixel_contacts[0][0],pixel_contacts[i][1]-pixel_contacts[0][1])
                    expect(projection.is_equal_approx(pixels),"Stair art/support contact %s q%s #%s" % [direction,q,i])
                actor.support_id = "flight"
                var entries = [{"id":"stairs","placement":stairs,"role":"body","layer":0,"screen_rect":Rect2(-500,-500,1000,1000)},
                    {"id":"actor","placement":actor,"role":"body","layer":1,"screen_rect":Rect2(-500,-500,1000,1000)}]
                var ordered = Placement.compose(entries,q)
                expect(ordered.order==[0,1] and ordered.unresolved.is_empty(),"Supported actor appears over flight")
    var floors = [{"id":"a","kind":"terrain","position":[0,0],"base_height_steps":0}, {"id":"b","kind":"terrain","position":[1,0],"base_height_steps":1}]
    var actor = {"position":[0.49,0],"base_height_steps":0}
    expect(Walking.destination(actor,Vector2(0.51,0),Walking.index(floors,definition),definition).is_empty(),"Cannot climb unrelated raised floor")
    print("WALKING_CHECKS ",checks," checks; ",failures," failures")
    quit(1 if failures else 0)
