extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b40d8a53a5c8cf5d87fe80a0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c13022e9f289a3ef41f8/saved_ram_sphere_ram.tres"
	return instance


func set_contact_event(value: Variant) -> void:
	forward("set_contact_event", value)
