extends "res://assets/vfx/extensions/followup-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/846a3b779902ba2e44d43b13/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/followup-20261020/sources/ef923f07ee47f4639433/02_residue.tres"
	return instance

func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
