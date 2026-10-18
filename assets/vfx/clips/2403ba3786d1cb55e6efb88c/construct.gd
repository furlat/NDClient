extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/2403ba3786d1cb55e6efb88c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/bc9600d7623f0be32beb/cold_miss_delivery.tres"
	return instance
