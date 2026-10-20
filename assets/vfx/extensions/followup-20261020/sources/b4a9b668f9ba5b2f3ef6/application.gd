extends "res://assets/vfx/extensions/followup-20261020/sources/672c1ceae061a45e68c9/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/followup-20261020/sources/b4a9b668f9ba5b2f3ef6/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_aura_of_life_benefit_persistent/prepared.scn", "geometry": ["support/FactoryGenerated_0000_MeshInstance3D", "support/FactoryGenerated_0001_MeshInstance3D", "support/FactoryGenerated_0002_MeshInstance3D", "support/FactoryGenerated_0003_MeshInstance3D"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 62.8318530717959, "sustain_gain": 1.0, "adaptive_surface": {"kind": "support", "settings": {"readable": false}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
