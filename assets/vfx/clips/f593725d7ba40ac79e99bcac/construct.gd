extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f593725d7ba40ac79e99bcac/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/b85a9127707ea647287e/a4fd394cf7d9faa8.tres"
	return instance

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
