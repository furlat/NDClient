extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d12370fae0e9132e7cdd6818/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/20190f2888f82000adff/36c781856de511dc.tres"
	return instance


func set_payload_state(value: Variant) -> void:
	forward("set_payload_state", value)


func set_payload_anchor(value: Variant) -> void:
	forward("set_payload_anchor", value)
