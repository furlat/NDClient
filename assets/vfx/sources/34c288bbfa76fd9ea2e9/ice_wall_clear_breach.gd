extends "res://assets/vfx/sources/2a0fda0e7f174924eafc/ice_wall_frost_air.gd"
## The actual section first falls physically, then its ephemeral breakup clears.
## Frigid air/frost retain their independent parent concentration lifetime.
const DebrisOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
var debris_opacity_prepared := false


static func make_component(input: Dictionary) -> Node3D:
	assert(input.has("debris_clear_interval_seconds"))
	return construct("res://assets/vfx/sources/34c288bbfa76fd9ea2e9/ice_wall_clear_breach.gd", input)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	if not assembly_breakup.transferred:
		return
	if not debris_opacity_prepared:
		for pair in assembly_breakup.material_pairs:
			DebrisOpacity.adapt_resource(pair.material, {})
		debris_opacity_prepared = true
	var age := float(tick)/float(parameters.simulation_hz) - transfer_source_age_seconds
	var interval: Array = parameters.debris_clear_interval_seconds
	var fade := 1.0 - smoothstep(float(interval[0]), float(interval[1]), age)
	for pair in assembly_breakup.material_pairs:
		pair.material.set_shader_parameter("factory_occurrence_alpha", fade)
	if fade <= 0.0:
		assembly_breakup.retire()


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.debris_clear_interval_after_break_seconds = parameters.debris_clear_interval_seconds
	result.cold_air_retired_with_debris = false
	return result
