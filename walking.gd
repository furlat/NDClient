extends RefCounted
const Placement = preload("res://placement.gd")
# Preview walking over authored support records; independent of render visibility.
static func contacts(row: Dictionary, definition: Dictionary) -> Array[Vector3]:
    var result: Array[Vector3] = []
    var rotation = ["east","north","west","south"].find(row.orientation)
    for offset in definition.support_offsets:
        var p = Placement.rotate_grid(Vector2(offset[0],offset[1]),rotation)
        result.append(Vector3(row.position[0]+p.x, row.base_height_steps+offset[2], row.position[1]+p.y))
    return result

static func index(rows: Array, definition: Dictionary) -> Dictionary:
    var cells = {}
    for row in rows:
        if row.kind not in ["terrain","stairs"] or not row.get("walkable",true): continue
        var points: Array = contacts(row,definition) if row.kind == "stairs" else [Vector3(row.position[0],row.base_height_steps,row.position[1])]
        var seen = {}
        for p in points:
            var start = Vector2(p.x,p.z).floor()
            var end = Vector2(p.x+1,p.z+1).floor()
            for x in range(int(start.x),int(end.x)+1):
                for z in range(int(start.y),int(end.y)+1):
                    var cell = Vector2i(x,z)
                    if seen.has(cell): continue
                    seen[cell] = true
                    if not cells.has(cell): cells[cell] = []
                    cells[cell].append(row)
    return cells

static func supports_at(position: Vector2, cells: Dictionary, definition: Dictionary) -> Array:
    var result = []
    var cell = Vector2i((position+Vector2(0.5,0.5)).floor())
    for row in cells.get(cell,[]):
        if row.kind == "terrain":
            if absf(row.position[0]-position.x) <= 0.5 and absf(row.position[1]-position.y) <= 0.5:
                result.append(row)
            continue
        var points = contacts(row,definition)
        for i in range(points.size()-1):
            var a = Vector2(points[i].x,points[i].z)
            var b = Vector2(points[i+1].x,points[i+1].z)
            var axis = (b-a).normalized()
            var along = (position-a).dot(axis)
            var across = absf((position-a).cross(axis))
            var length = a.distance_to(b)
            if across > 0.5 or along < (-0.5 if i==0 else 0.0) or along > length+(0.5 if i==points.size()-2 else 0.0): continue
            result.append({"id":row.id,"kind":"stairs","base_height_steps":lerpf(points[i].y,points[i+1].y,clampf(along/length,0,1))})
            break
    result.sort_custom(func(a,b): return a.base_height_steps < b.base_height_steps)
    return result

static func destination(actor: Dictionary, position: Vector2, cells: Dictionary, definition: Dictionary) -> Dictionary:
    var candidates = supports_at(position,cells,definition)
    var distance = position.distance_to(Vector2(actor.position[0],actor.position[1]))
    # Prefer the declared flight to the ground beneath it. Height change is
    # possible only on that flight, never by stepping onto an unrelated ledge.
    for support in candidates:
        if support.kind == "stairs" and absf(support.base_height_steps-actor.base_height_steps) <= distance+0.0001:
            return support
    for support in candidates:
        if is_equal_approx(support.base_height_steps,actor.base_height_steps): return support
    return {}

static func ray_support(origin: Vector3, ray: Vector3, cells: Dictionary, stairs: Array, definition: Dictionary, heights: Array) -> Dictionary:
    var nearest = INF
    var picked = {}
    for height in heights:
        var point = Plane(Vector3.UP,height*Placement.HEIGHT_UNIT).intersects_ray(origin,ray)
        if point == null:continue
        for support in supports_at(Vector2(point.x,point.z),cells,definition):
            if support.kind == "stairs" or not is_equal_approx(support.base_height_steps,height):continue
            var distance=origin.distance_to(point)
            if distance<nearest:
                nearest=distance
                picked={"point":Vector2(point.x,point.z),"height":height,"support":support}
    for row in stairs:
        var points=contacts(row,definition)
        for i in range(points.size()-1):
            var a=Vector2(points[i].x,points[i].z);var b=Vector2(points[i+1].x,points[i+1].z)
            var axis=(b-a).normalized()
            var slope=(points[i+1].y-points[i].y)/a.distance_to(b)
            var normal=Vector3(-axis.x*slope*Placement.HEIGHT_UNIT,1,-axis.y*slope*Placement.HEIGHT_UNIT).normalized()
            var plane_point=Vector3(a.x,points[i].y*Placement.HEIGHT_UNIT,a.y)
            var point=Plane(normal,normal.dot(plane_point)).intersects_ray(origin,ray)
            if point==null:continue
            var p=Vector2(point.x,point.z);var along=(p-a).dot(axis)
            if absf((p-a).cross(axis))>0.5 or along<0 or along>a.distance_to(b):continue
            var distance=origin.distance_to(point)
            if distance<nearest:
                nearest=distance
                picked={"point":p,"height":point.y/Placement.HEIGHT_UNIT,"support":row,"slope_axis":axis,"slope":slope}
    return picked
