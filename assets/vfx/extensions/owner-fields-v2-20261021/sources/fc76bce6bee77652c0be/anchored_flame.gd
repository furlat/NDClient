extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/00db8f16d62269816121/anchored_flame.gd"
## Wall leaves only set age/envelope and latch their emission-stop threshold.
## Eventful healing/jet sources deliberately retain their fixed-step paths.

static func make_component(input: Dictionary) -> Node3D:
	assert(input.settings.id == "wall_of_fire")
	var instance := construct("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/fc76bce6bee77652c0be/anchored_flame.gd", input)
	instance.parameters.lifecycle_sampling = "analytical"
	return instance

func sample_analytical_tick(desired_tick: int) -> bool:
	tick = desired_tick - 1
	advance_lifecycle(1.0 / float(parameters.simulation_hz))
	return true
