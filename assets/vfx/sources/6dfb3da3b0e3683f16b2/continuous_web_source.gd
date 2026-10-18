extends RefCounted
## Exact ContinuousWeb vertex equations, evaluated on the original source grid.
## The fragment/UV mask remains the original source, independent of binding.


static func vertex_specification(vertex: Vector3, yaw_degrees: float) -> Dictionary:
	var q := Vector2(vertex.x, vertex.z)
	var radius := q.length()
	var edge := maxf(absf(q.x), absf(q.y))
	q *= lerpf(1.0, radius / maxf(edge, .0001), .82)
	var angle := atan2(q.y, q.x)
	var irregular := .065 * sin(angle * 3.0 + .7) + .04 * sin(angle * 2.0 - 1.3)
	var bend := .10 * sin(radius * .7 + angle * 2.0) * minf(radius / 3.0, 1.0)
	q = q.rotated(bend)
	q *= 1.0 + irregular
	q += Vector2(sin(q.y * 1.05 + .7), sin(q.x * .87 - 1.1)) * .18 * minf(radius / 3.0, 1.0)
	var forward := Vector2(-sin(deg_to_rad(yaw_degrees)), -cos(deg_to_rad(yaw_degrees)))
	var side := Vector2(-forward.y, forward.x)
	var cross := q.dot(side)
	var along := q.dot(forward)
	var order := clampf((along + 5.3) / 10.6, 0.0, 1.0)
	var trailing := 1.0 - order
	var folded := Vector2.ONE + side * (cross * .09 + sin(along * 3.2) * .035 * trailing) - forward * trailing * 1.55
	var from_hit := q - Vector2.ONE
	var sector := atan2(from_hit.y, from_hit.x)
	var stagger := .5 + .30 * sin(sector * 3.0 + .8) + .20 * sin(sector * 5.0 - .6)
	return {"rest":Vector3(q.x, .035 + .016 * (1.0 + sin(q.x * 2.0 + q.y * 1.7)), q.y),
		"folded":Vector3(folded.x, .06 + (.08 + .10 * cos(cross * 2.5)) * trailing, folded.y),
		"delay":.02 + .24 * stagger + from_hit.length() * .008,
		"duration":.62 + .40 * (.5 + .5 * sin(sector * 2.0 - 1.2)),
		"phase_modulation":sin(sector * 3.0 + 1.1),
		"lift":(.32 + .36 * order) * (.8 + .2 * cos(cross)),
		"along":along, "trailing":trailing}


static func deployment(specification: Dictionary, seconds: float) -> float:
	var phase := smoothstep(float(specification.delay), float(specification.delay + specification.duration), seconds)
	return clampf(phase + .075 * sin(phase * TAU) * float(specification.phase_modulation), 0.0, 1.0)


static func position(specification: Dictionary, seconds: float) -> Vector3:
	var phase := deployment(specification, seconds)
	var result: Vector3 = specification.folded.lerp(specification.rest, phase)
	result.y += sin(phase * PI) * float(specification.lift)
	if seconds < 0.0:
		result.y += sin(seconds * 15.0 + float(specification.along) * 2.0) * .025 * float(specification.trailing) * minf(1.0, -seconds * 8.0)
	return result


static func fragment_shader(original: String) -> String:
	# Remove only the vertex function: its exact equations now feed the CPU mesh.
	# Do not substitute a new mask, tint, alpha gain or body-specific material.
	var start := original.find("void vertex()")
	assert(start >= 0)
	var cursor := original.find("{", start) + 1
	var depth := 1
	while cursor < original.length() and depth > 0:
		if original[cursor] == "{":
			depth += 1
		elif original[cursor] == "}":
			depth -= 1
		cursor += 1
	var result := original.substr(0, start) + original.substr(cursor)
	result = result.replace("shader_type spatial;", "shader_type spatial;\nuniform float factory_occurrence_alpha=1.0;")
	return result.insert(result.rfind("}"), "\nALPHA *= factory_occurrence_alpha;\n")
