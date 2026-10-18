extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f9aaf708375731a3a0b34442/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/2667910d07bef4eef644/e181283ebe663514.tres"
	return instance


func set_blast_event(value: Variant) -> void:
	forward("set_blast_event", value)
