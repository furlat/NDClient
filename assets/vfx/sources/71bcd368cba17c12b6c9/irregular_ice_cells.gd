extends RefCounted
## Deterministic closed Voronoi fragments of the actual textured donor mesh.
## Exterior UVs/normals survive; only newly cut faces receive the ice interior.


static func build(source: ArrayMesh, size: Vector3, exterior: Material,
		interior: Material, seed_value: int, count: int) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var seeds: Array[Vector3] = []
	for index in count:
		# Jittered alternating height tiers avoid regular octant planes.
		var angle := float(index) * 2.399963 + random.randf_range(-0.2, 0.2)
		var radius := random.randf_range(0.15, 0.35)
		seeds.append(Vector3(cos(angle) * size.x * radius,
			size.y * (float(index % 3) - 1.0) * 0.24 + random.randf_range(-0.035, 0.035),
			sin(angle) * size.z * radius))
	var original := _polygons(source)
	var pieces := []
	for index in seeds.size():
		var polygons: Array = original.duplicate(true)
		for other in seeds.size():
			if other == index:
				continue
			var normal := (seeds[other] - seeds[index]).normalized()
			var distance := normal.dot((seeds[other] + seeds[index]) * 0.5)
			polygons = _cut(polygons, normal, distance)
			if polygons.is_empty():
				break
		if polygons.is_empty():
			continue
		var points: Array[Vector3] = []
		for polygon in polygons:
			for vertex in polygon:
				points.append(vertex.position)
		var bounds := AABB(points[0], Vector3.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		var pivot := bounds.get_center()
		var mesh := ArrayMesh.new()
		for cap in [false, true]:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var vertices := 0
			for polygon in polygons:
				if bool(polygon[0].cap) != cap:
					continue
				for triangle in range(1, polygon.size() - 1):
					for vertex in [polygon[0], polygon[triangle], polygon[triangle + 1]]:
						surface.set_uv(vertex.uv)
						surface.set_normal(vertex.normal)
						surface.add_vertex(vertex.position - pivot)
						vertices += 1
			if vertices > 0:
				surface.set_material(interior if cap else exterior)
				surface.commit(mesh)
		pieces.append({"mesh": mesh, "pivot": pivot})
	return pieces


static func _polygons(source: ArrayMesh) -> Array:
	var result := []
	for index in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices = PackedInt32Array(range(vertices.size()))
		for triangle in range(0, indices.size(), 3):
			var polygon := []
			for corner in 3:
				var at: int = indices[triangle + corner]
				polygon.append({"position": vertices[at], "normal": normals[at],
					"uv": uv[at] if at < uv.size() else Vector2(vertices[at].x, vertices[at].z), "cap": false})
			result.append(polygon)
	return result


static func _cut(polygons: Array, normal: Vector3, distance: float) -> Array:
	var result := []
	var cuts: Array[Vector3] = []
	for polygon in polygons:
		var clipped := []
		for index in polygon.size():
			var first: Dictionary = polygon[index]
			var second: Dictionary = polygon[(index + 1) % polygon.size()]
			var first_distance: float = normal.dot(first.position) - distance
			var second_distance: float = normal.dot(second.position) - distance
			if first_distance <= 0.000001:
				clipped.append(first)
			if (first_distance <= 0.0) != (second_distance <= 0.0):
				var fraction: float = first_distance / (first_distance - second_distance)
				var position: Vector3 = first.position.lerp(second.position, fraction)
				clipped.append({"position": position, "uv": first.uv.lerp(second.uv, fraction),
					"normal": first.normal.lerp(second.normal, fraction).normalized(), "cap": first.cap})
				if not cuts.any(func(point: Vector3) -> bool: return point.distance_squared_to(position) < 0.00000001):
					cuts.append(position)
		if clipped.size() >= 3:
			result.append(clipped)
	if cuts.size() >= 3:
		var centre := Vector3.ZERO
		for point in cuts:
			centre += point
		centre /= float(cuts.size())
		var across := normal.cross(Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT).normalized()
		var up := normal.cross(across).normalized()
		# Godot front triangles are clockwise when viewed from outside.
		cuts.sort_custom(func(first: Vector3, second: Vector3) -> bool:
			return atan2((first-centre).dot(up),(first-centre).dot(across)) > atan2((second-centre).dot(up),(second-centre).dot(across)))
		var cap := []
		for point in cuts:
			cap.append({"position": point, "normal": normal,
				"uv": Vector2(point.dot(across), point.dot(up)), "cap": true})
		result.append(cap)
	return result
