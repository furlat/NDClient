extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/87b76f05613b70e6b7b70c5f/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/abe281867e8658b636f5/native_sphere_ram.tres"
	return instance


func set_contact_event(value: Variant) -> void:
	forward("set_contact_event", value)
