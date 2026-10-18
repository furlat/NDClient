extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f1ac440d7a2e89db6f42fd35/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/ebee42fa4f53a264e7b1/c54267b2276ef00c.tres"
	return instance


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
