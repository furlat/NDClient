extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b111d12929bc41d6e4903372/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/8cbfee69170bd46b6d07/d20f7df3e046d112.tres"
	return instance

func set_event_input(value: Variant) -> void:
	forward("set_event_input", value)

func set_lease_input(value: Variant) -> void:
	forward("set_lease_input", value)

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
