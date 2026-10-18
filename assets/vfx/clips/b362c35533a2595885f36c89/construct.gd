extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b362c35533a2595885f36c89/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/94590e66751e15e40e52/fire_target2_receiver.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
