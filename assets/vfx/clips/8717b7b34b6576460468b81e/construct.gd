extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/8717b7b34b6576460468b81e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/e10da6745a4554c97416/sleep_target_condition.tres"
	return instance


func set_condition_state(value: Variant) -> void:
	forward("set_condition_state", value)
