extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/04101c0e9b00c2cfd1b39213/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/05c280600ce2e6a94163/f4e38d027b07db1c.tres"
	return instance


func set_strike_input(value: Variant) -> void:
	forward("set_strike_input", value)


func set_condition_input(value: Variant) -> void:
	forward("set_condition_input", value)


func set_tick_input(value: Variant) -> void:
	forward("set_tick_input", value)
