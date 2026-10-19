extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_vampiric_touch_hand_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_vampiric_touch_hand_persistent/prepared.scn", "geometry": ["owned_contact/RecipientToRealHandDrain0", "owned_contact/RecipientToRealHandDrain1", "owned_contact/CasterOwnedHandFold"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
