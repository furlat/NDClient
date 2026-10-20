extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/1f60a35651512397aa219de2/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/25b501cf80d0554e8cfc/cf9c83213301ec16.tres"
	return instance

func set_blast_event(value: Variant) -> void:
	forward("set_blast_event", value)
