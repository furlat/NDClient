extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/370d5824d9d47beb403bcae8/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6eb1803b00ca449e6ab2/poison_native_grant.tres"
	return instance


func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
