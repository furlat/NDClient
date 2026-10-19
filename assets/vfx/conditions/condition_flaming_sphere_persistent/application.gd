extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_flaming_sphere_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_flaming_sphere_persistent/prepared.scn", "geometry": ["effect/NativeMovingFlame0", "effect/NativeMovingFlame1", "effect/NativeMovingFlame2", "effect/NativeMovingFlame3", "effect/NativeMovingFlame4", "effect/NativeMovingFlame5", "effect/NativeMovingFlame6", "effect/NativeMovingFlame7", "effect/NativeFireFlowBody", "effect/NativeVolumeFlames/firex2", "effect/NativeVolumeFlames/smallparticles_constant", "effect/NativeVolumeFlames/firex2LoopHalf", "effect/NativeVolumeFlames/smallparticles_constantLoopHalf"], "emitters": ["effect/NativeVolumeFlames/firex2", "effect/NativeVolumeFlames/smallparticles_constant", "effect/NativeVolumeFlames/firex2LoopHalf", "effect/NativeVolumeFlames/smallparticles_constantLoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
