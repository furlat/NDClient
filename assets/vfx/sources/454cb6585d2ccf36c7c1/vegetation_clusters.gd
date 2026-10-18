extends RefCounted
## Extract real connected stems from a native plant mesh, preserving original
## positions/normals/UVs/vertex colours. No new asset bank or source mutation.

static func separate(source: Mesh) -> Array[ArrayMesh]:
	var result: Array[ArrayMesh] = []
	for surface_index in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface_index)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in positions.size():
				indices.append(index)
		var canonical := {}
		var vertex_keys := []
		var adjacency := {}
		for index in positions.size():
			var point := positions[index]
			var key := Vector3i(roundi(point.x * 100000), roundi(point.y * 100000), roundi(point.z * 100000))
			if not canonical.has(key):
				canonical[key] = index
			vertex_keys.append(canonical[key])
		for offset in range(0, indices.size(), 3):
			var triangle := [vertex_keys[indices[offset]], vertex_keys[indices[offset + 1]], vertex_keys[indices[offset + 2]]]
			for vertex in triangle:
				if not adjacency.has(vertex):
					adjacency[vertex] = {}
				for other in triangle:
					adjacency[vertex][other] = true
		var owners := {}
		var owner := 0
		for vertex in adjacency:
			if owners.has(vertex):
				continue
			var pending := [vertex]
			while not pending.is_empty():
				var current: int = pending.pop_back()
				if owners.has(current):
					continue
				owners[current] = owner
				for neighbour in adjacency[current]:
					if not owners.has(neighbour):
						pending.append(neighbour)
			owner += 1
		var groups := {}
		for offset in range(0, indices.size(), 3):
			var identity: int = owners[vertex_keys[indices[offset]]]
			if not groups.has(identity):
				groups[identity] = []
			groups[identity].append_array([indices[offset], indices[offset + 1], indices[offset + 2]])
		for group in groups.values():
			if group.size() < 120:
				continue
			var extracted := []
			extracted.resize(Mesh.ARRAY_MAX)
			extracted[Mesh.ARRAY_VERTEX] = PackedVector3Array()
			extracted[Mesh.ARRAY_NORMAL] = PackedVector3Array()
			extracted[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
			extracted[Mesh.ARRAY_COLOR] = PackedColorArray()
			for index in group:
				extracted[Mesh.ARRAY_VERTEX].append(positions[index])
				extracted[Mesh.ARRAY_NORMAL].append(arrays[Mesh.ARRAY_NORMAL][index])
				extracted[Mesh.ARRAY_TEX_UV].append(arrays[Mesh.ARRAY_TEX_UV][index])
				extracted[Mesh.ARRAY_COLOR].append(arrays[Mesh.ARRAY_COLOR][index] if arrays[Mesh.ARRAY_COLOR] != null else Color.WHITE)
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, extracted)
			# Keep actual substantial stems, not disconnected tiny thorn caps.
			if mesh.get_aabb().size.y >= .50:
				result.append(mesh)
	assert(not result.is_empty(), "Selected native vegetation has no substantial connected stems")
	return result
