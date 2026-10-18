extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e258f8c8e8d4ecc4160eeea6/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6cdf4abd612af1100f76/25c3d524853a24fe.tres"
	return instance


func set_membership_present(value: Variant) -> void:
	forward("set_membership_present", value)
