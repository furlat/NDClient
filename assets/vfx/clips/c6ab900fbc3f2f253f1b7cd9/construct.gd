extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/c6ab900fbc3f2f253f1b7cd9/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/a2bdfb6e55d0ebd40d73/2667910d07bef4ee.tres"
	return instance

func set_blast_event(value: Variant) -> void:
	forward("set_blast_event", value)
