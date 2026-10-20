extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/69741adb50e074d2bf139ec7/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/17074aaa9942d3b4025d/concentration_end_old_cell_trail.tres"
	return instance

func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)

func set_patch_states(value: Variant) -> void:
	forward("set_patch_states", value)

func set_surface_presence(value: Variant) -> void:
	forward("set_surface_presence", value)
