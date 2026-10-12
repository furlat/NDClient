extends Control
# Screen controls visualize the same world support records used by walking.
const Placement = preload("res://placement.gd")
const Walking = preload("res://walking.gd")
var world: Node3D
var performance = Label.new()
var hover = Label.new()
var notice = Label.new()
var heights: Array = []
var map_index = -1
var redraw_signature: Array = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var help = Label.new()
    help.text = "SMALLSCALE  ·  EXPLORE\nWASD walk   ·   Middle-drag pan   ·   Wheel zoom   ·   Q/E rotate\nG grid   ·   Space follow   ·   Click break   ·   Alt highlight   ·   F8 record / F9 dump"
    help.position = Vector2(20,16)
    help.add_theme_font_size_override("font_size",16)
    add_child(help)
    hover.position = Vector2(20,94)
    add_child(hover)
    performance.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    performance.position = Vector2(20,-60)
    add_child(performance)
    notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    notice.position = Vector2(20,-96)
    notice.add_theme_font_size_override("font_size",13)
    add_child(notice)
    for label in [help,hover,performance,notice]:
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.add_theme_color_override("font_shadow_color",Color.BLACK)
        label.add_theme_constant_override("shadow_offset_x",1)
        label.add_theme_constant_override("shadow_offset_y",2)

func _process(_delta: float) -> void:
    if not is_instance_valid(world.camera):return
    var signature=[get_viewport().get_mouse_position(),world.camera.transform,world.camera.size,world.grid_visible,world.scene_index,world.pending_rows]
    if signature!=redraw_signature:
        redraw_signature=signature
        queue_redraw()

func mouse_support() -> Dictionary:
    if map_index != world.scene_index:
        map_index = world.scene_index
        var unique = {}
        for row in world.placements:
            if row.kind == "terrain" and row.get("walkable",true): unique[row.base_height_steps]=true
        heights = unique.keys()
        heights.sort()
        heights.reverse()
    var mouse = get_viewport().get_mouse_position()
    var origin = world.camera.project_ray_origin(mouse)
    var ray = world.camera.project_ray_normal(mouse)
    return Walking.ray_support(origin,ray,world.support_cells,world.stair_rows,world.stair_definition,heights)

func cell_outline(point: Vector2, height: float, colour: Color, width: float, slope: Dictionary = {}) -> void:
    var points = PackedVector2Array()
    for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5),Vector2(-0.5,-0.5)]:
        var p = point+offset
        var corner_height=height
        if slope.has("slope_axis"):corner_height=slope.height+(p-slope.point).dot(slope.slope_axis)*slope.slope
        points.append(world.camera.unproject_position(Vector3(p.x,corner_height*Placement.HEIGHT_UNIT,p.y)))
    draw_polyline(points,colour,width,true)

func _draw() -> void:
    if not is_instance_valid(world.camera) or world.player.is_empty():return
    var picked = mouse_support()
    if picked.is_empty():
        hover.text = "No walk surface under cursor"
        return
    var grid_origin = Vector2(-0.489921,-0.489921)
    var cell = (picked.point-grid_origin).round()
    var centre = cell+grid_origin
    hover.text = "Cell %d, %d   ·   Z %.2f   ·   View %d/4" % [cell.x,cell.y,picked.height,world.quarter+1]
    if world.grid_visible:
        var radius = mini(24,ceili(world.camera.size))
        for x in range(-radius,radius+1):
            for z in range(-radius,radius+1):
                var p = centre+Vector2(x,z)
                var supports: Array = world.supports_at(p)
                if supports.is_empty():continue
                var support: Dictionary = supports.back()
                cell_outline(p,support.base_height_steps,Color(0.85,0.93,1,0.14),1)
    cell_outline(centre,picked.height,Color(0.4,1,0.85,0.95),2,picked)
