extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/c4f721f61b3ad23490081f41/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/heavy-effects-20261020/sources/fba2bf14259f9a14824e/2a949241e705dc45.tres"
	return instance
