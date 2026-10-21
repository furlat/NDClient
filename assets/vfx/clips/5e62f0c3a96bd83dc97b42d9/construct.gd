extends "res://assets/vfx/extensions/source-preparation-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/5e62f0c3a96bd83dc97b42d9/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/source-preparation-20261020/sources/32533179fe19fc9f5009/divine_deafened.tres"
	return instance

func set_observation(value: Variant) -> void:
	forward("set_observation", value)
