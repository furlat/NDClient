extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/3756090d3c80904bf8e782b6/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4c839b4dd53569f46345/fe2be1aa023d626a.tres"
	return instance


func set_quarry_input(value: Variant) -> void:
	forward("set_quarry_input", value)


func set_hit_input(value: Variant) -> void:
	forward("set_hit_input", value)


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
