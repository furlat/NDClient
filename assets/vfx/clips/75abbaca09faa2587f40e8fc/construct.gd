extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/75abbaca09faa2587f40e8fc/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/d11dc7e1bbb06f8aaf50/d9c19df5d50eb1dc.tres"
	return instance


func set_recipient_outcomes(value: Variant) -> void:
	forward("set_recipient_outcomes", value)


func set_cast_presence(value: Variant) -> void:
	forward("set_cast_presence", value)
