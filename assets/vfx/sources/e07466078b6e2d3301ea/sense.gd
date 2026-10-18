extends "res://assets/vfx/sources/d94cb458d7e38082f91f/divine_effect.gd"
## Small split brow compass owned by the supplied two-turn self condition.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/sources/e07466078b6e2d3301ea/sense.gd", input)

func _paths() -> Array:
	var result: Array = []
	var face: Dictionary = endpoint("caster", "face")
	if face.is_empty():
		return result
	var centre: Vector3 = face.point + frame.up * .055 + frame.normal * .035
	for parity in [-1.0, 1.0]:
		var points: Array[Vector3] = []
		for index in 25:
			var u: float = float(index) / 24.0
			points.append(centre + frame.side * (u - .5) * .18 + frame.up * parity * sin(u * PI) * .042)
		result.append(line(points, .011))
	result.append(line([centre - frame.up * .028, centre + frame.up * .028, centre + frame.up * .085], .009))
	return result
