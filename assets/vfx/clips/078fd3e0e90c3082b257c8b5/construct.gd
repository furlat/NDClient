extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/078fd3e0e90c3082b257c8b5/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/bb65dcbbadbf13f4c684/6875a4dd2ce612f3.tres"
	return instance


func set_membership_present(value: Variant) -> void:
	forward("set_membership_present", value)
