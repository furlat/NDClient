extends "res://assets/vfx/extensions/source-preparation-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f3c6bfdb67547b04b45a8aad/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/source-preparation-20261020/sources/0f866ec3dd623b7b4aff/divine_blinded.tres"
	return instance

func set_observation(value: Variant) -> void:
	forward("set_observation", value)
