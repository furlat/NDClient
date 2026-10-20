extends RefCounted
## The existing recorded player's value semantics, including singular poses.

static func different(first: Variant, last: Variant) -> bool:
	# Recorded discrete mat4 uniforms can change their actual Variant type.
	# Godot rejects Transform3D != Projection; preserve the new source value
	# rather than coercing the matrices or treating a type change as unchanged.
	return typeof(first) != typeof(last) or first != last

static func at(track: Dictionary, low: int, high: int, weight: float) -> Variant:
	var first: Variant = track.values[low]
	if not track.blend or low == high or weight == 0.0:
		return first
	var last: Variant = track.values[high]
	match typeof(first):
		TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR:
			return lerp(first,last,weight)
		TYPE_TRANSFORM3D:
			if is_zero_approx(first.basis.determinant()) or is_zero_approx(last.basis.determinant()):
				return Transform3D(Basis(first.basis.x.lerp(last.basis.x,weight),first.basis.y.lerp(last.basis.y,weight),
					first.basis.z.lerp(last.basis.z,weight)),first.origin.lerp(last.origin,weight))
			return first.interpolate_with(last,weight)
	return first

static func changing(tracks: Array, frame: int, frames: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in tracks.size():
		var track: Dictionary = tracks[index]
		var changed: bool = frame > 0 and different(track.values[frame],track.values[frame-1])
		changed = changed or (track.blend and frame+1 < frames and different(track.values[frame],track.values[frame+1]))
		if changed:
			result.append(index)
	return result
