extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_asleep_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_asleep_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/Particles", "assembly/effect/Donor/ParticlesLoopHalf"], "emitters": ["assembly/effect/Donor/Particles", "assembly/effect/Donor/ParticlesLoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
