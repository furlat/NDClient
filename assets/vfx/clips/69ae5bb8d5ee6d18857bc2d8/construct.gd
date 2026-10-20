extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/69ae5bb8d5ee6d18857bc2d8/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c1730f204ee91e7952a0/4bc2c6d8150a997a.tres"
	return instance

func set_event_input(value: Variant) -> void:
	forward("set_event_input", value)

func set_lease_input(value: Variant) -> void:
	forward("set_lease_input", value)

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
