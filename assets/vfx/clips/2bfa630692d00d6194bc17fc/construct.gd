extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/2bfa630692d00d6194bc17fc/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/fa0712b7996a20c0937b/73cb5165a9390390.tres"
	return instance


func set_owner_projection(value: Variant) -> void:
	forward("set_owner_projection", value)


func set_activation_projection(value: Variant) -> void:
	forward("set_activation_projection", value)
