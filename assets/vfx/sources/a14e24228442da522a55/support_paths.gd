extends RefCounted
## Shared execution of the original high-level support equations. Admission
## remains in each source class. Geometry is measured only for a changed pose.
const Programs = preload("res://assets/vfx/sources/801b495c0bd760a8e358/directed_program.gd")
var source: Node3D
var kind: int
var part: int
var geometry_key: Array = []
var last_origin := Vector3.ZERO
var texture: ImageTexture
var uploads := 0
var body_ready := false
var patch_ready := false

func _init(component: Node3D, family: int) -> void:
	source = component
	kind = family
	var part_name := str(source.settings.part)
	part = {"field": 1, "ground": 1, "windup": 2, "recovery": 3, "break": 4, "word": 5, "cross": 6}.get(part_name, 0)
	if kind == 4 and part == 6:
		return # The measured cross is static per pose, using the exact source mesh.
	var counts := []
	match kind:
		0:
			for index in (6 if part == 1 else (2 if part == 2 else 4)):
				counts.append(49 if part == 1 else (25 if part == 2 else 33))
		1:
			for index in (12 if part == 1 else 6):
				counts.append(17 if part == 1 else 33)
		2:
			counts = [41, 41, 9, 9, 9]
		3:
			for index in (3 if part == 4 else 6):
				counts.append(33 if part == 4 else 25)
		4:
			for index in (3 if part == 5 else 6):
				counts.append(25 if part == 5 else 41)
	source._prepare_pieces(counts.size())
	for index in counts.size():
		source.pieces[index].mesh = _template(index, counts[index])
		source.pieces[index].custom_aabb = AABB(Vector3.ONE * -5., Vector3.ONE * 10.)
	Programs.prepare(source.material, "support_paths")
	source.material.set_shader_parameter("gpu_support_kind", kind)
	source.material.set_shader_parameter("gpu_support_part", part)
	source.material.set_shader_parameter("gpu_support_mode", 1 if source.settings.mode == "apply" else (2 if source.settings.mode == "retire" else 0))
	source.material.set_shader_parameter("gpu_support_width", float(source.settings.width_cells))
	source.material.set_shader_parameter("gpu_support_duration", float(source.settings.seconds))
	if kind == 0 and part == 1:
		source.material.set_shader_parameter("gpu_support_radius", float(source.settings.public_area.radius_cells))

func _template(piece: int, count: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var colour := Color.html(str(source.settings.vertex_colour)).srgb_to_linear()
	colour.a = float(source.settings.get("vertex_alpha", 1.))
	for row in count:
		for column in 5:
			vertices.append(Vector3(float(row) / float(count - 1), float(column) / 2. - 1., piece))
			normals.append(Vector3.UP)
			coordinates.append(Vector2(float(column) / 4., float(row) / float(count - 1)))
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
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _body() -> bool:
	if source.surface.get("points", []).size() < 8:
		body_ready = false
		return false
	var key: Array = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(source.surface)
	var origin: Vector3 = source.surface.origin
	if not body_ready or key.is_empty() or key != geometry_key:
		source.frame = source.Frame.measure(source.surface)
		if source.frame.is_empty():
			body_ready = false
			return false
		geometry_key = key.duplicate(true)
		last_origin = origin
		body_ready = true
		patch_ready = false
		if kind == 4 and part == 6:
			return true
		var image := Image.create(source.frame.points.size(), 2, false, Image.FORMAT_RGBAF)
		for index in source.frame.points.size():
			var position: Vector3 = source.frame.points[index].position - origin
			var normal: Vector3 = source.frame.points[index].normal
			image.set_pixel(index, 0, Color(position.x, position.y, position.z, 1.))
			image.set_pixel(index, 1, Color(normal.x, normal.y, normal.z, 1.))
		if texture != null and texture.get_size() == Vector2(image.get_size()):
			texture.update(image)
		else:
			texture = ImageTexture.create_from_image(image)
		uploads += 1
		var material: ShaderMaterial = source.material
		material.set_shader_parameter("gpu_support_points", texture)
		material.set_shader_parameter("gpu_support_count", source.frame.points.size())
		material.set_shader_parameter("gpu_support_centre", source.frame.centre - origin)
		material.set_shader_parameter("gpu_support_normal", source.frame.normal)
		material.set_shader_parameter("gpu_support_up", source.frame.up)
		material.set_shader_parameter("gpu_support_side", source.frame.side)
		material.set_shader_parameter("gpu_support_bottom", source.frame.bottom - origin.y)
		material.set_shader_parameter("gpu_support_height", source.frame.height)
		material.set_shader_parameter("gpu_support_half_width", source.frame.half_width)
	return true

func rebuild() -> void:
	if source.envelope <= .0001 or not _body() or not _endpoints():
		for piece in source.pieces:
			piece.hide()
		return
	if kind == 4 and part == 6:
		if not patch_ready:
			var paths: Array = source._paths()
			source._prepare_pieces(paths.size())
			for index in paths.size():
				source.pieces[index].mesh = source._mesh(paths[index])
			patch_ready = true
	else:
		source.material.set_shader_parameter("gpu_support_seconds", source.local_clock)
	for piece in source.pieces:
		piece.global_transform = Transform3D(Basis.IDENTITY, source.surface.origin)
		piece.show()

func _endpoints() -> bool:
	var first := {}
	var second := {}
	if (kind == 0 or kind == 2) and part == 2:
		first = source.endpoint(str(source.settings.geometry_actor), "cast_hand")
		if first.is_empty():
			return false
	elif kind == 3 and part == 4:
		if source.event_input.get("removed_condition_uuids", []).is_empty() or str(source.event_input.get("ward_uuid", "")) != str(source.settings.ward_uuid):
			return false
		first = source.endpoint("caster", "hand")
		second = source.endpoint(str(source.settings.geometry_actor), "body_center")
		if first.is_empty() or second.is_empty():
			return false
	elif kind == 4 and part == 5:
		first = source.endpoint(str(source.settings.geometry_actor), "face")
		second = source.endpoint(str(source.settings.voice_recipient_actor), "body_center")
		if first.is_empty() or second.is_empty() or first.point.is_equal_approx(second.point):
			return false
	if not first.is_empty():
		source.material.set_shader_parameter("gpu_support_start", first.point - source.surface.origin)
	if not second.is_empty():
		source.material.set_shader_parameter("gpu_support_end", second.point - source.surface.origin)
	if kind == 4 and part == 5:
		# Keep the actual three syllable bounds separate for transparent sorting.
		# A broad shared GPU bound changes overlap order despite identical paths.
		var direction: Vector3 = (second.point - first.point).normalized()
		var opening := smoothstep(.10, .60, source.local_clock)
		for index in source.pieces.size():
			var radius := .075 + float(index) * .035 + .035 * opening
			var advance := .06 + float(index) * .045 + .045 * opening
			var centre: Vector3 = first.point - source.surface.origin + direction * advance
			centre += source.frame.up * ((cos(PI * .45) + 1.) * .5 - .75) * radius * .62
			source.pieces[index].custom_aabb = AABB(centre - Vector3.ONE * .4, Vector3.ONE * .8)
	return true
