extends "res://assets/vfx/sources/478452765e07c2cb9aca/membership.gd"
## Quiet actual membership entry. The palm is fitted to visible shoulder depth,
## not hidden inside the mean body plane.

static func make_component(input: Dictionary) -> Node3D:
	return create("res://assets/vfx/sources/cbd77fbe2e7613a4bf03/devotion_entry.gd", input)

func _paths() -> Array:
	var result: Array = []
	var centre: Vector3 = frame.centre + frame.up * frame.height * .19
	var offsets: Array[Vector2] = [Vector2(-.065, -.045), Vector2(-.055, .035),
		Vector2(.0, .065), Vector2(.055, .035), Vector2(.065, -.045)]
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for offset in offsets:
		var support: Dictionary = Frame.tangent_support(frame, centre,
			frame.half_width * .48 + offset.x, offset.y)
		points.append(support.position + support.normal * .055)
		normals.append(support.normal)
	result.append(ribbon(points, normals, .016))
	return result
