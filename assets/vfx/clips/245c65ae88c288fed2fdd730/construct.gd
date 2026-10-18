extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/245c65ae88c288fed2fdd730/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/449b8c0c8b523a5cc57d/native_target2_initial.tres"
	return instance


func set_native_state(value: Variant) -> void:
	forward("set_native_state", value)
