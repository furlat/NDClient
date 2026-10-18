extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/7442ca5fda83681c9788f278/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/64d94cab874fca46ea14/a5586c4208de6af7.tres"
	return instance


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
