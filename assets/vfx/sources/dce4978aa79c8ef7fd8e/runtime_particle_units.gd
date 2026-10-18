extends "res://assets/vfx/sources/07cc721710dacce01ef6/native_particle_units.gd"
## Neutral occurrence scale requires no property conversion. Keep the last
## applied scale per emitter, so returning from a scaled occurrence restores
## the real source values before its next callback. Live edits remain native.

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
