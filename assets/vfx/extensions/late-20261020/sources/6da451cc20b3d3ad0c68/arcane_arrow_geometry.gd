extends RefCounted
## Geometry in an arrow's local frame: +Y is flight, +Z is upright.
## Materials, ownership and clocks belong to the delivery component.


static func barbed_head(length_units: float, half_width_units: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fin in 2:
		var rotation := Basis(Vector3.UP, float(fin) * PI * 0.5 + PI * 0.125)
		var points: Array[Vector3] = [
			Vector3.ZERO,
			Vector3(-half_width_units, -length_units, 0.0),
			Vector3(0.0, -length_units * 0.59, 0.0),
			Vector3(half_width_units, -length_units, 0.0),
		]
		for face in [-1.0, 1.0]:
			for triangle in [[0, 1, 2], [0, 2, 3]]:
				var order: Array = triangle.duplicate()
				if face < 0.0:
					order.reverse()
				for index in order:
					var point: Vector3 = points[index]
					point.z = face * 0.009 * sin(clampf(-point.y / length_units, 0.0, 1.0) * PI)
					surface.set_uv(Vector2(0.99 - absf(point.x) / half_width_units * 0.17, -point.y / length_units))
					surface.add_vertex(rotation * point)
	surface.generate_normals()
	return surface.commit()


static func tube(points: Array[Vector3], radii: Array[float], sides: int = 8) -> ArrayMesh:
	assert(points.size() >= 2 and points.size() == radii.size())
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in points.size():
		var tangent: Vector3 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
		var reference := Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var side: Vector3 = tangent.cross(reference).normalized()
		var normal: Vector3 = tangent.cross(side).normalized()
		for ring in sides + 1:
			var angle: float = float(ring) / float(sides) * TAU
			var outward: Vector3 = side * cos(angle) + normal * sin(angle)
			vertices.append(points[index] + outward * radii[index])
			normals.append(outward)
			# Stay in the bright donor-gradient region; its independent web mask
			# still scrolls along the full limb rather than painting solid metal.
			coordinates.append(Vector2(0.82 + float(ring) / float(sides) * 0.16, float(index) / float(points.size() - 1) * 2.0))
			if index > 0 and ring < sides:
				var first: int = (index - 1) * (sides + 1) + ring
				indices.append_array(PackedInt32Array([first, first + 1, first + sides + 1, first + 1, first + sides + 2, first + sides + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = coordinates
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
