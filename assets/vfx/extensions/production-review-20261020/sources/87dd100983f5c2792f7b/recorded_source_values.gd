extends RefCounted
## Explicit source-loop and nearest track semantics; all old tracks unchanged.


static func source_seconds(bundle: Resource, seconds: float) -> float:
	var declared: Variant = bundle.get("source_loop")
	if not declared is Dictionary or declared.is_empty(): return seconds
	var begin := float(declared.begin_seconds)
	var period := float(declared.period_seconds)
	var result := maxf(0., seconds)
	if result > begin + period:
		result = begin + fposmod(result - begin, period)
	return result


static func prepare(handle: Dictionary) -> String:
	var loop: Variant = handle.bundle.get("source_loop")
	if loop is Dictionary and not loop.is_empty():
		if not loop.has("begin_seconds") or not loop.has("period_seconds") \
				or not is_finite(float(loop.begin_seconds)) or not is_finite(float(loop.period_seconds)) \
				or float(loop.begin_seconds) < 0. or float(loop.period_seconds) <= 0. \
				or float(loop.begin_seconds) + float(loop.period_seconds) != float(handle.bundle.seconds) \
				or not handle.bundle.systems.is_empty() or not handle.bundle.trails.is_empty() or handle.bundle.moving:
			return "Explicit source cycle requires its complete fixed mesh-only recorded domain"
	var selected := []
	for entry: Dictionary in handle.tracks:
		var mode := str(entry.track.get("interpolation", ""))
		if mode.is_empty(): continue
		if mode != "nearest" or entry.track.kind != "material" or not entry.target is ShaderMaterial \
				or entry.track.values.size() != handle.bundle.frames or entry.track.blend:
			return "Unsupported explicit recorded track interpolation"
		selected.append(entry)
	handle.declared_nearest_tracks = selected
	return ""


static func sample(handle: Dictionary, seconds: float) -> void:
	var selected: Array = handle.get("declared_nearest_tracks", [])
	if selected.is_empty(): return
	var frame := clampi(int(roundf(seconds * handle.bundle.rate)), 0, handle.bundle.frames - 1)
	for entry: Dictionary in selected:
		entry.target.set_shader_parameter(entry.track.property, entry.track.values[frame])
