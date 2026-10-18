extends RefCounted
## Partition existing static radial shell triangles; never add render faces.
## Opposing inner/outer triangles share one footprint and connected region.
var chunks: Array[Dictionary] = []
var triangle_regions := PackedInt32Array()
var footprint_regions := PackedInt32Array()
var footprints: Array[Dictionary] = []
var triangles: Array[Dictionary] = []
var seed_footprints := PackedInt32Array()
var source_arrays: Array = []
var source_seed: int = 0
var direction_quantization: float = 0.0
var centre_source_units := Vector3.ZERO


func build(source: MeshInstance3D, specification: Dictionary) -> void:
	assert(chunks.is_empty() and source.mesh is ArrayMesh)
	assert(source.mesh.get_surface_count() == 1 and source.mesh.get_blend_shape_count() == 0,
		"Source surface partition currently requires one static triangle surface")
	assert(source.mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES)
	for key in ["source_seed", "chunk_count", "direction_quantization", "centre_source_units"]:
		assert(specification.has(key), "Surface partition requires explicit " + key)
	source_seed = int(specification.source_seed)
	direction_quantization = float(specification.direction_quantization)
	assert(direction_quantization > 0.0)
	var centre: Array = specification.centre_source_units
	assert(centre.size() == 3)
	centre_source_units = Vector3(centre[0], centre[1], centre[2])
	source_arrays = source.mesh.surface_get_arrays(0)
	assert(source_arrays[Mesh.ARRAY_BONES] == null and source_arrays[Mesh.ARRAY_WEIGHTS] == null,
		"Skinned source surfaces require a different explicit partition contract")
	for slot in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		assert(source_arrays[slot] == null, "Custom packed vertex formats need an explicit attribute decoder")
	_build_footprints()
	_choose_seeds(int(specification.chunk_count))
	_grow_connected_regions()
	_make_chunk_meshes(source)


func _direction_key(position: Vector3) -> Vector3i:
	var direction: Vector3 = (position - centre_source_units).normalized()
	return Vector3i(roundi(direction.x * direction_quantization),
		roundi(direction.y * direction_quantization), roundi(direction.z * direction_quantization))


func _build_footprints() -> void:
	var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if source_arrays[Mesh.ARRAY_INDEX] != null:
		indices = source_arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index in vertices.size():
			indices.append(index)
	assert(indices.size() % 3 == 0)
	var groups: Dictionary = {}
	var direction_ids: Dictionary = {}
	var edge_groups: Dictionary = {}
	for triangle_index in range(int(indices.size() / 3)):
		var corners := PackedInt32Array([indices[triangle_index * 3], indices[triangle_index * 3 + 1], indices[triangle_index * 3 + 2]])
		var position: Vector3 = (vertices[corners[0]] + vertices[corners[1]] + vertices[corners[2]]) / 3.0
		var key: Vector3i = _direction_key(position)
		if not groups.has(key):
			groups[key] = footprints.size()
			footprints.append({"direction":(position - centre_source_units).normalized(),
				"triangles":PackedInt32Array(), "adjacent":{}, "area":0.0})
		var group: int = int(groups[key])
		footprints[group].triangles.append(triangle_index)
		footprints[group].area += (vertices[corners[1]] - vertices[corners[0]]).cross(vertices[corners[2]] - vertices[corners[0]]).length() * .5
		triangles.append({"corners":corners, "footprint":group})
		var ports := PackedInt32Array()
		for corner in corners:
			var vertex_key: Vector3i = _direction_key(vertices[corner])
			if not direction_ids.has(vertex_key):
				direction_ids[vertex_key] = direction_ids.size()
			ports.append(int(direction_ids[vertex_key]))
		for edge in 3:
			var first: int = ports[edge]
			var second: int = ports[(edge + 1) % 3]
			if first == second:
				continue
			var edge_key := Vector2i(mini(first, second), maxi(first, second))
			if not edge_groups.has(edge_key):
				edge_groups[edge_key] = {}
			edge_groups[edge_key][group] = true
	for owners in edge_groups.values():
		for first in owners:
			for second in owners:
				if first != second:
					footprints[first].adjacent[second] = true


func _choose_seeds(count: int) -> void:
	assert(count > 1 and count < footprints.size())
	var random := RandomNumberGenerator.new()
	random.seed = source_seed
	var candidates := PackedInt32Array()
	var jitter := PackedFloat32Array()
	for index in footprints.size():
		if float(footprints[index].area) > .000001:
			candidates.append(index)
		jitter.append(random.randf_range(.90, 1.10))
	assert(count <= candidates.size())
	seed_footprints.append(candidates[random.randi_range(0, candidates.size() - 1)])
	while seed_footprints.size() < count:
		var chosen: int = -1
		var greatest: float = -1.0
		for candidate in candidates:
			if seed_footprints.has(candidate):
				continue
			var nearest: float = INF
			for seed in seed_footprints:
				nearest = minf(nearest, footprints[candidate].direction.distance_squared_to(footprints[seed].direction))
			var score: float = nearest * jitter[candidate]
			if score > greatest:
				greatest = score
				chosen = candidate
		assert(chosen >= 0)
		seed_footprints.append(chosen)


func _grow_connected_regions() -> void:
	var costs := PackedFloat32Array()
	var settled := PackedByteArray()
	costs.resize(footprints.size())
	costs.fill(INF)
	settled.resize(footprints.size())
	settled.fill(0)
	footprint_regions.resize(footprints.size())
	footprint_regions.fill(-1)
	for region in seed_footprints.size():
		var seed: int = seed_footprints[region]
		costs[seed] = 0.0
		footprint_regions[seed] = region
	for iteration in footprints.size():
		var current: int = -1
		var nearest: float = INF
		for index in footprints.size():
			if settled[index] == 0 and costs[index] < nearest:
				current = index
				nearest = costs[index]
		assert(current >= 0, "Source radial surface footprints must form one connected shell")
		settled[current] = 1
		for adjacent in footprints[current].adjacent:
			if settled[adjacent] != 0:
				continue
			var distance: float = footprints[current].direction.distance_to(footprints[adjacent].direction)
			var proposed: float = costs[current] + maxf(distance, .000001)
			if proposed < costs[adjacent]:
				costs[adjacent] = proposed
				footprint_regions[adjacent] = footprint_regions[current]
	triangle_regions.resize(triangles.size())
	for triangle_index in triangles.size():
		triangle_regions[triangle_index] = footprint_regions[triangles[triangle_index].footprint]


func _make_chunk_meshes(source: MeshInstance3D) -> void:
	for region in seed_footprints.size():
		var selected := PackedInt32Array()
		var original_triangles := PackedInt32Array()
		for triangle_index in triangles.size():
			if triangle_regions[triangle_index] == region:
				selected.append_array(triangles[triangle_index].corners)
				original_triangles.append(triangle_index)
		assert(not selected.is_empty())
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		for slot in Mesh.ARRAY_MAX:
			if slot == Mesh.ARRAY_INDEX or source_arrays[slot] == null:
				continue
			var channel: Variant = source_arrays[slot]
			var copied: Variant = channel.duplicate()
			copied.resize(0)
			var stride: int = 4 if slot == Mesh.ARRAY_TANGENT else 1
			for index in selected:
				for offset in stride:
					copied.append(channel[index * stride + offset])
			arrays[slot] = copied
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh = _preserve_native_streams(source.mesh, mesh, selected)
		mesh.surface_set_material(0, source.mesh.surface_get_material(0))
		chunks.append({"mesh":mesh, "source_vertex_indices":selected,
			"source_triangle_indices":original_triangles, "seed_footprint":seed_footprints[region]})


func _preserve_native_streams(original: ArrayMesh, rebuilt: ArrayMesh, selected: PackedInt32Array) -> ArrayMesh:
	# ArrayMesh re-encodes octahedral normals/tangents when rebuilding from
	# decoded arrays. Copy actual native stream bytes instead of accumulating
	# another quantization step. Engine APIs own the layout/stride offsets.
	var original_surfaces: Array = original.get("_surfaces")
	var rebuilt_surfaces: Array = rebuilt.get("_surfaces")
	var source: Dictionary = original_surfaces[0]
	var target: Dictionary = rebuilt_surfaces[0].duplicate(true)
	var format: int = int(source.format)
	assert(format == int(target.format) and (format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) == 0,
		"Raw source partition currently supports the inspected uncompressed static vertex format")
	var count: int = int(source.vertex_count)
	var vertex_stride: int = RenderingServer.mesh_surface_get_format_vertex_stride(format, count)
	var normal_stride: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format, count)
	var attribute_stride: int = RenderingServer.mesh_surface_get_format_attribute_stride(format, count)
	var normal_offset: int = RenderingServer.mesh_surface_get_format_offset(format, count, Mesh.ARRAY_NORMAL)
	var source_vertices: PackedByteArray = source.vertex_data
	var vertex_data := PackedByteArray()
	for index in selected:
		var offset: int = index * vertex_stride
		vertex_data.append_array(source_vertices.slice(offset, offset + vertex_stride))
	for index in selected:
		var offset: int = normal_offset + index * normal_stride
		vertex_data.append_array(source_vertices.slice(offset, offset + normal_stride))
	assert(vertex_data.size() == selected.size() * (vertex_stride + normal_stride))
	target.vertex_data = vertex_data
	var source_attributes: PackedByteArray = source.attribute_data
	var attribute_data := PackedByteArray()
	for index in selected:
		var offset: int = index * attribute_stride
		attribute_data.append_array(source_attributes.slice(offset, offset + attribute_stride))
	target.attribute_data = attribute_data
	if source.has("uv_scale"):
		target.uv_scale = source.uv_scale
	var exact := ArrayMesh.new()
	exact.set("_surfaces", [target])
	return exact


func observation() -> Dictionary:
	var counts: Array[int] = []
	for chunk in chunks:
		counts.append(chunk.source_triangle_indices.size())
	return {"source_seed":source_seed, "source_triangles":triangles.size(),
		"radial_footprints":footprints.size(), "chunks":chunks.size(),
		"triangles_per_chunk":counts, "added_render_faces":0,
		"source_vertices_uv_normals_retained":true, "regions_follow_source_adjacency":true,
		"native_vertex_streams_copied_without_reencoding":true,
		"paired_inner_outer_surface_footprints":true,
		"visible_cut_edge_caps_added":false}
