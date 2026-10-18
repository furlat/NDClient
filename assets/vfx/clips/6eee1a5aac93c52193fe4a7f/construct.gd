extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6eee1a5aac93c52193fe4a7f/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/3146943dc14c7055e464/b509c112d512f87b.tres"
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
