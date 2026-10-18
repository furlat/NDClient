extends "res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"
const Modules = preload("res://assets/vfx/sources/a848b84a3842277f1296/wind_modules.gd")
var wall: Node3D


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/94d264858d8a892d13f7/wind_modules.gd", input)


func prepare_materials(_node: Node) -> void:
	pass


func apply_scene_edits(node: Node) -> void:
	wall = Modules.new()
	add_child(wall)
	wall.path_points = settings.path_points
	wall.CAMERA_GROUND = Vector2(parameters.clip_ground[0], parameters.clip_ground[1]).normalized()
	wall.build(node)


func advance_lifecycle(_d: float) -> void:
	tick += 1
	var age = float(tick) / float(parameters.simulation_hz)
	wall.set_visual_state(age, Vector2(100, 100), smoothstep(4., 5., age))
