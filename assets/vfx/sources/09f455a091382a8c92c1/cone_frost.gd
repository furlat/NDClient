extends "res://assets/vfx/sources/a100769e182ade6887cc/cone_frost_edges.gd"
## The original cold transforms/materials are closed-form functions of tick.
## Intermediate substeps are never displayed and have no events or solver.

static func make_component(input: Dictionary) -> Node3D:
	var instance := construct("res://assets/vfx/sources/09f455a091382a8c92c1/cone_frost.gd", input)
	instance.parameters.lifecycle_sampling = "analytical"
	return instance

func sample_analytical_tick(desired_tick: int) -> bool:
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return true
