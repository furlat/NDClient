extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b4d05e60db9b64d974a22de0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0d3ca8787a4e1bf4187a/4b01bea1b3ffc00e.tres"
	return instance


func set_enchantment_input(value: Variant) -> void:
	forward("set_enchantment_input", value)
