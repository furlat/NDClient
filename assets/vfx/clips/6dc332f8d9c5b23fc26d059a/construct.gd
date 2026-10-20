extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6dc332f8d9c5b23fc26d059a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/547f0721b55da32be215/8a65e5750ac8f31d.tres"
	return instance

func set_event_binding(value: Variant) -> void:
	forward("set_event_binding", value)

func set_event_state(value: Variant) -> void:
	forward("set_event_state", value)
