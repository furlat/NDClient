extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d430a091f6f7bec11bb6170b/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/cd6455c4f89b816efdb8/acid_target2_receiver.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
