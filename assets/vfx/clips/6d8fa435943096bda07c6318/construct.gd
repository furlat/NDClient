extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6d8fa435943096bda07c6318/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/81d5f1ea0e712942dafe/phase-0.tres"
	return instance


func set_operation_state(value: Variant) -> void:
	forward("set_operation_state", value)
