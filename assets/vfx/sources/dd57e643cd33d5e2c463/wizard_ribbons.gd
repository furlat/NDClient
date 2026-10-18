extends RefCounted
const Programs = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")


static func template(segments: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for station in segments:
		for corner in [Vector2i(station, 0), Vector2i(station, 1), Vector2i(station + 1, 1), Vector2i(station, 0), Vector2i(station + 1, 1), Vector2i(station + 1, 0)]:
			surface.set_uv(Vector2(float(corner.x) / segments, corner.y))
			surface.set_normal(Vector3.UP)
			surface.set_tangent(Plane(1, 0, 0, 1))
			surface.add_vertex(Vector3(corner.x, corner.y, 0))
	return surface.commit()


static func prepare(draw: MeshInstance3D, kind: int, index: int, segments: int) -> void:
	draw.mesh = template(segments)
	draw.custom_aabb = AABB(Vector3.ONE * -1.0, Vector3.ONE * 2.0)
	Programs.prepare(draw.material_override, "wizard_ribbons")
	draw.material_override.set_shader_parameter("gpu_wizard_kind", kind)
	draw.material_override.set_shader_parameter("gpu_wizard_piece", index)
	draw.material_override.set_shader_parameter("gpu_wizard_segments", segments)
