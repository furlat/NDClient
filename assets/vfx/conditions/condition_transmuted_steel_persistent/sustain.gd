extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_transmuted_steel_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_transmuted_steel_persistent/prepared.scn", "geometry": [], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "actor_operation": {"data": {"texture": "res://assets/vfx/shared/textures/9cd3f8878bb7309b93e326f32ec56826051c01d37c379da21f6cddcf4ecfc33a.res"}, "kind": 4.0, "loop_seconds": 2.0}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
