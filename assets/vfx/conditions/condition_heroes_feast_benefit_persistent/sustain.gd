extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_heroes_feast_benefit_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_heroes_feast_benefit_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/smallparticles2", "assembly/effect/Donor/smoke2init2", "assembly/effect/Donor/smallparticles2LoopHalf", "assembly/effect/Donor/smoke2init2LoopHalf"], "emitters": ["assembly/effect/Donor/smallparticles2", "assembly/effect/Donor/smoke2init2", "assembly/effect/Donor/smallparticles2LoopHalf", "assembly/effect/Donor/smoke2init2LoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 0.035, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
