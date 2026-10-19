extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_beacon_of_hope_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_beacon_of_hope_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/Flare", "assembly/effect/Donor/Pillar_01", "assembly/effect/Donor/Pillar_02", "assembly/effect/Donor/ShapeParticles", "assembly/effect/Donor/GPUParticles3D2", "assembly/effect/Donor/ShapeParticlesLoopHalf", "assembly/effect/Donor/GPUParticles3D2LoopHalf"], "emitters": ["assembly/effect/Donor/ShapeParticles", "assembly/effect/Donor/GPUParticles3D2", "assembly/effect/Donor/ShapeParticlesLoopHalf", "assembly/effect/Donor/GPUParticles3D2LoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
