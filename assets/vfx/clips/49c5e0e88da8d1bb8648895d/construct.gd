extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/49c5e0e88da8d1bb8648895d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/a9edc36c14ce5c1385ab/407e2970253cb945.tres"
	return instance


func set_owner_projection(value: Variant) -> void:
	forward("set_owner_projection", value)
