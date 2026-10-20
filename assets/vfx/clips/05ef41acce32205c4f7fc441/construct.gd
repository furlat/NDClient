extends "res://assets/vfx/extensions/followup-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/05ef41acce32205c4f7fc441/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/followup-20261020/sources/ea460335c22701629360/04_patch.tres"
	return instance

func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
