extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/8431d36a389de9e0b61d4b06/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/3f2c1d99a5e03dcafef2/d145bd82264f092d.tres"
	return instance
