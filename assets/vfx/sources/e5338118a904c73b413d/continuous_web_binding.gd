extends Node3D
## One source net with prescribed anchored draping, not simulated cloth.
## Only supplied exact Web memberships may pull its existing floor vertices.
const Source = preload("res://assets/vfx/sources/6dfb3da3b0e3683f16b2/continuous_web_source.gd")
const MaterialBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

var specification: Dictionary = {}
var owners: Array = []
var surfaces: Dictionary = {}
var profiles: Dictionary = {}
var anchors: Dictionary = {}
var anchored_vertices: Dictionary = {}
var source_vertices := PackedVector3Array()
var source_normals := PackedVector3Array()
var source_uv := PackedVector2Array()
var source_indices := PackedInt32Array()
var source_specs: Array = []
var rest_vertices := PackedVector3Array()
var vertices := PackedVector3Array()
var mesh := ArrayMesh.new()
var net: MeshInstance3D
var material: ShaderMaterial
var source_seconds := .0
var deployment_end_seconds := .0
var observations: Dictionary = {}


static func make_component(input: Dictionary) -> Node3D:
	for key in ["source_shader", "source_texture", "source_size", "source_subdivisions", "yaw_degrees",
			"zone_uuid", "binding_owners", "rise_seconds", "release_seconds", "anchor_margin_world_units",
			"return_run_height_ratio", "surface_clearance_world_units", "contact_witness_max_gap_world_units", "surface_columns", "surface_rows"]:
		assert(input.has(key), "Continuous Web requires explicit " + key)
	assert(is_equal_approx(float(input.source_size), 10.6))
	assert(float(input.rise_seconds) > 0.0 and float(input.release_seconds) > 0.0)
	var instance := preload("res://assets/vfx/sources/e5338118a904c73b413d/continuous_web_binding.gd").new()
	instance.specification = input.duplicate(true)
	instance._prepare_source()
	instance.set_binding_owners(input.binding_owners)
	return instance


func _prepare_source() -> void:
	var source := PlaneMesh.new()
	source.size = Vector2.ONE * float(specification.source_size)
	source.subdivide_width = int(specification.source_subdivisions)
	source.subdivide_depth = int(specification.source_subdivisions)
	var arrays: Array = source.get_mesh_arrays()
	source_vertices = arrays[Mesh.ARRAY_VERTEX].duplicate()
	source_normals = arrays[Mesh.ARRAY_NORMAL].duplicate()
	source_uv = arrays[Mesh.ARRAY_TEX_UV].duplicate()
	source_indices = arrays[Mesh.ARRAY_INDEX].duplicate()
	rest_vertices.resize(source_vertices.size())
	for index in source_vertices.size():
		var entry := Source.vertex_specification(source_vertices[index], float(specification.yaw_degrees))
		source_specs.append(entry)
		rest_vertices[index] = entry.rest
		deployment_end_seconds = maxf(deployment_end_seconds, float(entry.delay + entry.duration))
	material = ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = Source.fragment_shader(VfxPackageIO_e5338118a9.text(specification.source_shader))
	if specification.has("raised_strand_alpha"):
		var code: String = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float web_raised_alpha=1.0;\nuniform float web_wrap_strength=0.0;\nvarying float web_raised_height;\n")
		# Original resting source vertices never exceed .067 local units. Only
		# lifted silk receives this opt-in visibility gain; floor UV/mask stay exact.
		code += "\nvoid vertex(){web_raised_height=length(MODEL_MATRIX[1].xyz)*max(0.0,VERTEX.y-.067);}\n"
		code = MaterialBindings.finish_fragment(code, "\nALPHA*=mix(1.0,web_raised_alpha,web_wrap_strength*smoothstep(.04,.16,web_raised_height));\n")
		var shader := Shader.new()
		shader.code = code
		MaterialBindings.replace_shader(material, shader)
		material.set_shader_parameter("web_raised_alpha", float(specification.raised_strand_alpha))
	var texture := MaterialBindings.imported_image(specification.source_texture)
	assert(texture != null and not texture.is_empty())
	texture.generate_mipmaps()
	material.set_shader_parameter("silk_texture", ImageTexture.create_from_image(texture))
	material.set_shader_parameter("factory_occurrence_alpha", 1.0)
	material.set_meta("factory_occurrence_alpha", true)
	net = MeshInstance3D.new()
	net.name = "ContinuousSourceNet"
	net.mesh = mesh
	net.material_override = material
	add_child(net)


func set_binding_owners(value: Array) -> void:
	# This is an explicit presentation projection, not a new backend packet type.
	# An absent owner never acquires membership merely by standing on this floor.
	owners = []
	var seen: Dictionary = {}
	for supplied in value:
		var owner: Dictionary = supplied
		for key in ["owner_uuid", "actor_id", "zone_uuid", "condition_identity", "admitted", "begin_seconds", "removed_seconds"]:
			assert(owner.has(key), "Binding owner input requires " + key)
		if not bool(owner.admitted) or str(owner.owner_uuid).is_empty() or str(owner.actor_id).is_empty():
			continue
		if str(owner.zone_uuid) != str(specification.zone_uuid) or str(owner.condition_identity) != "condition.spell.web.restrained":
			continue
		assert(not seen.has(str(owner.owner_uuid)), "One exact membership UUID cannot bind two actors")
		assert(float(owner.removed_seconds) < 0.0 or float(owner.removed_seconds) >= float(owner.begin_seconds))
		seen[str(owner.owner_uuid)] = true
		owners.append(owner.duplicate(true))
	owners.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first.owner_uuid) < str(second.owner_uuid))
	if is_inside_tree():
		sample(source_seconds)


func set_live_endpoints(value: Array) -> void:
	surfaces = {}
	for endpoint in value:
		var surface: Dictionary = endpoint.get("surface", {})
		if not str(surface.get("actor", "")).is_empty():
			surfaces[str(surface.actor)] = surface
	if is_inside_tree():
		sample(source_seconds)


func set_entity_geometry(surface: Dictionary) -> void:
	# Optional single-receiver seam; the array seam above supports several owners.
	if not str(surface.get("actor", "")).is_empty():
		surfaces[str(surface.actor)] = surface
		if is_inside_tree():
			sample(source_seconds)


func owner_envelope(owner: Dictionary, seconds: float) -> float:
	var result := smoothstep(float(owner.begin_seconds), float(owner.begin_seconds) + float(specification.rise_seconds), seconds)
	if float(owner.removed_seconds) >= 0.0:
		result *= 1.0 - smoothstep(float(owner.removed_seconds), float(owner.removed_seconds) + float(specification.release_seconds), seconds)
	return result


func _surface_profile(surface: Dictionary) -> Dictionary:
	var actor: String = surface.actor
	var pose: Array = surface.get("pose_key", [])
	# The host's key includes actual source texture, frame, quarter and normal profile.
	# Uniform actor movement translates these measured local points; it does not
	# choose another patch of floor or change its source UV ownership.
	if not pose.is_empty() and profiles.has(actor) and profiles[actor].pose == pose:
		var cached: Dictionary = profiles[actor].duplicate(false)
		cached.origin = surface.origin
		profiles[actor] = cached
		return cached
	var points: Array = surface.get("points", [])
	if points.size() < 8:
		return {}
	var normal := Vector3.ZERO
	var bottom := INF
	var top := -INF
	for point in points:
		normal += point.normal
		bottom = minf(bottom, float(point.position.y - surface.origin.y))
		top = maxf(top, float(point.position.y - surface.origin.y))
	normal.y = 0.0
	if normal.is_zero_approx() or top - bottom < .015:
		return {}
	normal = normal.normalized()
	var side := normal.cross(Vector3.UP).normalized()
	var half_width := .0
	for point in points:
		half_width = maxf(half_width, absf((point.position - surface.origin).dot(side)))
	var columns := int(specification.surface_columns)
	var rows := int(specification.surface_rows)
	assert(columns > 2 and rows > 2 and half_width > 0.0)
	var bins: Dictionary = {}
	for point in points:
		var local: Vector3 = point.position - surface.origin
		var column := clampi(roundi((local.dot(side) / half_width + 1.0) * .5 * float(columns - 1)), 0, columns - 1)
		var row := clampi(roundi(inverse_lerp(bottom, top, local.y) * float(rows - 1)), 0, rows - 1)
		var key := Vector2i(column, row)
		if not bins.has(key):
			bins[key] = []
		bins[key].append({"position":local, "normal":point.normal})
	var contacts: Array = []
	for row in rows:
		var height := lerpf(bottom, top, float(row) / float(rows - 1))
		for column in columns:
			var across := lerpf(-half_width, half_width, float(column) / float(columns - 1))
			var candidates: Array = []
			var radius := 0
			while candidates.is_empty() and radius < maxi(rows, columns):
				for y in range(maxi(0, row - radius), mini(rows, row + radius + 1)):
					for x in range(maxi(0, column - radius), mini(columns, column + radius + 1)):
						if bins.has(Vector2i(x, y)):
							candidates.append_array(bins[Vector2i(x, y)])
				radius += 1
			var closest: Dictionary = {}
			var distance := INF
			for candidate in candidates:
				var squared := pow((candidate.position as Vector3).dot(side) - across, 2.0) + pow(float(candidate.position.y) - height, 2.0)
				if squared < distance:
					distance = squared
					closest = candidate
			contacts.append(closest)
	var result := {"origin":surface.origin, "normal":normal, "side":side, "bottom":bottom, "top":top,
		"half_width":half_width, "columns":columns, "rows":rows, "contacts":contacts,
		"pose":pose.duplicate(true), "points":points.size()}
	profiles[actor] = result
	return result


func _contact(profile: Dictionary, across_fraction: float, height_fraction: float) -> Dictionary:
	var x := clampf((across_fraction + 1.0) * .5 * float(profile.columns - 1), 0.0, float(profile.columns - 1))
	var y := clampf(height_fraction * float(specification.get("wrap_height_fraction", 1.0)) * float(profile.rows - 1), 0.0, float(profile.rows - 1))
	var first_x := floori(x)
	var first_y := floori(y)
	var position := Vector3.ZERO
	var normal := Vector3.ZERO
	var measured_corners: Array[Vector3] = []
	for row_offset in 2:
		for column_offset in 2:
			var column := mini(int(profile.columns) - 1, first_x + column_offset)
			var row := mini(int(profile.rows) - 1, first_y + row_offset)
			var weight := (1.0 - (x - first_x) if column_offset == 0 else x - first_x) * (1.0 - (y - first_y) if row_offset == 0 else y - first_y)
			var point: Dictionary = profile.contacts[row * int(profile.columns) + column]
			position += (point.position as Vector3) * weight
			normal += (point.normal as Vector3) * weight
			measured_corners.append(profile.origin + (point.position as Vector3))
	normal = normal.normalized()
	position = profile.origin + position + normal * float(specification.surface_clearance_world_units)
	var distance := INF
	for corner in measured_corners:
		distance = minf(distance, position.distance_to(corner))
	return {"position":position, "normal":normal, "distance_to_measured_corner":distance}


func _anchor_coordinate(index: int, rest_world: Vector3, anchor: Dictionary) -> Dictionary:
	var offset: Vector3 = rest_world - anchor.origin
	var across := offset.dot(anchor.side)
	var along := offset.dot(anchor.normal)
	var width: float = anchor.half_width
	var margin := float(specification.anchor_margin_world_units)
	var transverse := 1.0 - smoothstep(width, width + margin, absf(across))
	var t := inverse_lerp(-float(anchor.run), float(anchor.run), along)
	if transverse <= 0.0 or t <= 0.0 or t >= 1.0:
		return {}
	return {"index":index, "rest_world":rest_world, "across":across,
		"fraction":clampf(across / width, -1.0, 1.0), "t":t, "weight":transverse}


func _constraint(coordinate: Dictionary, anchor: Dictionary, profile: Dictionary) -> Dictionary:
	var rest_world: Vector3 = coordinate.rest_world
	var across := float(coordinate.across)
	var t := float(coordinate.t)
	var fraction := float(coordinate.fraction)
	var target: Vector3
	var contact: bool = false
	var guided_band: bool = false
	if t < .5:
		# The visible source has no hidden rear samples. This is a disclosed
		# unsupported return span from a real crest to a pinned original floor.
		var crest := _contact(profile, fraction, 1.0)
		var floor_anchor: Vector3 = anchor.origin + anchor.side * across - anchor.normal * float(anchor.run)
		floor_anchor.y = rest_world.y
		target = floor_anchor.lerp(crest.position, smoothstep(0.0, .5, t))
	else:
		var height := 1.0 - smoothstep(.5, 1.0, t)
		var support := _contact(profile, fraction, height)
		var floor_blend := smoothstep(.88, 1.0, t)
		target = (support.position as Vector3).lerp(rest_world, floor_blend)
		guided_band = floor_blend <= 0.0 and float(coordinate.weight) >= 1.0
		# Interpolation across a silhouette hole is a tension span, not a
		# recovered body surface. This witness never changes the visible mesh.
		contact = guided_band and float(support.distance_to_measured_corner) <= float(specification.contact_witness_max_gap_world_units)
	return {"target":target, "measured_front_contact":contact, "surface_guided_band":guided_band}


func _cache_anchored_vertices(identity: String, anchor: Dictionary, world_transform: Transform3D) -> void:
	var selected: Array = []
	for index in rest_vertices.size():
		var uv: Vector2 = source_uv[index]
		var boundary := minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
		if boundary <= .02:
			continue
		var coordinate := _anchor_coordinate(index, world_transform * rest_vertices[index], anchor)
		if not coordinate.is_empty():
			selected.append(coordinate)
	anchored_vertices[identity] = selected


func sample(seconds: float) -> void:
	source_seconds = seconds
	vertices.resize(source_vertices.size())
	observations = {"owners":[], "raised_vertices":0, "contact_vertices":0, "surface_guided_vertices":0, "overlap_vertices":0, "maximum_lift_world_units":0.0}
	var active: Array = []
	var inverse := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	var world_transform := global_transform if is_inside_tree() else Transform3D.IDENTITY
	for owner in owners:
		var actor: String = owner.actor_id
		var strength := owner_envelope(owner, seconds)
		var profile := _surface_profile(surfaces[actor]) if surfaces.has(actor) else {}
		# Removal may coincide with the recipient becoming unavailable. Only
		# the finite supplied removal tail may reuse its last real measurement.
		if profile.is_empty() and float(owner.removed_seconds) >= 0.0 and seconds >= float(owner.removed_seconds):
			profile = profiles.get(actor, {})
		observations.owners.append({"owner_uuid":owner.owner_uuid, "actor_id":actor, "strength":strength, "surface_points":int(profile.get("points", 0))})
		if profile.is_empty() or strength <= 0.0:
			continue
		if not anchors.has(str(owner.owner_uuid)):
			anchors[str(owner.owner_uuid)] = {"origin":profile.origin, "side":profile.side, "normal":profile.normal,
				"half_width":profile.half_width, "run":maxf(float(profile.top) * float(specification.return_run_height_ratio), float(profile.half_width) + float(specification.anchor_margin_world_units))}
			_cache_anchored_vertices(str(owner.owner_uuid), anchors[str(owner.owner_uuid)], world_transform)
		active.append({"owner":owner, "profile":profile, "anchor":anchors[str(owner.owner_uuid)], "strength":strength})
	if specification.has("raised_strand_alpha"):
		var wrap_strength := 0.0
		for binding in active:
			wrap_strength = maxf(wrap_strength, float(binding.strength))
		material.set_shader_parameter("web_wrap_strength", wrap_strength)
	# Deployment ends by this exact upper bound of the original equations.
	# Once settled, only the local anchored source vertices need a new position.
	if seconds >= deployment_end_seconds:
		vertices = rest_vertices.duplicate()
	else:
		for index in vertices.size():
			vertices[index] = Source.position(source_specs[index], seconds)
	var strongest := PackedFloat32Array()
	strongest.resize(vertices.size())
	var chosen: Dictionary = {}
	var contributors: Dictionary = {}
	for binding in active:
		for coordinate in anchored_vertices[str(binding.owner.owner_uuid)]:
			var index := int(coordinate.index)
			contributors[index] = int(contributors.get(index, 0)) + 1
			var strength := float(coordinate.weight) * float(binding.strength)
			if strength > strongest[index]:
				strongest[index] = strength
				chosen[index] = {"constraint":_constraint(coordinate, binding.anchor, binding.profile), "rest_world":coordinate.rest_world}
	for index in chosen:
		var constraint: Dictionary = chosen[index].constraint
		var deployed_strength := float(strongest[index]) * (1.0 if seconds >= deployment_end_seconds else Source.deployment(source_specs[index], seconds))
		var result: Vector3 = (world_transform * vertices[index]).lerp(constraint.target, deployed_strength)
		var rest_world: Vector3 = chosen[index].rest_world
		if result.y > rest_world.y + .01:
			observations.raised_vertices += 1
		if constraint.measured_front_contact and deployed_strength >= .999:
			observations.contact_vertices += 1
		if constraint.surface_guided_band and deployed_strength >= .999:
			observations.surface_guided_vertices += 1
		if int(contributors[index]) > 1:
			observations.overlap_vertices += 1
		observations.maximum_lift_world_units = maxf(float(observations.maximum_lift_world_units), result.y - rest_world.y)
		vertices[index] = inverse * result
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	# The source is unshaded and does not read NORMAL. Retain its original
	# attributes instead of introducing a redundant per-frame normal rebuild.
	arrays[Mesh.ARRAY_NORMAL] = source_normals
	arrays[Mesh.ARRAY_TEX_UV] = source_uv
	arrays[Mesh.ARRAY_INDEX] = source_indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func capture_observation() -> Dictionary:
	var result := observations.duplicate(true)
	result.merge({"method":"prescribed anchored deformation; not cloth simulation", "source_seconds":source_seconds,
		"original_deployment_end_seconds":deployment_end_seconds,
		"source_vertices":source_vertices.size(), "source_triangles":source_indices.size() / 3,
		"mesh_instances":1, "source_uv_unchanged":true, "source_mask_palette_unchanged":true,
		"zone_uuid":specification.zone_uuid, "admitted_memberships":owners.size(),
		"anchored_source_patches":anchors.size(), "optical_lights":0,
		"wrap_height_fraction":float(specification.get("wrap_height_fraction",1.0)),
		"raised_strand_alpha":float(specification.get("raised_strand_alpha",1.0)),
		"hidden_rear_surface":"not provided; unsupported return span", "rules_solver":false,
		"constraint_arbitration":"maximum supplied deformation strength, stable UUID tie order"})
	return result

const VfxPackageIO_e5338118a9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
