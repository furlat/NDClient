extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/c255d345e4825576aaeb63fe/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0e6711c84dd6f10e7b51/acid_native_exhale.tres"
	return instance


func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
