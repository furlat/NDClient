extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/9e64f5c9fc824fed956924a9/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4b7d43e5ddbcbf2ece39/073cb6897d4ed8d7.tres"
	return instance


func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)
