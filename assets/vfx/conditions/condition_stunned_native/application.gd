extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_stunned_native/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_stunned_native/prepared.scn", "geometry": ["assembly/effect/Donor/FactoryGenerated_0000_Node3D/FactoryGenerated_0000_MeshInstance3D", "assembly/effect/Donor/FactoryGenerated_0000_Node3D/FactoryGenerated_0001_MeshInstance3D", "assembly/effect/Donor/FactoryGenerated_0000_Node3D/FactoryGenerated_0002_MeshInstance3D"], "emitters": [], "application_seconds": 0.16, "removal_seconds": 0.25, "loop_seconds": 1.375, "sustain_gain": 1.0, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
