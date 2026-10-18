extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/01f6e2cb1b4e3a77d6061aa5/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/20f931d08ce51d8b61db/915ecb238937240b.tres"
	return instance


func set_wet_presence(value: Variant) -> void:
	forward("set_wet_presence", value)
