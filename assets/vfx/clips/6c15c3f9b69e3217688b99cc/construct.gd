extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6c15c3f9b69e3217688b99cc/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/33831720e0d32f435303/02_travel.tres"
	return instance
