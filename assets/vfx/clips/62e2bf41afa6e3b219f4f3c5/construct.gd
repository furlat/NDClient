extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/62e2bf41afa6e3b219f4f3c5/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/1683be7bfc616125e05d/ce2c8f2e19448d4c.tres"
	return instance


func set_recipient_outcomes(value: Variant) -> void:
	forward("set_recipient_outcomes", value)


func set_cast_presence(value: Variant) -> void:
	forward("set_cast_presence", value)
