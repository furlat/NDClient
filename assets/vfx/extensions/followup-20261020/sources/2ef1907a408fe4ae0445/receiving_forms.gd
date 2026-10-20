extends "res://assets/vfx/sources/db0b913465a389ae3bc7/receiving_forms.gd"
## Actual current actor points/normals, original support kernel, native profiles.
const Programs = preload("res://assets/vfx/extensions/followup-20261020/sources/801b495c0bd760a8e358/directed_program.gd")
var gpu_readable := false
var geometry_key: Array = []
var relative_centre := Vector3.ZERO
var body_texture: ImageTexture
var geometry_uploads := 0


static func make_component(input: Dictionary) -> Node3D:
	return make_gpu("res://assets/vfx/extensions/followup-20261020/sources/2ef1907a408fe4ae0445/receiving_forms.gd", input, false)


static func make_gpu(path: String, input: Dictionary, readable: bool) -> Node3D:
	var instance: Node3D = construct(path, input)
	instance.gpu_readable = readable
	instance._prepare_gpu()
	return instance


func _prepare_gpu() -> void:
	for index in pieces.size():
		var number := index % int(settings.count)
		var layer: Dictionary = settings.layers[floori(float(index) / float(settings.count))]
		var bounds: Array = layer.get("uv_longitude_bounds", [0., 1.])
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var coordinates := PackedVector2Array()
		var colours := PackedColorArray()
		var indices := PackedInt32Array()
		for row in 33:
			for column in 5:
				vertices.append(Vector3(row, float(column) / 2. - 1., number))
				normals.append(Vector3.UP)
				coordinates.append(Vector2(float(column) / 4., lerpf(bounds[0], bounds[1], float(row) / 32.)))
				colours.append(Color(1., 1., 1., float(settings.source_alpha)))
				if row > 0 and column > 0:
					var first := (row - 1) * 5 + column - 1
					indices.append_array(PackedInt32Array([first, first + 1, first + 5, first + 1, first + 6, first + 5]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = coordinates
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_INDEX] = indices
		pieces[index].mesh = ArrayMesh.new()
		pieces[index].mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		pieces[index].custom_aabb = AABB(Vector3.ONE * -3., Vector3.ONE * 6.)
	for material in materials:
		Programs.prepare(material, "receiving_forms")
		material.set_shader_parameter("gpu_form_profile", ["leaves", "pressure_folds", "descending_fronds", "offbeat_lobes", "unthreading"].find(settings.profile))
		material.set_shader_parameter("gpu_form_readable", gpu_readable)
		material.set_shader_parameter("gpu_form_width", float(settings.width_cells))
		material.set_shader_parameter("gpu_form_camber", float(settings.camber_cells))


func _refresh_body() -> bool:
	if surface.get("points", []).size() < 8:
		return false
	var key: Array = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	var origin: Vector3 = surface.get("origin", Vector3.ZERO)
	if key.is_empty() or geometry_key != key or body_texture == null:
		if not _measure():
			return false
		geometry_key = key.duplicate(true)
		relative_centre = centre - origin
		var image := Image.create(points.size(), 2, false, Image.FORMAT_RGBAF)
		for index in points.size():
			var point: Vector3 = points[index].position - centre
			var received_normal: Vector3 = points[index].normal
			image.set_pixel(index, 0, Color(point.x, point.y, point.z, 1.))
			image.set_pixel(index, 1, Color(received_normal.x, received_normal.y, received_normal.z, 1.))
		if body_texture != null and body_texture.get_size() == Vector2(image.get_size()):
			body_texture.update(image)
		else:
			body_texture = ImageTexture.create_from_image(image)
		geometry_uploads += 1
		for material in materials:
			material.set_shader_parameter("gpu_body_points", body_texture)
			material.set_shader_parameter("gpu_body_count", points.size())
			material.set_shader_parameter("gpu_body_up", up)
			material.set_shader_parameter("gpu_body_side", side)
			var height := clampf(height_radius, .055, float(settings.height_cap_cells)) if gpu_readable else minf(height_radius, float(settings.height_cap_cells))
			var width := clampf(width_radius, .07, float(settings.width_cap_cells)) if gpu_readable else minf(width_radius, float(settings.width_cap_cells))
			material.set_shader_parameter("gpu_body_radii", Vector2(height, width))
	else:
		centre = origin + relative_centre
	if endpoints.size() >= 2:
		heading = (endpoints[1].point - endpoints[0].point).normalized()
	return true


func _rebuild() -> void:
	if envelope <= .0001 or not _refresh_body():
		for piece in pieces:
			piece.hide()
		return
	for material in materials:
		material.set_shader_parameter("gpu_form_phase", (local_clock + float(settings.get("source_offset_seconds", 0.))) * float(settings.motion_rate))
		material.set_shader_parameter("gpu_form_heading_bias", clampf(-heading.dot(side), -1., 1.) * .45)
	for piece in pieces:
		piece.global_transform = Transform3D(Basis.IDENTITY, centre)
		piece.show()


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.gpu_geometry_uploads = geometry_uploads
	result.gpu_support_kernel = "Original four-nearest receiving support on live actor data"
	return result
