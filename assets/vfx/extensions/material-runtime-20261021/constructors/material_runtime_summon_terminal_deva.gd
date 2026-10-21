extends "res://assets/vfx/extensions/material-runtime-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/material-runtime-20261021/constructors/material_runtime_summon_terminal_deva.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/material-runtime-20261021/sources/ee2f010c497771da80c7/deva.tres").to_clip()
	return instance

func set_terminal_departure(value: Variant) -> void:
	forward("set_terminal_departure", value)
