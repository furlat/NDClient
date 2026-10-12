extends RefCounted
# Published tile topology qualifies interior receiving faces. No state/geometry
# inference: source alpha/depth and exposed skirt normals remain untouched.
const DIRECTIONS = [Vector2(1,0),Vector2(0,1),Vector2(-1,0),Vector2(0,-1)]

static func eligible(row: Dictionary) -> bool:
    return row.get("kind","")=="terrain" and row.get("material","")!="water"

static func heights(entries: Array) -> Dictionary:
    var result = {}
    for entry in entries:
        var rows: Array = entry.get("batch_rows",[entry.placement])
        for row in rows:
            if not eligible(row): continue
            var cell = Vector2(row.position[0],row.position[1])
            result[cell] = maxf(float(result.get(cell,-INF)),float(row.base_height_steps))
    return result

static func mask(row: Dictionary, supports: Dictionary) -> int:
    if not eligible(row): return 0
    var cell = Vector2(row.position[0],row.position[1])
    var result = 0
    for i in DIRECTIONS.size():
        var neighbour: Vector2 = cell+DIRECTIONS[i]
        if supports.has(neighbour) and float(supports[neighbour])>=float(row.base_height_steps):
            result |= 1<<i
    return result
