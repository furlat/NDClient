extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/eba71b9278c0bc783474e1ff/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/5b4d4ce0b128df5d9074/acid_surface.tres"
	return instance


func set_surface_presence(value: Variant) -> void:
	forward("set_surface_presence", value)


func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
