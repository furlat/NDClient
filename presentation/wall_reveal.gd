extends RefCounted
# Visibility belongs to a finite native boundary, never a crop of its artwork.
const Placement = preload("res://placement.gd")

static func footprint(member: Dictionary, quarter: int) -> PackedVector2Array:
    var normal: Vector2 = Placement.DIRECTIONS[member.boundaries[0]]
    var center = Vector2(member.position[0],member.position[1])+normal*.5
    var tangent = Vector2(-normal.y,normal.x)*.5
    var base: float = member.base_height_steps
    var top: float = member.top_height_steps
    return PackedVector2Array([
        Placement.project(center-tangent,base,quarter),
        Placement.project(center+tangent,base,quarter),
        Placement.project(center+tangent,top,quarter),
        Placement.project(center-tangent,top,quarter)])

static func bounds(member: Dictionary, quarter: int) -> Rect2:
    var polygon = footprint(member,quarter)
    var result = Rect2(polygon[0],Vector2.ZERO)
    for point in polygon: result = result.expand(point)
    return result

static func occludes(member: Dictionary, tile: Dictionary, quarter: int) -> bool:
    var normal: Vector2 = Placement.DIRECTIONS[member.boundaries[0]]
    var facing = Placement.rotate_grid(normal,quarter)
    # Explicit user policy: rear room walls always remain solid.
    if facing.x+facing.y <= 0: return false
    var edge = Vector2(member.position[0],member.position[1])+normal*.5
    var position = Vector2(tile.position[0],tile.position[1])
    if (position-edge).dot(normal) >= 0: return false
    var center = Placement.project(position,tile.elevation_steps,quarter)
    var diamond = PackedVector2Array([center+Vector2(-64,0),center+Vector2(0,-32),
        center+Vector2(64,0),center+Vector2(0,32)])
    for overlap in Geometry2D.intersect_polygons(footprint(member,quarter),diamond):
        var twice_area = 0.0
        for i in range(overlap.size()): twice_area += overlap[i].cross(overlap[(i+1)%overlap.size()])
        if absf(twice_area) > .01: return true
    return false

static func variants(source: Dictionary, faded: Dictionary, mode: String, member_visibility: Dictionary = {}) -> Dictionary:
    var result = {}
    for member in source.get("wall_members",[source]):
        result[member.id] = (0.28 if mode=="translucent" else 0.0) if mode!="solid" and faded.has(member.id) else 1.0
    if source.has("wall_members"):
        var values = result.values()
        var same_visibility: bool = member_visibility.get(source.wall_members[0].id,false) == member_visibility.get(source.wall_members[1].id,false)
        if values[0] == values[1] and same_visibility: return {"joined":values[0]}
    return result

static func targets(row: Dictionary, geometry: Dictionary, quarter: int) -> Array:
    var cached: Dictionary = geometry.candidates.get(row.id,{})
    var same_row: bool = cached.get("row",{}) == row
    var rect: Rect2 = cached.rect if same_row else bounds(row,quarter)
    var first: Vector2 = cached.first if same_row else (rect.position/256).floor()
    var last: Vector2 = cached.last if same_row else (rect.end/256).floor()
    var version = 0
    for x in range(int(first.x),int(last.x)+1):
        for y in range(int(first.y),int(last.y)+1):
            version = maxi(version,geometry.versions.get(Vector2i(x,y),0))
    if not same_row or cached.get("version",-1)!=version:
        var candidates: Array = []
        var tested = {}
        for x in range(int(first.x),int(last.x)+1):
            for y in range(int(first.y),int(last.y)+1):
                for target in geometry.buckets.get(Vector2i(x,y),[]):
                    if tested.has(target.cell): continue
                    tested[target.cell] = true
                    if rect.intersects(target.bounds) and occludes(row,target,quarter): candidates.append(target)
        cached = {"row":row,"version":version,"targets":candidates,"rect":rect,"first":first,"last":last}
        geometry.candidates[row.id] = cached
    return cached.targets


static func add_tile(geometry: Dictionary, tile: Dictionary, quarter: int) -> void:
    var cell = "%s,%s" % [tile.position[0],tile.position[1]]
    var center = Placement.project(Vector2(tile.position[0],tile.position[1]),tile.elevation_steps,quarter)
    var bounds = Rect2(center-Vector2(64,32),Vector2(128,64))
    var target = {"position":tile.position,"cell":cell,"center":center,"bounds":bounds,
        "elevation":tile.elevation_steps,"elevation_steps":tile.elevation_steps,"buckets":[]}
    var first = (bounds.position/256).floor()
    var last = (bounds.end/256).floor()
    for x in range(int(first.x),int(last.x)+1):
        for y in range(int(first.y),int(last.y)+1):
            var bucket = Vector2i(x,y)
            if not geometry.buckets.has(bucket): geometry.buckets[bucket] = []
            geometry.buckets[bucket].append(target)
            geometry.versions[bucket] = geometry.revision
            target.buckets.append(bucket)
    geometry.targets[cell] = target

static func prepare_geometry(tiles: Dictionary, visual_rows: Array, quarter: int) -> Dictionary:
    # A worker-owned result from immutable prospective after-values. Do not read
    # or fork the live view: its bucket arrays and candidate map can still be
    # updated by camera/style work while this future boundary is preparing.
    var geometry = {"targets":{},"buckets":{},"versions":{},"revision":1,"candidates":{},
        "pending_tiles":{},"pending_full":false,"pending_objects":false}
    for tile in tiles.values(): add_tile(geometry,tile,quarter)
    for source in visual_rows:
        if source.kind not in ["wall","cliff"]: continue
        # A joined original is an assembly of physical native members. Keep
        # those identities even when mode/current sight later chooses its art.
        for member in source.get("wall_members",[source]): targets(member,geometry,quarter)
    return geometry
