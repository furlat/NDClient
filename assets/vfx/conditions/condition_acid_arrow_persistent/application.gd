extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_acid_arrow_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_acid_arrow_persistent/prepared.scn", "geometry": ["effect/LiquidArrow/PointedArrowHead", "effect/LiquidArrow/LiquidShaft", "effect/DropletWake", "effect/AcidDrop0", "effect/AcidDrop1", "effect/AcidDrop2", "effect/AcidDrop3", "effect/AcidDrop4", "effect/AcidDrop5", "effect/AcidDrop6", "effect/AcidDrop7", "effect/AcidDrop8", "effect/AcidDrop9", "effect/AcidDrop10", "effect/AcidDrop11"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "droplets", "settings": {"count": 12.0, "nodes": ["AcidDrop*"], "profile": 0.0}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
