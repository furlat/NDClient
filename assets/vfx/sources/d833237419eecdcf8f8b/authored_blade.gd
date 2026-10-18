extends RefCounted
## Explicit source-axis normalization, preserving original faces/UVs/normals.
## Source identity/axis are authored data; no inferred weapon or hidden rig.

static func mesh(specification: Dictionary) -> ArrayMesh:
	var original: Mesh
	var source: Resource = VfxPackageIO_d833237419.resource(specification.path)
	if source is Mesh:
		original = source
	else:
		assert(source is PackedScene)
		var scene := (source as PackedScene).instantiate()
		var matches := scene.find_children("*", "MeshInstance3D", true, false)
		assert(matches.size() == 1, "Declare a unique native blade mesh, not an arbitrary demo hierarchy")
		original = matches[0].mesh
		scene.free()
	var bounds := original.get_aabb()
	var rotation := Basis.IDENTITY
	var length: float = bounds.size.y
	var origin := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	if specification.axis == "X":
		rotation = Basis(Vector3.BACK, PI * .5)
		length = bounds.size.x
		origin = Vector3(bounds.position.x, bounds.get_center().y, bounds.get_center().z)
	else:
		assert(specification.axis == "Y")
	var result := ArrayMesh.new()
	for surface_index in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface_index).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			vertices[index] = rotation * (vertices[index] - origin) * (float(specification.length_cells) / length)
			if not normals.is_empty():
				normals[index] = rotation * normals[index]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

const VfxPackageIO_d833237419 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
