extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/12215e72554a1ab7e0528e64/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/50ba36d6a6611b9525d9/concentration_end_body.tres"
	return instance


func set_body_state(value: Variant) -> void:
	forward("set_body_state", value)
