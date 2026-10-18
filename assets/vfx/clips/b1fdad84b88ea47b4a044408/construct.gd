extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b1fdad84b88ea47b4a044408/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/bdb1f48b32d084214f6f/02680e7b1b64ce34.tres"
	return instance


func set_hit_input(value: Variant) -> void:
	forward("set_hit_input", value)


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
