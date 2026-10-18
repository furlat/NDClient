extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/ee3a1a14146f7489b881dcff/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/a5c3ff9367032320976a/90c2db5e831f0c9a.tres"
	return instance


func set_transition_events(value: Variant) -> void:
	forward("set_transition_events", value)


func set_live_particles(value: Variant) -> void:
	forward("set_live_particles", value)


func set_link_edges(value: Variant) -> void:
	forward("set_link_edges", value)


func set_density_field(value: Variant) -> void:
	forward("set_density_field", value)
