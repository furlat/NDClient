extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/31528d945d45e5cb14ce28e2/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/d253c24f56f19c26c8da/33bc5ca0cdc4db52.tres"
	return instance

func set_event_input(value: Variant) -> void:
	forward("set_event_input", value)

func set_lease_input(value: Variant) -> void:
	forward("set_lease_input", value)

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
