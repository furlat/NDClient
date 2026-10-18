extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e30e5970a1678e45e9718440/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/8b3aca76c4a57900a930/bff736ac9a8728eb.tres"
	return instance


func set_lease_input(value: Variant) -> void:
	forward("set_lease_input", value)


func set_event_input(value: Variant) -> void:
	forward("set_event_input", value)


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
