extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e21cac91ec65128961465028/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4ce9d27c4b7d42f9fe14/2fffce04da1c03a6.tres"
	return instance


func set_strike_input(value: Variant) -> void:
	forward("set_strike_input", value)


func set_condition_input(value: Variant) -> void:
	forward("set_condition_input", value)


func set_tick_input(value: Variant) -> void:
	forward("set_tick_input", value)
