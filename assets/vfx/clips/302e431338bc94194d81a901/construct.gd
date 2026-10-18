extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/302e431338bc94194d81a901/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/941c0eff310437430474/f9e892eee0c954a4.tres"
	return instance


func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
