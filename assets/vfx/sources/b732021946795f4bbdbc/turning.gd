extends "res://assets/vfx/sources/d94cb458d7e38082f91f/divine_effect.gd"
## Holy cast opens toward supplied recipients. The separate steady marker is
## the one true shared Turned condition; no Frightened art or rules are imported.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/sources/b732021946795f4bbdbc/turning.gd", input)

func _paths() -> Array:
	var result: Array = []
	if settings.part == "marker":
		var centre: Vector3 = Vector3(frame.centre.x, frame.top + .16, frame.centre.z) + frame.normal * .035
		# Broken sun above two outward retreat arrows. Stable during hold.
		for half in 2:
			var points: Array[Vector3] = []
			for index in 25:
				var angle: float = float(half) * PI + .24 + float(index) / 24.0 * (PI - .48)
				points.append(centre + frame.side * cos(angle) * .105 + frame.up * sin(angle) * .105)
			result.append(line(points, .014))
		for parity in [-1.0, 1.0]:
			result.append(line([centre + frame.side * parity * .025 - frame.up * .012,
				centre + frame.side * parity * .080 - frame.up * .045,
				centre + frame.side * parity * .025 - frame.up * .080], .013))
		return result
	var palm: Dictionary = endpoint("caster", "cast_hand")
	var recipient: Dictionary = endpoint("target", "body_center")
	if palm.is_empty() or recipient.is_empty():
		return result
	var direction: Vector3 = (recipient.point - palm.point).normalized()
	if direction.is_zero_approx():
		return result
	var side: Vector3 = direction.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = frame.side
	var oath: bool = settings.part == "oath_cast"
	# The finite cast is a low, open holy burst aimed along the real target
	# direction. Width grows away from the palm; no sustained body cage appears.
	for branch in (5 if oath else 7):
		var offset: float = float(branch) - (2.0 if oath else 3.0)
		var points: Array[Vector3] = []
		for index in 25:
			var u: float = float(index) / 24.0
			var advance: float = (.08 + 1.50 * u) * smoothstep(.0, .30, local_clock)
			points.append(palm.point + direction * advance + side * offset * .18 * sin(u * PI * .72)
				+ Vector3.UP * (.025 + (absf(offset) * .055 if oath else .16) * sin(u * PI)))
		result.append(line(points, .115 if oath else .105, direction.cross(side).normalized()))
	return result
