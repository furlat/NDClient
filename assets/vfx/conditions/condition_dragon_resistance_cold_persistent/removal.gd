extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_dragon_resistance_cold_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_protection_from_energy_cold_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/ShieldSphere_1", "assembly/effect/Donor/small_particles", "assembly/effect/Donor/small_particlesLoopHalf"], "emitters": ["assembly/effect/Donor/small_particles", "assembly/effect/Donor/small_particlesLoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 0.075, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
