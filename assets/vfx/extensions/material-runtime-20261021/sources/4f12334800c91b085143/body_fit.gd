extends "res://assets/vfx/extensions/continuation42-20261020/sources/5bfb0a8d6113c8a6470c/body_fit.gd"
## Exact monotone vertical projection only. Every unadmitted matrix/input uses
## the original ordered scan; all packet state is released at call completion.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var maximum_points: Array[Dictionary] = []


func clear() -> void:
	values.clear()
	maximum_points.clear()


func _vertical_point(surface: Dictionary) -> Dictionary:
	for record: Dictionary in maximum_points:
		if is_same(record.surface, surface):
			return record
	var result := {"surface":surface, "valid":not surface.points.is_empty(), "point":Vector3.ZERO}
	var maximum := -INF
	for point: Dictionary in surface.points:
		var position: Vector3 = point.position
		if not position.is_finite():
			result.valid = false
			break
		if position.y > maximum:
			maximum = position.y
			result.point = position
	maximum_points.append(result)
	return result


func _top(surface: Dictionary, inverse: Transform3D) -> float:
	for record: Dictionary in values:
		if is_same(record.surface, surface) and record.inverse == inverse:
			return record.top
	# Exact zero coefficients only. Under a positive Y scale every original
	# transformed Y is monotone in world Y, including native float rounding.
	# Keep the ORIGINAL full Transform3D*actualPoint operation; a positive
	# finite result avoids signed-zero equivalence at the reduction boundary.
	var basis: Basis = inverse.basis
	if inverse.origin.is_finite() and basis.x.is_finite() and basis.y.is_finite() and basis.z.is_finite() \
			and basis.x.y == 0.0 and basis.z.y == 0.0 and basis.y.y > 0.0:
		var selected: Dictionary = _vertical_point(surface)
		if selected.valid:
			var result: float = (inverse * selected.point).y
			if is_finite(result) and result > 0.0:
				values.append({"surface":surface, "inverse":inverse, "top":result})
				return result
	return super.top(surface, inverse)


func top(surface: Dictionary, inverse: Transform3D) -> float:
	Profile.begin("curse_body_ordered_reduction")
	var result: float = _top(surface, inverse)
	Profile.end("curse_body_ordered_reduction")
	return result
