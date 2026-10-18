extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/8f53599cf8ba2b3e5a73036d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/53a4b9e6ab726158fbac/00.tres"
	return instance
