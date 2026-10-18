extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/5f8863f5bb28c05b8b276aa0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0eb1d51908db097c5772/86f1e0ee93f3df70.tres"
	return instance


func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)


func set_retirement_time(value: Variant) -> void:
	forward("set_retirement_time", value)
