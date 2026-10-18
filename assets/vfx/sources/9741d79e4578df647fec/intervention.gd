extends "res://assets/vfx/sources/d94cb458d7e38082f91f/divine_effect.gd"
## Sunder uses broken solar clefts. Revival has distinct living and downed-dead
## geometry. Creation accents never instantiate counterfeit reward props.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/sources/9741d79e4578df647fec/intervention.gd", input)

func _paths() -> Array:
	var result: Array = []
	var progress: float = smoothstep(.0, .65, local_clock)
	if settings.part == "invocation":
		var hand: Dictionary = endpoint("caster", "cast_hand")
		if hand.is_empty():
			return result
		# One Intervention invocation family opens a wide asymmetric diadem
		# above the actual raised palm. It never encloses the actor's body.
		for vane in 5:
			var offset: float = float(vane) - 2.0
			var points: Array[Vector3] = []
			for index in 33:
				var u: float = float(index) / 32.0
				points.append(hand.point + frame.up * (.08 + .42 * u) * progress
					+ frame.side * offset * .10 * sin(u * PI * .7)
					+ frame.normal * (.04 + .07 * sin(u * PI)))
			result.append(line(points, .075))
		return result
	if settings.part in ["sunder", "destroy", "strike", "improved_smite", "nimbus_contact"]:
		var ray_count: int = 7 if settings.part == "sunder" else (3 if settings.part == "destroy" else 2)
		for ray in ray_count:
			var offset: float = (float(ray) - float(ray_count - 1) * .5) / maxf(1.0, float(ray_count - 1))
			var points: Array[Vector3] = []
			for index in 33:
				var u: float = float(index) / 32.0
				var reach: float = minf(.75, frame.height * .62) * (1.0 if settings.part == "sunder" else .46)
				points.append(frame.centre + frame.side * (offset * minf(.42, frame.half_width * 1.25) + sin(u * PI) * .025)
					+ frame.up * (u - .45) * reach + frame.normal * (.04 + sin(u * PI) * .07 * progress))
			result.append(line(points, .115 if settings.part == "sunder" else (.065 if settings.part == "destroy" else .030)))
		return result
	if settings.part in ["arm", "generosity"]:
		# Only the actual admitted item's supplied socket/location gets an accent.
		var location: Array = event_input.get("creation_position_cells", [])
		if location.size() != 3:
			return result
		var centre := Vector3(location[0], location[1], location[2])
		if settings.part == "arm":
			# A single item admission seam is not a surrogate mace silhouette.
			for parity in [-1.0, 1.0]:
				var points: Array[Vector3] = []
				for index in 25:
					var u: float = float(index) / 24.0
					points.append(centre + frame.side * parity * (.10 + sin(u * PI) * .08)
						+ Vector3.UP * (.03 + .31 * u) + frame.normal * sin(u * PI) * .045)
				result.append(line(points, .038))
			return result
		for corner in 4:
			var angle: float = float(corner) * PI * .5 + PI * .25
			var radial := Vector3(cos(angle), .0, sin(angle))
			result.append(line([centre + radial * .07 + Vector3.UP * .03,
				centre + radial * (.20 + .08 * progress) + Vector3.UP * .03,
				centre + radial * (.20 + .08 * progress) + Vector3.UP * .16], .018, radial.cross(Vector3.UP)))
		return result
	var dead_path: bool = settings.part == "revival_dead"
	for leaf in (3 if dead_path else 6):
		var parity: float = -1.0 if leaf % 2 == 0 else 1.0
		var tier: float = float(leaf / 2)
		var points: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for index in 33:
			var u: float = float(index) / 32.0
			var across: float = parity * frame.half_width * (.10 + .70 * sin(u * PI))
			var elevation: float = frame.bottom + frame.height * (.12 + .70 * u + .045 * tier)
			var support: Dictionary = Frame.support(frame, across, elevation)
			points.append(support.position + support.normal * (.035 + .035 * sin(u * PI) * progress))
			normals.append(support.normal)
		result.append(ribbon(points, normals, .070 if dead_path else .085))
	return result
