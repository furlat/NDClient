extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/5d2df0d1b30fde63e478fe6a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c298a4777871a6be8c18/863642b738b1f992.tres"
	return instance


func set_removed_cells(value: Variant) -> void:
	forward("set_removed_cells", value)
