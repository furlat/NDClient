extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/52665668589a6a2bd67b40b4/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/heavy-effects-20261020/sources/4fec0660cc26f49b59f7/c9d1c8128c2f32f8.tres"
	return instance

func set_blast_event(value: Variant) -> void:
	forward("set_blast_event", value)
