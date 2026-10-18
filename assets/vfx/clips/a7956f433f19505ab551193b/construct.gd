extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/a7956f433f19505ab551193b/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/3320e0fed06488cf1e2e/af1e7d0d54f71ef2.tres"
	return instance


func set_owner_projection(value: Variant) -> void:
	forward("set_owner_projection", value)
