extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/67526ab265a80801307f1f2e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/aa4bc5a2fffe1e07d090/a193583418753c06.tres"
	return instance


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
