extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/1c5396f43ab32a296ae3c865/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/26e605dce010cfd54c5c/031df28bc0b4a01d.tres"
	return instance


func set_owner_projection(value: Variant) -> void:
	forward("set_owner_projection", value)
