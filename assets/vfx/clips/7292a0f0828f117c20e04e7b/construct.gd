extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/7292a0f0828f117c20e04e7b/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/ea9092504aa67b3caa14/inventory_created_item.tres"
	return instance


func set_created_item_binding(value: Variant) -> void:
	forward("set_created_item_binding", value)
