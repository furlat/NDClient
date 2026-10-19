extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_vicious_mockery_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_vicious_mockery_persistent/prepared.scn", "geometry": ["psychic/PsychicLayer0Piece0", "psychic/PsychicLayer0Piece1", "psychic/PsychicLayer1Piece0", "psychic/PsychicLayer1Piece1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 6.28318530717959, "sustain_gain": 1.0, "adaptive_surface": {"kind": "head", "settings": {"head_fraction_min": 0.8}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
