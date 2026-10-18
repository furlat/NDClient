extends RefCounted
## Local mesh/material construction for two distinct operation studies.
## No cameras, renderer hosts, game rules, spell lookup or light creation.

const SurfaceShader = preload("res://assets/vfx/sources/56049dd2dfc2cac01b4c/study_surface.gdshader")
const SourceNoise = preload("res://assets/vfx/sources/900721c102c94ad02849/texture.res")


static func ribbon(points: PackedVector3Array, width_cells: float, normal: Vector3 = Vector3.UP) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size() - 1):
		for corner in [Vector2i(index, 0), Vector2i(index, 1), Vector2i(index + 1, 1), Vector2i(index, 0), Vector2i(index + 1, 1), Vector2i(index + 1, 0)]:
			var along: float = float(corner.x) / float(points.size() - 1)
			var tangent: Vector3 = (points[mini(corner.x + 1, points.size() - 1)] - points[maxi(0, corner.x - 1)]).normalized()
			var across: Vector3 = tangent.cross(normal).normalized()
			if across.length() < 0.1:
				across = Vector3.RIGHT
			surface.set_normal(normal)
			surface.set_uv(Vector2(along, float(corner.y)))
			surface.add_vertex(points[corner.x] + across * width_cells * (float(corner.y) - 0.5))
	return surface.commit()


static func ink(color: Color, textured: float = 0.25) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SurfaceShader
	material.set_shader_parameter("ink_color", color)
	material.set_shader_parameter("source_noise", SourceNoise)
	material.set_shader_parameter("texture_strength", textured)
	return material


static func matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	# Authored item depiction colour, independent of unavailable donor scene light.
	# This shades no actor/floor and does not create an optical source.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func piece(parent: Node3D, label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result


static func observation(settings: Dictionary, live: Dictionary, seconds: float) -> Dictionary:
	var state: Dictionary = settings.get("state", {}).duplicate(true)
	for row in settings.get("review_states", []):
		if seconds >= float(row.seconds):
			state.merge(row.state, true)
	if not live.is_empty():
		state = live.duplicate(true)
	return state


static func visibility(state: Dictionary) -> float:
	if not bool(state.get("present", false)) or bool(state.get("suppressed", false)):
		return 0.0
	return clampf(float(state.get("visibility", 1.0)), 0.0, 1.0)


static func fade(seconds: float, duration_seconds: float, state: Dictionary) -> float:
	var envelope: float = smoothstep(0.0, 0.16, seconds) * (1.0 - smoothstep(duration_seconds - 0.4, duration_seconds, seconds))
	if state.has("retire_at_seconds"):
		envelope *= 1.0 - smoothstep(float(state.retire_at_seconds), float(state.retire_at_seconds) + 0.28, seconds)
	return envelope * visibility(state)
