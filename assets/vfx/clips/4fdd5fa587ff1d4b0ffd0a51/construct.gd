extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/4fdd5fa587ff1d4b0ffd0a51/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/57475093cc81088b5a62/192ec7b91fc5af9f.tres"
	return instance


func set_lease_input(value: Variant) -> void:
	forward("set_lease_input", value)


func set_event_input(value: Variant) -> void:
	forward("set_event_input", value)


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
