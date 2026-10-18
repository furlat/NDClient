extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/1dab44e50e363144e382ad3c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6a46e51c80f6b779e023/doused_trail_old_cell_trail.tres"
	return instance


func set_patch_states(value: Variant) -> void:
	forward("set_patch_states", value)


func set_surface_presence(value: Variant) -> void:
	forward("set_surface_presence", value)


func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
