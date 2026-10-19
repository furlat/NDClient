extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_fire_shield_chill_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_fire_shield_chill_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/FactoryGenerated_0000_Node3D/VFX_Shield_demon/ShieldSphere_1", "assembly/effect/Donor/FactoryGenerated_0000_Node3D/VFX_Shield_demon/DistortionSphere_1", "assembly/effect/Donor/FactoryGenerated_0000_Node3D/VFX_Shield_demon/GPUParticles3D"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 0.18, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
