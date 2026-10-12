extends SceneTree
const Placement = preload("res://placement.gd")
var failures = 0
var checks = 0

func expect(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)

func piece(id: String, role: String, x: float, z: float, h: float, layer: int = 0) -> Dictionary:
    return {"id": id + ":" + str(layer), "role": role, "layer": layer,
        "placement": {"id": id, "position": [x, z], "base_height_steps": h},
        "screen_rect": Rect2(-500, -500, 1000, 1000)}

func ordered(a: Dictionary, b: Dictionary, q: int) -> bool:
    var result = Placement.compose([a, b], q)
    return result.unresolved.is_empty() and result.order == [0, 1]

func _initialize() -> void:
    for q in range(4):
        for h in [0, 2, 4]:
            var floor_piece = piece("floor", "terrain", 0, 0, h)
            var wall = piece("wall", "wall", 0, 0, h)
            wall.placement.boundaries = ["east"]
            expect(ordered(floor_piece, wall, q), "Floor must not crop its wall base: q%s h%s" % [q, h])
            expect(ordered(floor_piece, piece("actor", "body", 0, 0, h), q), "Actor on its support")
        var upper_floor = piece("upper", "terrain", 0, 0, 2)
        expect(ordered(piece("underground", "body", 0, 0, -2), piece("ground", "terrain", 0, 0, 0), q), "Ground covers underground occupant")
        expect(ordered(piece("lower", "body", 0, 0, 0), upper_floor, q), "Upper support covers lower occupant")
        expect(ordered(piece("lower", "shadow", 0, 0, 0), upper_floor, q), "Lower shadow cannot punch through upper support")
        var foregrounds = [Vector2(2, 2), Vector2(2, -2), Vector2(-2, -2), Vector2(-2, 2)]
        var foreground: Vector2 = foregrounds[q]
        expect(ordered(upper_floor, piece("front", "body", foreground.x, foreground.y, 0), q), "Lower foreground actor stays foreground")
        var wall = piece("boundary", "wall", 0, 0, 2)
        wall.placement.boundaries = ["east"]
        var inside = piece("inside", "body", 0.1, 0, 2)
        var outside = piece("outside", "body", 0.9, 0, 2)
        expect(ordered(inside, wall, q) if q in [0, 1] else ordered(wall, inside, q), "Boundary uses edge rather than owner centre (inside)")
        expect(ordered(wall, outside, q) if q in [0, 1] else ordered(outside, wall, q), "Boundary uses edge rather than owner centre (outside)")
        var rug_shadow = piece("rug", "shadow", 0, 0, 2, 0)
        var rug = piece("rug", "covering", 0, 0, 2, 1)
        var straw = piece("straw", "covering", 0, 0, 2, 11)
        rug_shadow.floor_group = true
        rug.floor_group = true
        straw.floor_group = true
        var layers = Placement.compose([rug_shadow, rug, straw, piece("actor", "shadow", 0, 0, 2, 0), piece("actor", "body", 0, 0, 2, 1)], q)
        expect(layers.unresolved.is_empty() and layers.order == [0, 1, 2, 3, 4], "Rug/shadow/straw/actor composition order")
        var p0 = Placement.project(Vector2(1, -2), 0, q)
        var p2 = Placement.project(Vector2(1, -2), 2, q)
        expect(p2 - p0 == Vector2(0, -128), "Height applied once with unchanged owner XY")
    var corner = {"position": [0, 0], "base_height_steps": 0, "boundaries": ["north", "east"]}
    expect(Placement.sort_contact(corner, 0) == Vector2(32, 16), "Corner tie uses frontmost edge then projected X")
    print("PLACEMENT_CHECKS ", checks, " checks; ", failures, " failures")
    quit(1 if failures else 0)
