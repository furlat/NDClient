extends "res://assets/vfx/sources/d94cb458d7e38082f91f/divine_effect.gd"
## The real palm and receiving body define all touch contacts. Lesser/greater
## are the same action family; cure and Cleansing Touch have separate motions.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/sources/9dfd22b4225ff2693c55/touch.gd", input)

func _paths() -> Array:
	var result: Array = []
	var palm: Dictionary = endpoint("caster", "cast_hand")
	var recipient: Dictionary = endpoint("target", "body_center")
	if palm.is_empty() or recipient.is_empty():
		return result
	var wanted: Vector3 = palm.point
	var nearest: Dictionary = frame.points[0]
	for point in frame.points:
		if point.position.distance_squared_to(wanted) < nearest.position.distance_squared_to(wanted):
			nearest = point
	var centre: Vector3 = nearest.position + nearest.normal * .025
	var join: float = smoothstep(.08, .48, local_clock)
	if settings.part == "windup":
		centre = palm.point
	var strength: float = 1.24 if settings.part == "greater" else 1.0
	if settings.part in ["cure", "cleanse"]:
		for parity in [-1.0, 1.0]:
			var points: Array[Vector3] = []
			for index in 25:
				var u: float = float(index) / 24.0
				var rise: float = (u - .5) * .24
				var across: float = parity * (.025 + .085 * join * sin(u * PI))
				if settings.part == "cleanse":
					across *= 1.0 - .65 * u
				points.append(centre + frame.side * across + frame.up * rise + nearest.normal * .025 * sin(u * PI))
			result.append(line(points, .015))
		return result
	for leaf in (4 if settings.part == "greater" else 2):
		var parity: float = -1.0 if leaf % 2 == 0 else 1.0
		var tier: float = float(leaf / 2)
		var points: Array[Vector3] = []
		for index in 33:
			var u: float = float(index) / 32.0
			var across: float = parity * .12 * sin(u * PI) * strength
			var rise: float = (-.10 + u * .20 + tier * .045) * strength
			points.append(centre + frame.side * across + frame.up * rise + nearest.normal * (.025 + .035 * sin(u * PI)))
		result.append(line(points, .020 if leaf < 2 else .013))
	return result
