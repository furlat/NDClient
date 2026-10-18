extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/c77fd9f1b669f5e7ce85709c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/38ca4133c2166b53c4d5/cold_native_exhale.tres"
	return instance


func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
