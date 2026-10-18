extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/efb46c1fba126071c7b4e97d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c97c018275e4f40b0f5f/lightning_native_receiver.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
