extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e3144085af0d8ac7cf12db68/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/a0c0fc2a287144550942/fire_native_receiver.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
