extends "res://assets/vfx/extensions/material-runtime-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/material-runtime-20261021/constructors/material_runtime_summon_terminal_air_elemental.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/material-runtime-20261021/sources/577712791e3d1a072ce8/air_elemental.tres").to_clip()
	return instance

func set_terminal_departure(value: Variant) -> void:
	forward("set_terminal_departure", value)
