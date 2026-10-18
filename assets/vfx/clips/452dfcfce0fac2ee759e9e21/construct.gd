extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/452dfcfce0fac2ee759e9e21/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/de8eed10448045fc86cf/4b4fdc51ef357bc0.tres"
	return instance


func set_strike_input(value: Variant) -> void:
	forward("set_strike_input", value)


func set_condition_input(value: Variant) -> void:
	forward("set_condition_input", value)


func set_tick_input(value: Variant) -> void:
	forward("set_tick_input", value)
