extends RefCounted
## Three thin intersecting ribbons follow a supplied 3D path; no camera/owner code.
static func build(points: Array[Vector3], widths: Array[float]) -> ArrayMesh:
	assert(points.size() == widths.size() and points.size() >= 2)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var indices := PackedInt32Array()
	for fin in 3:
		var offset: int = vertices.size()
		for index in points.size():
			var tangent: Vector3 = (points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]).normalized()
			if tangent.is_zero_approx(): tangent = Vector3.FORWARD
			var reference: Vector3 = Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.99 else Vector3.UP
			var side: Vector3 = tangent.cross(reference).normalized().rotated(tangent, float(fin) * TAU / 3.0)
			var normal: Vector3 = side.cross(tangent).normalized()
			for edge in [-1.0, 1.0]:
				vertices.append(points[index] + side * float(widths[index]) * edge)
				normals.append(normal)
				coordinates.append(Vector2((edge + 1.0) * 0.5, float(index) / float(points.size() - 1)))
			if index > 0:
				var first: int = offset + (index - 1) * 2
				indices.append_array(PackedInt32Array([first, first + 1, first + 2, first + 1, first + 3, first + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = coordinates
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
