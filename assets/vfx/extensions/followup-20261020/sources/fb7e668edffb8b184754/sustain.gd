extends "res://assets/vfx/extensions/followup-20261020/sources/672c1ceae061a45e68c9/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/followup-20261020/sources/fb7e668edffb8b184754/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_holy_aura_persistent/prepared.scn", "geometry": ["support/FactoryGenerated_0000_MeshInstance3D", "support/FactoryGenerated_0001_MeshInstance3D", "support/FactoryGenerated_0002_MeshInstance3D", "support/FactoryGenerated_0003_MeshInstance3D", "support/FactoryGenerated_0004_MeshInstance3D", "support/FactoryGenerated_0005_MeshInstance3D"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 62.8318530717959, "sustain_gain": 1.0, "adaptive_surface": {"kind": "support", "settings": {"readable": false}}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
