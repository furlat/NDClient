extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/64bc9fd11a2cfbb1e85ef98c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/ce2ac394af942d5597db/plant_growth_partial_burn_native-phase.tres"
	return instance

func set_removed_cells(value: Variant) -> void:
	forward("set_removed_cells", value)
