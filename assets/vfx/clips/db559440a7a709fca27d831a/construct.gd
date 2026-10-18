extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/db559440a7a709fca27d831a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/f7e1ab07d3a7acaea412/launch_delivery.tres"
	return instance


func set_accepted_release(value: Variant) -> void:
	forward("set_accepted_release", value)
