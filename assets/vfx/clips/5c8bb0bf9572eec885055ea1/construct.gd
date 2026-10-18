extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/5c8bb0bf9572eec885055ea1/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/7e6f0c3e2e2aa7a2fe00/ordinary_attack_hit.tres"
	return instance


func set_contact_event(value: Variant) -> void:
	forward("set_contact_event", value)
