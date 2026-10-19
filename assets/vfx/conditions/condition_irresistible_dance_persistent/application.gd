extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_irresistible_dance_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_irresistible_dance_persistent/prepared.scn", "geometry": ["receiving/ReceivingForm0Layer0", "receiving/ReceivingForm1Layer0", "receiving/ReceivingForm2Layer0"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 18.4799567858223, "sustain_gain": 1.0, "adaptive_surface": {"kind": "forms", "settings": {"height_cap_cells": 0.45, "readable": false, "width_cap_cells": 0.28}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
