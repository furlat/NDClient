extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/ab9f1098a38497b11265f372/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c8565a88a3ee6c18d1e1/00.tres"
	return instance


func set_item_snapshot(value: Variant) -> void:
	forward("set_item_snapshot", value)
