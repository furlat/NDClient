extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/7e43cced19c92277ef771b03/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/e941820c6755c8bdf2aa/blood_freeze_thaw_candidate-phase.tres"
	return instance

func set_density_field(value: Variant) -> void:
	forward("set_density_field", value)

func set_link_edges(value: Variant) -> void:
	forward("set_link_edges", value)

func set_live_particles(value: Variant) -> void:
	forward("set_live_particles", value)

func set_transition_events(value: Variant) -> void:
	forward("set_transition_events", value)
