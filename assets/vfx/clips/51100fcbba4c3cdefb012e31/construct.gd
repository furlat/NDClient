extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/51100fcbba4c3cdefb012e31/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/e30d655a0e7434d37c02/saved_ram_enemy_turn_end.tres"
	return instance


func set_contact_event(value: Variant) -> void:
	forward("set_contact_event", value)
