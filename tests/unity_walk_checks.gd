extends SceneTree
const Walking = preload("res://walking.gd")
const Catalog = preload("res://source_catalog.gd")
func _initialize() -> void:
    var cache={}
    var definition: Dictionary = Catalog.read_file("world.json",cache).terrain_stairs
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/unity_map.json"))
    var cells=Walking.index(data.placements,definition)
    var failures=0
    for row in data.placements:
        if row.kind!="stairs":continue
        var points=Walking.contacts(row,definition)
        var axis=(Vector2(points[-1].x,points[-1].z)-Vector2(points[0].x,points[0].z)).normalized()
        var actor={"position":[points[0].x,points[0].z],"base_height_steps":points[0].y}
        var climbed=true
        for step in range(1,57):
            var p=Vector2(points[0].x,points[0].z)+axis*step*0.05
            var support=Walking.destination(actor,p,cells,definition)
            if support.is_empty():climbed=false;break
            actor.position=[p.x,p.y];actor.base_height_steps=support.base_height_steps
        if not climbed or not is_equal_approx(actor.base_height_steps,points[-1].y):
            failures+=1
            print("STAIR_FAIL ",row.source_cell," base ",row.base_height_steps," stopped ",actor)
        else:print("STAIR_OK ",row.source_cell," ",points[0].y," -> ",actor.base_height_steps)
        if climbed:
            for step in range(55,-1,-1):
                var p=Vector2(points[0].x,points[0].z)+axis*step*0.05
                var support=Walking.destination(actor,p,cells,definition)
                if support.is_empty():climbed=false;break
                actor.position=[p.x,p.y];actor.base_height_steps=support.base_height_steps
            if not climbed or not is_equal_approx(actor.base_height_steps,points[0].y):
                failures+=1
                print("STAIR_DESCENT_FAIL ",row.source_cell," stopped ",actor)
        var midpoint=(points[0]+points[1])*0.5
        var picked=Walking.ray_support(Vector3(midpoint.x,20,midpoint.z),Vector3.DOWN,cells,[row],definition,[0,2,4])
        if picked.is_empty() or not is_equal_approx(picked.height,midpoint.y):
            failures+=1
            print("STAIR_CURSOR_FAIL ",row.source_cell," picked ",picked)
    print("UNITY_STAIRS failures=",failures)
    quit(1 if failures else 0)
