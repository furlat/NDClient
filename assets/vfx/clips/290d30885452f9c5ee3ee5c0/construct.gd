extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/290d30885452f9c5ee3ee5c0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/cbcfcea9720d13647550/fire_native_grant.tres"
	return instance


func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
