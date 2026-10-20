extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/bd45dcb77cecb041678de43e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/heavy-effects-20261020/sources/0416cf5ba862a2da81e4/d145bd82264f092d.tres"
	return instance
