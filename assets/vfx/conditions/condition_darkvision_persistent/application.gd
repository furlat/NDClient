extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_darkvision_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_darkvision_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/FactoryGenerated_0003_GPUParticles3D", "assembly/effect/Donor/FactoryGenerated_0004_MeshInstance3D", "assembly/effect/Donor/FactoryGenerated_0003_GPUParticles3DLoopHalf"], "emitters": ["assembly/effect/Donor/FactoryGenerated_0003_GPUParticles3D", "assembly/effect/Donor/FactoryGenerated_0003_GPUParticles3DLoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
