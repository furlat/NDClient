extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/91e45db45de041c4af932293/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/db52a11d1ad70378da96/net.tres"
	return instance


func set_binding_owners(value: Variant) -> void:
	forward("set_binding_owners", value)
