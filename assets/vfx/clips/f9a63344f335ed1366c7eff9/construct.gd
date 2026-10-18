extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f9a63344f335ed1366c7eff9/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/cf9c83213301ec16b05a/native_initial_blast.tres"
	return instance


func set_blast_event(value: Variant) -> void:
	forward("set_blast_event", value)
