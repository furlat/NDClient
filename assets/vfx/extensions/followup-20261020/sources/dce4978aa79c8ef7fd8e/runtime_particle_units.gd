extends "res://assets/vfx/sources/07cc721710dacce01ef6/native_particle_units.gd"
## Neutral occurrence scale requires no property conversion. Keep the last
## applied scale per emitter, so returning from a scaled occurrence restores
## the real source values before its next callback. Live edits remain native.
const OriginalUnits = preload("res://assets/vfx/sources/07cc721710dacce01ef6/native_particle_units.gd")
const PrivateProcess = preload("res://assets/vfx/extensions/followup-20261020/sources/03c6c60becba37a1fcaf/private_particle_process.gd")


static func prepare(emitter: GPUParticles3D) -> Dictionary:
	var prepared: Dictionary = PrivateProcess.binding(emitter, OriginalUnits.LENGTH_FIELDS)
	if not prepared.is_empty():
		return prepared
	return OriginalUnits.prepare(emitter)

static func restore(bindings: Array) -> void:
	for binding in bindings:
		if float(binding.get("factory_applied_scale", 1.0)) == 1.0:
			continue
		for field in binding.source:
			binding.emitter.process_material.set(field, binding.source[field])
		binding.factory_applied_scale = 1.0

static func apply(bindings: Array, scale: float) -> void:
	if scale == 1.0:
		return
	for binding in bindings:
		for field in binding.source:
			var value: Variant = binding.emitter.process_material.get(field)
			binding.source[field] = value
			binding.emitter.process_material.set(field, value * scale)
		binding.factory_applied_scale = scale
