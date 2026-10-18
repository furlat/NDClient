extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/9fd5121e79f3b2927c2ade16/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/afdc9edfb49b77b28b18/0010203bda693cbc.tres"
	return instance


func set_strike_input(value: Variant) -> void:
	forward("set_strike_input", value)


func set_condition_input(value: Variant) -> void:
	forward("set_condition_input", value)


func set_tick_input(value: Variant) -> void:
	forward("set_tick_input", value)
