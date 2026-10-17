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

## The same supports as one float texture over the grid bounds, for receivers
## that derive their mask in the shader: texel = highest eligible terrain step at
## that cell, or -1e30 where there is none. rect = (first cell x, y, width, height).
static func support_image(entries: Array) -> Dictionary:
    var supports := heights(entries)
    if supports.is_empty():
        var empty := Image.create_empty(1, 1, false, Image.FORMAT_RF)
        empty.fill(Color(-1e30, 0, 0))
        return {"image": empty, "rect": Vector4(0, 0, 1, 1)}
    var low := Vector2(INF, INF); var high := -low
    for cell in supports:
        low = low.min(cell); high = high.max(cell)
    var size := Vector2i(high - low) + Vector2i.ONE
    var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RF)
    image.fill(Color(-1e30, 0, 0))
    for cell in supports:
        image.set_pixelv(Vector2i(cell - low), Color(float(supports[cell]), 0, 0))
    return {"image": image, "rect": Vector4(low.x, low.y, size.x, size.y)}
