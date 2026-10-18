extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/2172a4298ef1c275103130fa/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4813cd931825d8009ab5/transfer_created_item.tres"
	return instance


func set_created_item_binding(value: Variant) -> void:
	forward("set_created_item_binding", value)
