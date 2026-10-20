extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/3c3ea66aad40d743dd5b3d83/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/f4ecad680c7acc0aa223/frenzy.tres"
	return instance

func set_activation_projection(value: Variant) -> void:
	forward("set_activation_projection", value)

func set_owner_projection(value: Variant) -> void:
	forward("set_owner_projection", value)
