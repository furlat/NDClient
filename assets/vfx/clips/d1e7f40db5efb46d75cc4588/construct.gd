extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d1e7f40db5efb46d75cc4588/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/dda72876d5fc12927307/0f53e69f074f0f51.tres"
	return instance


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
