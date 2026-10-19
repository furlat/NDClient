extends RefCounted
## Authored item geometry, shared immutably after its first construction.
static var cache: Dictionary = {}

static func append_triangle(arrays: Dictionary, first: Vector3, second: Vector3, third: Vector3, first_uv: Vector2, second_uv: Vector2, third_uv: Vector2, outward: Vector3) -> void:
	var normal: Vector3 = (second - first).cross(third - first).normalized()
	if normal.dot(outward) < 0.0:
		normal = -normal
	# Godot's front faces wind clockwise. Normals remain the explicit outward
	# facet normals, including the independently bevelled head surfaces.
	var corners: Array[Vector3] = [first, second, third]
	var coordinates: Array[Vector2] = [first_uv, second_uv, third_uv]
	if (second - first).cross(third - first).dot(normal) > 0.0:
		corners = [first, third, second]
		coordinates = [first_uv, third_uv, second_uv]
	for index in 3:
		arrays.vertices.append(corners[index])
		arrays.normals.append(normal)
		arrays.uvs.append(coordinates[index])

static func append_quad(arrays: Dictionary, corners: Array[Vector3], coordinates: Array[Vector2], outward: Vector3) -> void:
	append_triangle(arrays, corners[0], corners[1], corners[2], coordinates[0], coordinates[1], coordinates[2], outward)
	append_triangle(arrays, corners[0], corners[2], corners[3], coordinates[0], coordinates[2], coordinates[3], outward)

static func mesh_from_arrays(values: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = values.vertices
	arrays[Mesh.ARRAY_NORMAL] = values.normals
	arrays[Mesh.ARRAY_TEX_UV] = values.uvs
	arrays[Mesh.ARRAY_TEX_UV2] = values.uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func empty_arrays() -> Dictionary:
	return {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array()}

static func blade() -> ArrayMesh:
	if not cache.has("blade"):
		# Each section has a real transverse 0..1 coordinate. The original
		# imported cone is V=1 at its root and V=0 at its tip in Godot; putting
		# item-space XY straight into UV had reversed/truncated that source mask.
		var sections: Array[Vector3] = [Vector3(0.0, .10, .027), Vector3(.001, .22, .033), Vector3(.008, .34, .039), Vector3(.025, .46, .042), Vector3(.052, .58, .037), Vector3(.086, .69, .029), Vector3(.120, .78, .018), Vector3(.145, .84, .001)]
		var arrays := empty_arrays()
		var half_depth := .008
		for index in sections.size() - 1:
			var lower: Vector3 = sections[index]
			var upper: Vector3 = sections[index + 1]
			var lower_v: float = 1.0 - (lower.y - .10) / .74
			var upper_v: float = 1.0 - (upper.y - .10) / .74
			for side in [-1.0, 1.0]:
				var corners: Array[Vector3] = [Vector3(lower.x - lower.z, lower.y, side * half_depth), Vector3(lower.x + lower.z, lower.y, side * half_depth), Vector3(upper.x + upper.z, upper.y, side * half_depth), Vector3(upper.x - upper.z, upper.y, side * half_depth)]
				var coordinates: Array[Vector2] = [Vector2(0.0, lower_v), Vector2(1.0, lower_v), Vector2(1.0, upper_v), Vector2(0.0, upper_v)]
				append_quad(arrays, corners, coordinates, Vector3(0, 0, side))
			for edge in [-1.0, 1.0]:
				var corners: Array[Vector3] = [Vector3(lower.x + edge * lower.z, lower.y, -half_depth), Vector3(lower.x + edge * lower.z, lower.y, half_depth), Vector3(upper.x + edge * upper.z, upper.y, half_depth), Vector3(upper.x + edge * upper.z, upper.y, -half_depth)]
				var edge_u: float = (edge + 1.0) * .5
				var coordinates: Array[Vector2] = [Vector2(edge_u, lower_v), Vector2(edge_u, lower_v), Vector2(edge_u, upper_v), Vector2(edge_u, upper_v)]
				append_quad(arrays, corners, coordinates, Vector3(edge, 0, 0))
		cache.blade = mesh_from_arrays(arrays)
	return cache.blade

static func mace_flange() -> ArrayMesh:
	if not cache.has("mace_flange"):
		# A thin steel vane, with separate broad faces, bevels and edge faces.
		# Six radial copies leave the dark core and the flange gaps visible.
		var outline := PackedVector2Array([Vector2(.030, .445), Vector2(.057, .465), Vector2(.085, .510), Vector2(.085, .610), Vector2(.057, .650), Vector2(.030, .675)])
		var centre := Vector2(.054, .560)
		var inset := PackedVector2Array()
		for point in outline:
			inset.append(point.move_toward(centre, .009))
		var arrays := empty_arrays()
		var outer_half_depth := .003
		var face_half_depth := .009
		var ridge_half_depth := .025
		for side in [-1.0, 1.0]:
			# A raised central fold splits every broad vane into real tilted
			# steel faces. A flat front plate had still read as a ribbed disk.
			for index in inset.size():
				var first: Vector2 = inset[index]
				var second: Vector2 = inset[(index + 1) % inset.size()]
				append_triangle(arrays, Vector3(centre.x, centre.y, side * ridge_half_depth), Vector3(first.x, first.y, side * face_half_depth), Vector3(second.x, second.y, side * face_half_depth), centre, first, second, Vector3(0, 0, side))
			for index in outline.size():
				var next: int = (index + 1) % outline.size()
				var first: Vector2 = outline[index]
				var second: Vector2 = outline[next]
				var inner_first: Vector2 = inset[index]
				var inner_second: Vector2 = inset[next]
				var edge_normal := Vector3(second.y - first.y, first.x - second.x, 0).normalized()
				var corners: Array[Vector3] = [Vector3(first.x, first.y, side * outer_half_depth), Vector3(second.x, second.y, side * outer_half_depth), Vector3(inner_second.x, inner_second.y, side * face_half_depth), Vector3(inner_first.x, inner_first.y, side * face_half_depth)]
				var coordinates: Array[Vector2] = [first, second, inner_second, inner_first]
				append_quad(arrays, corners, coordinates, edge_normal + Vector3(0, 0, side))
		for index in outline.size():
			var first: Vector2 = outline[index]
			var second: Vector2 = outline[(index + 1) % outline.size()]
			var normal := Vector3(second.y - first.y, first.x - second.x, 0).normalized()
			var corners: Array[Vector3] = [Vector3(first.x, first.y, -outer_half_depth), Vector3(second.x, second.y, -outer_half_depth), Vector3(second.x, second.y, outer_half_depth), Vector3(first.x, first.y, outer_half_depth)]
			var coordinates: Array[Vector2] = [first, second, second, first]
			append_quad(arrays, corners, coordinates, normal)
		cache.mace_flange = mesh_from_arrays(arrays)
	return cache.mace_flange

static func cylinder(key: String, radius: float, height: float) -> CylinderMesh:
	if not cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 12
		cache[key] = mesh
	return cache[key]
