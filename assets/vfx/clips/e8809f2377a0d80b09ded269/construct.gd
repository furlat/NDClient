extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e8809f2377a0d80b09ded269/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/heavy-effects-20261020/sources/6b28556fea54d020a8e7/darkness-phase.tres"
	return instance
