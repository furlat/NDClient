extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/73ea6c91894ae4d09e260fd2/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/8b5d0fff46f09ceb7b57/9ba53516da527832.tres"
	return instance

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
