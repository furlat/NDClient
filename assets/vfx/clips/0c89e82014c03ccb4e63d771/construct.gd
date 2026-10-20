extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/0c89e82014c03ccb4e63d771/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/b15bc5c6e21f6c28d7e0/windup.tres"
	return instance

func set_condition_input(value: Variant) -> void:
	forward("set_condition_input", value)

func set_healing_input(value: Variant) -> void:
	forward("set_healing_input", value)

func set_hit_input(value: Variant) -> void:
	forward("set_hit_input", value)

func set_owner_input(value: Variant) -> void:
	forward("set_owner_input", value)

func set_quarry_input(value: Variant) -> void:
	forward("set_quarry_input", value)

func set_strike_input(value: Variant) -> void:
	forward("set_strike_input", value)

func set_tick_input(value: Variant) -> void:
	forward("set_tick_input", value)
