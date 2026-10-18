extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f14f3d926e20a0227a1e00d3/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/69a7d13142360d16d6ca/f2eeff7ba9c71085.tres"
	return instance


func set_lease_input(value: Variant) -> void:
	forward("set_lease_input", value)


func set_event_input(value: Variant) -> void:
	forward("set_event_input", value)


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
