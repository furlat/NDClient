extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/49ed2b9326d1aaa6344bcc1a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/70e7038c4f4e149e8ea9/58e42af97dd28889.tres"
	return instance

func set_event_input(value: Variant) -> void:
	forward("set_event_input", value)

func set_lease_input(value: Variant) -> void:
	forward("set_lease_input", value)

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
