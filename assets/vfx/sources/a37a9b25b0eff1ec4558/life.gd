extends "res://assets/vfx/sources/d94cb458d7e38082f91f/divine_effect.gd"
## Preserve Life opens low branching fans; committed recipient healing closes
## two local leaves. Neither composition replays a complete healing spell.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/sources/a37a9b25b0eff1ec4558/life.gd", input)

func _paths() -> Array:
	var result: Array = []
	if settings.part == "source":
		# This is a local source flourish. The actual thirty-foot admitted ally
		# set belongs to gameplay and is not painted as six giant floor blades.
		var radius: float = float(settings.source_accent_reach_cells)
		for branch in 6:
			var angle: float = float(branch) * TAU / 6.0
			var radial := Vector3(cos(angle), .0, sin(angle))
			var side: Vector3 = radial.cross(Vector3.UP)
			var points: Array[Vector3] = []
			for index in 33:
				var u: float = float(index) / 32.0
				var reach: float = radius * (.08 + .45 * u) * smoothstep(.0, .55, local_clock)
				points.append(surface.origin + radial * reach + side * sin(u * PI) * .13 + Vector3.UP * (.030 + .10 * sin(u * PI)))
			result.append(line(points, .115, Vector3.UP))
		return result
	var self_heal: bool = settings.part == "blessed_return"
	var centre: Vector3 = frame.centre + frame.normal * .035
	for parity in [-1.0, 1.0]:
		var points: Array[Vector3] = []
		for index in 33:
			var u: float = float(index) / 32.0
			var width: float = minf(.19, frame.half_width * .76) * (0.65 if self_heal else 1.0)
			points.append(centre + frame.side * parity * sin(u * PI) * width
				+ frame.up * (u - .5) * minf(.36, frame.height * .34)
				+ frame.normal * sin(u * PI) * .025)
		result.append(line(points, .025 if self_heal else .055))
	return result
