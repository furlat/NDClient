extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/eb9b4b6d1444512a7285edaf/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/a1ceb10cfb58d71deb11/897efa4cc7a92fa6.tres"
	return instance

func set_condition_input(value: Variant) -> void:
	forward("set_condition_input", value)

func set_strike_input(value: Variant) -> void:
	forward("set_strike_input", value)

func set_tick_input(value: Variant) -> void:
	forward("set_tick_input", value)
