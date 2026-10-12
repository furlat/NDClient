extends RefCounted
# The map is a stack of 2D display layers. No surface-depth decoding or graph.
const Placement = preload("res://placement.gd")
const WIDTH = 7

static func key(row: Dictionary, role: String, layer: int, quarter: int, ground_background: bool = true) -> Array:
    var origin=Vector2(-0.489921,-0.489921)
    var position: Array=row.get("sort_position",row.position)
    var owner=(Vector2(position[0],position[1])-origin).round()
    var point=Placement.rotate_grid(owner,quarter)
    var floor_pass = role == "terrain" or role == "covering"
    var background=ground_background and floor_pass and row.base_height_steps==0
    return [0 if background else 1,row.get("layer",0) if background else point.x+point.y,
        0 if background else point.x-point.y,row.get("sort_height_steps",row.base_height_steps),
        0 if floor_pass else (1 if role=="shadow" else 2),
        Placement.sort_contact(row,quarter).y,layer]

static func less(a: Array,b: Array) -> bool:
    for i in range(WIDTH):
        if a[i]!=b[i]:return a[i]<b[i]
    return false

static func insertion(keys: PackedFloat64Array, value: Array) -> int:
    var low=0
    var high=keys.size()/WIDTH
    while low<high:
        var middle=(low+high)/2
        var before=false
        for i in range(WIDTH):
            if keys[middle*WIDTH+i]!=value[i]:
                before=keys[middle*WIDTH+i]<value[i]
                break
        if before:low=middle+1
        else:high=middle
    return low
