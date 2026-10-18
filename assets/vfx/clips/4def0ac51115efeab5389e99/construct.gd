extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/4def0ac51115efeab5389e99/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4a2d66eaf849613bd750/7e1429882caee543.tres"
	return instance


func set_accepted_release(value: Variant) -> void:
	forward("set_accepted_release", value)
