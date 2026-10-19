extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_dragon_resistance_poison_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_protection_from_poison_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/symbolWHq", "assembly/effect/Donor/transfloorflash5", "assembly/effect/Donor/smallparticles7", "assembly/effect/Donor/smallparticles7LoopHalf"], "emitters": ["assembly/effect/Donor/smallparticles7", "assembly/effect/Donor/smallparticles7LoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
