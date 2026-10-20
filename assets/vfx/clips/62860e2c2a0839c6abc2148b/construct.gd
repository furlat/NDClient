extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/62860e2c2a0839c6abc2148b/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c14b37673bbf945b8401/a0c0fc2a28714455.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
