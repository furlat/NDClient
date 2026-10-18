extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/0f7a7cc4c97724c9933efa67/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c9da0e40cc5e127d512d/sleep_target2_condition.tres"
	return instance


func set_condition_state(value: Variant) -> void:
	forward("set_condition_state", value)
