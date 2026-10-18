extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/7b7e25c78068fe762c380542/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/9d90d289d9f87f0e765b/8569c549fcb67b05.tres"
	return instance


func set_recipient_outcomes(value: Variant) -> void:
	forward("set_recipient_outcomes", value)


func set_cast_presence(value: Variant) -> void:
	forward("set_cast_presence", value)
