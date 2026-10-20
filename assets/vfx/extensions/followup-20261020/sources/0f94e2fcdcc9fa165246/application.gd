extends "res://assets/vfx/extensions/followup-20261020/sources/672c1ceae061a45e68c9/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/followup-20261020/sources/0f94e2fcdcc9fa165246/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_weird_persistent/prepared.scn", "geometry": ["receiving/ReceivingForm0Layer0", "receiving/ReceivingForm1Layer0", "receiving/ReceivingForm2Layer0", "receiving/ReceivingForm0Layer1", "receiving/ReceivingForm1Layer1", "receiving/ReceivingForm2Layer1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 38.0799109526036, "sustain_gain": 1.0, "adaptive_surface": {"kind": "forms", "settings": {"height_cap_cells": 0.45, "readable": false, "width_cap_cells": 0.28}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
