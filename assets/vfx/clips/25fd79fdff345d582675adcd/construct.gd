extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/25fd79fdff345d582675adcd/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/c9d1c8128c2f32f85ec3/e1954c9de764ba18.tres"
	return instance


func set_blast_event(value: Variant) -> void:
	forward("set_blast_event", value)
