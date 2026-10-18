extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/859c09202af1bc9f23853065/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/8640d72020a9a2d28ff4/launch_observed_ice.tres"
	return instance


func set_surface_state(value: Variant) -> void:
	forward("set_surface_state", value)
