extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/28f69406e6a6c52380d6df3f/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6b33b6be25092470f96c/06bd3b12bcf2b646.tres"
	return instance


func set_owner_input(value: Variant) -> void:
	forward("set_owner_input", value)


func set_healing_input(value: Variant) -> void:
	forward("set_healing_input", value)


func set_strike_input(value: Variant) -> void:
	forward("set_strike_input", value)


func set_condition_input(value: Variant) -> void:
	forward("set_condition_input", value)


func set_tick_input(value: Variant) -> void:
	forward("set_tick_input", value)
