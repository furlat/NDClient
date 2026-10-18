extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b67a0b4e03fe4481da943c2c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/b5f78b3e67c6d9c6b93c/9698606495a8a3d1.tres"
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
