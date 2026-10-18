extends RefCounted
## Original rear-view source geometry, not selection of rejected artwork.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Programs = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")


static func template(tube: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	surface.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var descriptors: Array[Vector3] = []
	var coordinates: Array[Vector2] = []
	if tube:
		for station in 64:
			for face in 6:
				for corner in [0, 1, 2, 0, 2, 3]:
					descriptors.append(Vector3(station, corner, face))
					coordinates.append(Vector2(float(station) / 65., float(corner % 2)))
	else:
		for station in 32:
			for index in [station * 2, station * 2 + 1, station * 2 + 2, station * 2 + 1, station * 2 + 3, station * 2 + 2]:
				descriptors.append(Vector3(floori(float(index) / 2.), (index % 2) * 2 - 1, 0))
				coordinates.append(Vector2(float(floori(float(index) / 2.)) / 32., float(index % 2)))
	for index in descriptors.size():
		var triangle := floori(float(index) / 3.) * 3
		var second: Vector3 = descriptors[triangle + (index + 1) % 3]
		var third: Vector3 = descriptors[triangle + (index + 2) % 3]
		surface.set_uv(coordinates[index])
		surface.set_normal(Vector3.UP)
		surface.set_tangent(Plane(1, 0, 0, 1))
		surface.set_custom(0, Color(second.x, second.y, second.z, 0))
		surface.set_custom(1, Color(third.x, third.y, third.z, 0))
		surface.add_vertex(descriptors[index])
	return surface.commit()


static func mesh(draw: MeshInstance3D, index: int, seconds: float, tube: bool, animal: bool) -> ArrayMesh:
	if not draw.has_meta("gpu_legacy_geometry"):
		draw.set_meta("gpu_legacy_geometry", true)
		draw.mesh = template(tube)
		draw.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 6, 4))
		Programs.prepare(draw.material_override, "legacy_receiving", false, "gpu_legacy_vertex(VERTEX,NORMAL,TANGENT,BINORMAL,CUSTOM0.xyz,CUSTOM1.xyz);")
		var shader := Shader.new()
		shader.code = Materials.finish_fragment(draw.material_override.shader.code.replace("shader_type spatial;", "shader_type spatial;uniform float gpu_legacy_present=0.;"), "\nALPHA*=gpu_legacy_present;\n")
		Materials.replace_shader(draw.material_override, shader)
		draw.material_override.set_shader_parameter("gpu_legacy_tube", tube)
		draw.material_override.set_shader_parameter("gpu_legacy_animal", animal)
		draw.material_override.set_shader_parameter("gpu_legacy_piece", index)
	draw.material_override.set_shader_parameter("gpu_legacy_seconds", seconds)
	draw.material_override.set_shader_parameter("gpu_legacy_present", 1.0)
	return draw.mesh
