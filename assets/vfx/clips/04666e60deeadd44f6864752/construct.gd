extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/04666e60deeadd44f6864752/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/b9f2bd56b454836debb9/8961255b7f6d0fcc.tres"
	return instance


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
