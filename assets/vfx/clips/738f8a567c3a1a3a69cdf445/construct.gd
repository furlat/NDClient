extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/738f8a567c3a1a3a69cdf445/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/90147fd36c2b6f1a167c/04f04900a5879e8a.tres"
	return instance


func set_lease_input(value: Variant) -> void:
	forward("set_lease_input", value)


func set_event_input(value: Variant) -> void:
	forward("set_event_input", value)


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
