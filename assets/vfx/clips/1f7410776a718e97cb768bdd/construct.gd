extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/1f7410776a718e97cb768bdd/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/16f49d1cdc86a7b2fbdc/cbb8a06c62dc95da.tres"
	return instance


func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
