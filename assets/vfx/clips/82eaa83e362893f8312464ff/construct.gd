extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/82eaa83e362893f8312464ff/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/561e050eca9d7bcdfdda/poison_surface.tres"
	return instance


func set_surface_presence(value: Variant) -> void:
	forward("set_surface_presence", value)


func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
