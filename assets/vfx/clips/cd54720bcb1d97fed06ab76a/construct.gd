extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/cd54720bcb1d97fed06ab76a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/52ef7c5efd8d015becf6/saved_ram_body.tres"
	return instance

func set_body_state(value: Variant) -> void:
	forward("set_body_state", value)
