extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/8559c021779fe93103bc3b3d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/e4d14d67971aab1186fd/ee76958b6b6b79e2.tres"
	return instance


func set_removed_cells(value: Variant) -> void:
	forward("set_removed_cells", value)
