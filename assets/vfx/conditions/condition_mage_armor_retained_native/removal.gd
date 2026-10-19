extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_mage_armor_retained_native/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_mage_armor_retained_native/prepared.scn", "geometry": ["effect/Retained/Donor/ShieldSphere_1", "effect/Retained/Donor/small_particles2", "effect/Retained/Donor/small_particles2LoopHalf"], "emitters": ["effect/Retained/Donor/small_particles2", "effect/Retained/Donor/small_particles2LoopHalf"], "application_seconds": 0.45, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
