extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_paladin_aura_devotion_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_paladin_aura_devotion_persistent/prepared.scn", "geometry": ["divine_art/FactoryGenerated_0000_MeshInstance3D", "divine_art/FactoryGenerated_0001_MeshInstance3D", "divine_art/FactoryGenerated_0002_MeshInstance3D", "divine_art/FactoryGenerated_0003_MeshInstance3D", "divine_art/FactoryGenerated_0004_MeshInstance3D", "divine_art/FactoryGenerated_0005_MeshInstance3D", "divine_art/FactoryGenerated_0006_MeshInstance3D", "divine_art/FactoryGenerated_0007_MeshInstance3D"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "support", "settings": {}}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
