extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/5ab8faeb512677fcd5bf7771/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/e86e5aa47a232d531b37/82dc7776a94151a5.tres"
	return instance


func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
