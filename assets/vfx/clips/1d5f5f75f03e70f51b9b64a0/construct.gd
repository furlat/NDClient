extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/1d5f5f75f03e70f51b9b64a0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/8513b562e50478ac3e46/rage.tres"
	return instance

func set_activation_projection(value: Variant) -> void:
	forward("set_activation_projection", value)

func set_owner_projection(value: Variant) -> void:
	forward("set_owner_projection", value)
