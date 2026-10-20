extends RefCounted
## One synchronous sample only. Never retain actor geometry across input calls.
## Identical source inverse + same supplied packet imply the same exact Y max;
## preserve point order and the original Transform3D*Vector3 arithmetic.
var values: Array[Dictionary] = []

func clear() -> void:
	values.clear()

func top(surface: Dictionary, inverse: Transform3D) -> float:
	for record: Dictionary in values:
		if is_same(record.surface,surface) and record.inverse == inverse:
			return record.top
	var result := -INF
	for point in surface.points:
		result = maxf(result,(inverse * point.position).y)
	values.append({"surface":surface,"inverse":inverse,"top":result})
	return result
