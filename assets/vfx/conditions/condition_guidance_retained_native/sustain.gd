extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_guidance_retained_native/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_guidance_retained_native/prepared.scn", "geometry": ["effect/Retained/Donor/MeshInstance3D", "effect/Retained/Donor/Particles", "effect/Retained/Donor/Aura", "effect/Retained/Donor/ParticlesLoopHalf", "effect/Retained/Donor/AuraLoopHalf"], "emitters": ["effect/Retained/Donor/Particles", "effect/Retained/Donor/Aura", "effect/Retained/Donor/ParticlesLoopHalf", "effect/Retained/Donor/AuraLoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.32, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
