extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/3ee3072f812e67dee528f28d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/1a5ccaa55971032289c3/plant_growth_native-phase.tres"
	return instance

func set_removed_cells(value: Variant) -> void:
	forward("set_removed_cells", value)
