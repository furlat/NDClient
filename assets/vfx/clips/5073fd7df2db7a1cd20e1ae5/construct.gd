extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/5073fd7df2db7a1cd20e1ae5/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c076ddfb2448556ff5f4/f89300769a4d1221.tres"
	return instance


func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
