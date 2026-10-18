extends RefCounted
## Pure phase clocks. Owner age is supplied data, never a gameplay expiry.


static func evaluate(phase: String, seconds: float, specification: Dictionary, context: Dictionary = {}) -> Dictionary:
	assert(is_finite(seconds) and seconds >= 0.0, "Condition sample age must be finite and nonnegative")
	assert(phase in ["application", "sustain", "removal"])
	var duration: float = float(specification.get("phase_seconds", .25))
	assert(is_finite(duration) and duration > 0.0)
	var source_age: float = seconds
	var opacity: float = 1.0
	if phase == "application":
		opacity = smoothstep(0.0, duration, seconds)
	elif phase == "sustain":
		source_age += float(specification.get("application_seconds", .16))
	else:
		var removal_age: float = float(context.get("removal_started_at_owner_age_seconds", specification.get("removal_started_at_owner_age_seconds", 0.0)))
		assert(is_finite(removal_age) and removal_age >= 0.0)
		source_age += removal_age
		opacity = 1.0 - smoothstep(0.0, duration, seconds)
	if context.has("owner_age_seconds"):
		source_age = float(context.owner_age_seconds)
		assert(is_finite(source_age) and source_age >= 0.0)
	var period: float = float(specification.get("loop_seconds", 0.0))
	assert(is_finite(period) and period >= 0.0)
	return {"source_age_seconds": source_age, "loop_age_seconds": fposmod(source_age, period) if period > 0.0 else source_age,
		"opacity": opacity, "phase": phase, "phase_age_seconds": seconds}
