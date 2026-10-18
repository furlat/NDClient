extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/c040ef1288829852e095f59a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/aa29ea2be7ec763f85bf/fire_removed_exhale.tres"
	return instance


func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
