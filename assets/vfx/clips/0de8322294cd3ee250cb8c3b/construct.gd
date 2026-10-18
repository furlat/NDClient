extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/0de8322294cd3ee250cb8c3b/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/a88df2fc88183a0fc537/fire_target_receiver.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
