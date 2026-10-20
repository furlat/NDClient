extends RefCounted
## Shared execution of the original high-level support equations. Admission
## remains in each source class. Geometry is measured only for a changed pose.
const Tables = preload("res://assets/vfx/sources/d3bf76efa97b3499c285/receiving_table.gd")
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
var active_piece_count := 0

func _init(component: Node3D, family: int, prepared: Resource = null) -> void:
	source = component
	kind = family
	var part_name := str(source.settings.part)
	part = {"field": 1, "ground": 1, "windup": 2, "recovery": 3, "break": 4, "word": 5, "cross": 6}.get(part_name, 0)
	if kind == 5:
		part = {"invocation": 1, "sunder": 2, "destroy": 3, "strike": 4,
			"improved_smite": 5, "nimbus_contact": 6, "arm": 7,
			"generosity": 8, "revival_dead": 9, "revival_living": 10}.get(part_name, 0)
	if prepared != null:
		active_piece_count = prepared.active_piece_count
		for index in prepared.meshes.size():
			source.pieces[index].mesh = prepared.meshes[index]
			source.pieces[index].custom_aabb = prepared.bounds[index]
		return
	if kind == 4 and part == 6:
		source._prepare_pieces(1)
		source.pieces[0].mesh = _patch_template()
		source.pieces[0].custom_aabb = AABB(Vector3.ONE * -5., Vector3.ONE * 10.)
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
		5:
			var count: int = 5 if part == 1 else 7 if part == 2 else 3 if part in [3, 9] else 2 if part in [4, 5, 6, 7] else 4 if part == 8 else 6
			for index in count:
				counts.append(25 if part == 7 else 3 if part == 8 else 33)
		6:
			counts = [25, 25, 25, 25, 25, 25]
		7:
			counts = [49, 49, 49, 49, 49]
	if kind == 4 and part == 6:
		counts = []
	active_piece_count = 1 if kind == 4 and part == 6 else counts.size()
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
	if kind == 5 and part in [2, 3, 4, 5, 6]:
		source.material.set_shader_parameter("gpu_support_piece_count", active_piece_count)


func _patch_template() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var colour := Color.html(str(source.settings.vertex_colour)).srgb_to_linear()
	colour.a = float(source.settings.get("vertex_alpha", 1.0))
	for row in 13:
		for column in 13:
			var uv := Vector2(float(column) / 12.0, float(row) / 12.0)
			vertices.append(Vector3(uv.x, uv.y, 0.0))
			normals.append(Vector3.UP)
			coordinates.append(uv)
			colours.append(colour)
			if row > 0 and column > 0:
				var first := (row - 1) * 13 + column - 1
				indices.append_array(PackedInt32Array([first, first + 1, first + 13, first + 1, first + 14, first + 13]))
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
		var table: Dictionary = Tables.obtain(source.surface, kind == 4 and part == 6)
		if table.is_empty():
			body_ready = false
			return false
		geometry_key = key.duplicate(true)
		last_origin = origin
		body_ready = true
		source.frame = Tables.world_frame(table.full, source.surface)
		var receiving_frame: Dictionary = Tables.world_frame(table.receiving, source.surface)
		texture = table.texture
		uploads += 1
		var material: ShaderMaterial = source.material
		material.set_shader_parameter("gpu_support_points", texture)
		material.set_shader_parameter("gpu_support_count", table.count)
		var queries: Texture2D = Tables.fixed_queries(table, kind) if kind == 3 and part != 4 else null
		material.set_shader_parameter("gpu_support_fixed_queries", queries)
		material.set_shader_parameter("gpu_support_precise_queries", queries != null)
		if kind == 1 and part != 1:
			material.set_shader_parameter("gpu_support_holy_roots", Tables.holy_roots(table, source.surface))
		material.set_shader_parameter("gpu_support_centre", receiving_frame.centre - origin)
		material.set_shader_parameter("gpu_support_normal", receiving_frame.normal)
		material.set_shader_parameter("gpu_support_up", receiving_frame.up)
		material.set_shader_parameter("gpu_support_side", receiving_frame.side)
		material.set_shader_parameter("gpu_support_bottom", receiving_frame.bottom - origin.y)
		material.set_shader_parameter("gpu_support_height", receiving_frame.height)
		material.set_shader_parameter("gpu_support_half_width", receiving_frame.half_width)
	elif last_origin != origin:
		var offset: Vector3 = origin - last_origin
		source.frame.centre += offset
		source.frame.top += offset.y
		source.frame.bottom += offset.y
		source.frame.origin = origin
		source.frame.points = source.surface.points
		last_origin = origin
	return true

func rebuild() -> void:
	if source.envelope <= .0001 or not _body() or not _endpoints():
		for piece in source.pieces:
			piece.hide()
		return
	source.material.set_shader_parameter("gpu_support_seconds", source.local_clock)
	for index in source.pieces.size():
		var piece: MeshInstance3D = source.pieces[index]
		piece.visible = index < active_piece_count
		if piece.visible:
			piece.global_transform = Transform3D(Basis.IDENTITY, source.surface.origin)

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
	elif kind == 5 and part == 1:
		first = source.endpoint("caster", "cast_hand")
		if first.is_empty():
			return false
	elif kind == 5 and part in [7, 8]:
		var location: Array = source.event_input.get("creation_position_cells", [])
		if location.size() != 3:
			return false
		first = {"point": Vector3(location[0], location[1], location[2])}
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
