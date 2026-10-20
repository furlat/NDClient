extends "res://assets/vfx/extensions/followup-20261020/sources/d94cb458d7e38082f91f/divine_effect.gd"
## Three quiet membership-event motifs. No continuous rings, stacked cages or
## aura membership/strongest-provider calculation is performed by this artwork.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/extensions/followup-20261020/sources/478452765e07c2cb9aca/membership.gd", input)

func _paths() -> Array:
	var result: Array = []
	var centre: Vector3 = frame.centre + frame.normal * .04
	match str(settings.part):
		"protection":
			centre.y = frame.bottom + frame.height * .13
			for tier in 2:
				var rise: float = float(tier) * .035
				result.append(line([centre - frame.side * .075 + frame.up * rise,
					centre - frame.up * (.04 - rise), centre + frame.side * .075 + frame.up * rise], .012))
		"devotion":
			centre.y = frame.bottom + frame.height * .69
			result.append(line([centre - frame.side * .065 - frame.up * .045,
				centre - frame.side * .055 + frame.up * .035, centre + frame.up * .065,
				centre + frame.side * .055 + frame.up * .035, centre + frame.side * .065 - frame.up * .045], .013))
		"courage":
			centre.y = frame.bottom + frame.height * .47
			result.append(line([centre - frame.side * .065 - frame.up * .04,
				centre + frame.up * .055, centre + frame.side * .065 - frame.up * .04], .014))
	return result
