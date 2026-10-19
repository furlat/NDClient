extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_fly_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_fly_persistent/prepared.scn", "geometry": ["effect/wind_0/Donor/windsoil", "effect/wind_1/Donor/windsoil"], "emitters": [], "application_seconds": 0.18, "removal_seconds": 0.15, "loop_seconds": 2.0, "sustain_gain": 1.0, "appearance_operation": {"body_animation_override": false, "category": "Bag8", "kind": "fly_modular_wings", "pose_policy": "current_actor_pose_and_facing", "provider_required": true, "slot": "backpack"}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
