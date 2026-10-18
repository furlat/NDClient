extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d3bcf75568e44e3f65421734/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/51f118b8dda98c18b73d/native_enemy_turn_end.tres"
	return instance


func set_contact_event(value: Variant) -> void:
	forward("set_contact_event", value)
