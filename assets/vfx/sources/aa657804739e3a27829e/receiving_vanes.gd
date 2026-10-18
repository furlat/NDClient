extends "res://assets/vfx/sources/5441f2ac6be4f01f1671/receiving_vanes.gd"
## Actual current actor points/normals, original support kernel, native profiles.
const Programs = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
var geometry_key: Array = []
var relative_centre := Vector3.ZERO
var body_texture: ImageTexture
var geometry_uploads := 0


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/sources/aa657804739e3a27829e/receiving_vanes.gd", input)
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
				var lateral := float(column) / 4.
				if layer.has("uv_latitude_bounds"):
					lateral = lerpf(layer.uv_latitude_bounds[0], layer.uv_latitude_bounds[1], lateral)
				coordinates.append(Vector2(lateral, lerpf(bounds[0], bounds[1], float(row) / 32.)))
				var colour := Color.html(settings.colour).srgb_to_linear()
				colour.a = float(settings.get("source_alpha", .7))
				colours.append(colour)
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
		Programs.prepare(material, "receiving_vanes", false, "float source_alpha;gpu_vane_vertex(VERTEX,NORMAL,TANGENT,BINORMAL,source_alpha);COLOR.a=source_alpha;")
		material.set_shader_parameter("gpu_form_profile", ["ascending", "unfurl"].find(settings.style))
		material.set_shader_parameter("gpu_form_width", float(settings.width_cells))
		material.set_shader_parameter("gpu_form_camber", .028)
		material.set_shader_parameter("gpu_vane_rate", float(settings.motion_rate))
		material.set_shader_parameter("gpu_vane_sheet", bool(settings.get("sheet_animation", false)))
		material.set_shader_parameter("gpu_vane_period", float(settings.get("sheet_period_seconds", 1.8)))
		material.set_shader_parameter("gpu_vane_alpha", float(settings.get("source_alpha", .7)))
		material.set_shader_parameter("gpu_vane_removal", settings.mode == "remove")
		material.set_shader_parameter("gpu_vane_duration", float(settings.seconds))


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
		var image := Image.create(measured.size(), 2, false, Image.FORMAT_RGBAF)
		for index in measured.size():
			var point: Vector3 = measured[index].position - origin
			var received_normal: Vector3 = measured[index].normal
			image.set_pixel(index, 0, Color(point.x, point.y, point.z, 1.))
			image.set_pixel(index, 1, Color(received_normal.x, received_normal.y, received_normal.z, 1.))
		if body_texture != null and body_texture.get_size() == Vector2(image.get_size()):
			body_texture.update(image)
		else:
			body_texture = ImageTexture.create_from_image(image)
		geometry_uploads += 1
		for material in materials:
			material.set_shader_parameter("gpu_body_points", body_texture)
			material.set_shader_parameter("gpu_body_count", measured.size())
			material.set_shader_parameter("gpu_body_up", Vector3.UP)
			material.set_shader_parameter("gpu_body_side", side)
			material.set_shader_parameter("gpu_vane_centre", centre - origin)
			material.set_shader_parameter("gpu_body_radii", Vector2(height_cells, half_width_cells))
	else:
		centre = origin + relative_centre
	return true


func _rebuild() -> void:
	if envelope <= .0001 or not _refresh_body():
		for piece in pieces:
			piece.hide()
		return
	for material in materials:
		material.set_shader_parameter("gpu_form_phase", local_clock)
	for piece in pieces:
		piece.global_transform = Transform3D(Basis.IDENTITY, surface.origin)
		piece.show()


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.gpu_geometry_uploads = geometry_uploads
	result.gpu_support_kernel = "Original four-nearest receiving support on live actor data"
	return result
