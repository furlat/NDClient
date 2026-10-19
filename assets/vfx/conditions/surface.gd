extends RefCounted
## Adapt the existing GPU receiving kernels to the current recipient. Static
## template meshes remain shared; only a changed pose uploads its point table.
## There is no source constructor, mesh generation or nearest-point CPU search.
var current_surface: Dictionary = {}
var entries: Array = []
var last_key: Array = []
var texture: ImageTexture
var uploads := 0
var admitted_geometry := false
var height_visual: Node3D
var height_scale := Vector3.ONE
var head_groups: Array = []
var height_specification: Dictionary = {}
var sphere_radius := 0.0


func configure(visual: Node3D, specification: Dictionary, geometry: Array) -> void:
	assert(specification.kind in ["height_fit", "forms", "curves", "vanes", "support", "head", "sphere", "electric_contact", "patches", "droplets"], "Unsupported receiving kernel")
	if specification.kind == "height_fit":
		height_visual = visual
		height_scale = visual.scale
		height_specification = specification
		for path in specification.get("head_groups", []):
			var group: Node3D = visual.get_node(path)
			head_groups.append({"node": group, "basis": group.global_basis})
		entries.append({"kind": "height_fit"})
		height_visual.hide()
		return
	for entry in geometry:
		var node: GeometryInstance3D = entry.node
		if node is MeshInstance3D and node.has_meta("condition_receiving_template"):
			entries.append({"node": node, "material": node.material_override, "kind": specification.kind,
				"settings": specification.get("settings", {}), "visual": visual})
			node.hide()


func update(surface: Dictionary) -> void:
	current_surface = surface
	if surface.get("points", []).size() < 8:
		admitted_geometry = false
		if height_visual != null:
			height_visual.hide()
			last_key = []
			return
		for entry in entries:
			entry.node.hide()
		last_key = []
		return
	var identity: Array = surface.get("gpu_geometry_key", [])
	if not entries.is_empty() and entries[0].kind == "sphere":
		# Elevation can change while the pose revision remains identical.
		# The original force material clips in world space, so its ground
		# plane must follow a vertical move without resizing the enclosure.
		for entry in entries:
			entry.material.set_shader_parameter("field_ground_height", surface.get("origin", Vector3.ZERO).y)
	# An explicit pose revision is the cheap path. With no revision the caller
	# must send this input only on an actual geometry change.
	if not identity.is_empty() and identity == last_key:
		return
	if entries.is_empty():
		return
	last_key = identity.duplicate()
	if height_visual != null:
		var frame: Transform3D = height_visual.get_parent().global_transform
		var inverse_frame := frame.affine_inverse()
		var high := -INF
		var low := INF
		var centre := Vector3.ZERO
		for point in surface.points:
			var local: Vector3 = inverse_frame * point.position
			high = maxf(high, local.y)
			low = minf(low, local.y)
			centre += local
		centre /= float(surface.points.size())
		var factor: float = (high - low) / float(height_specification.reference_height_cells)
		height_visual.scale = height_scale * factor
		for group in head_groups:
			group.node.global_position = frame * Vector3(centre.x, high + float(height_specification.head_clearance_cells), centre.z)
			group.node.global_basis = frame.basis * group.basis
		height_visual.show()
		admitted_geometry = true
		uploads += 1
		return
	var inverse: Transform3D = entries[0].visual.global_transform.affine_inverse()
	var origin: Vector3 = inverse * surface.get("origin", Vector3.ZERO)
	var kind: String = entries[0].kind
	var points := []
	var centre := Vector3.ZERO
	var normal := Vector3.ZERO
	var low := INF
	var high := -INF
	for point in surface.points:
		var allowed: Array = entries[0].settings.get("geometry_slots", [])
		if not allowed.is_empty() and point.get("slot", "body") not in allowed:
			continue
		var position: Vector3 = inverse * point.position
		var direction: Vector3 = (inverse.basis * point.normal).normalized()
		points.append({"position": position, "normal": direction, "slot": point.get("slot", "body")})
		centre += position
		normal += direction
		low = minf(low, position.y)
		high = maxf(high, position.y)
	if points.size() < 8:
		admitted_geometry = false
		last_key = []
		for entry in entries:
			entry.node.hide()
		return
	centre /= float(points.size())
	if entries[0].settings.has("fraction_min") or entries[0].settings.has("fraction_max"):
		var settings: Dictionary = entries[0].settings
		points = points.filter(func(point: Dictionary) -> bool:
			var fraction: float = (point.position.y-low)/maxf(.001,high-low)
			return fraction >= float(settings.get("fraction_min",0.)) and fraction <= float(settings.get("fraction_max",1.)))
		if points.size() < 8:
			admitted_geometry = false
			last_key = []
			return
		centre = Vector3.ZERO
		for point in points:
			centre += point.position
		centre /= float(points.size())
	if kind == "droplets":
		var radius: float = entries[0].settings.get("candidate_radius_cells", INF)
		points = points.filter(func(point: Dictionary) -> bool: return point.position.distance_to(centre) < radius)
		if points.is_empty():
			admitted_geometry = false
			last_key = []
			return
	if kind == "sphere":
		var minimum := Vector3(INF, INF, INF)
		var maximum := -minimum
		for point in points:
			minimum = minimum.min(point.position)
			maximum = maximum.max(point.position)
		var target_centre := (minimum + maximum) * .5
		# The original spell measures the enclosure once. Animation must not
		# make a rigid force sphere expand and contract with Run/Idle poses.
		if sphere_radius <= 0.0:
			for point in points:
				sphere_radius = maxf(sphere_radius, target_centre.distance_to(point.position))
			sphere_radius += float(entries[0].settings.clearance_cells)
			height_specification.centre_offset = target_centre - origin
		for entry in entries:
			entry.node.scale = Vector3.ONE * sphere_radius / float(entry.settings.reference_radius_cells)
			entry.node.position = origin + height_specification.centre_offset
			entry.material.set_shader_parameter("field_ground_height", surface.get("origin", Vector3.ZERO).y)
			entry.node.show()
		admitted_geometry = true
		uploads += 1
		return
	if kind == "head":
		var head_points := points.filter(func(point: Dictionary) -> bool:
			return point.slot in ["head", "helmet", "hair", "beard"])
		if head_points.size() >= 4:
			points = head_points
		else:
			# A raised staff or pose-coupled wing cannot redefine the top of
			# the actor's head. Full-body creature receivers use only their
			# body channel for this fallback; specialized creatures stay a
			# separate staging review rather than a fabricated head socket.
			points = points.filter(func(point: Dictionary) -> bool:
				return point.slot in ["body", "chest", "neck"])
			low = INF
			high = -INF
			for point in points:
				low = minf(low, point.position.y)
				high = maxf(high, point.position.y)
			var threshold: float = lerpf(low, high, float(entries[0].settings.head_fraction_min))
			points = points.filter(func(point: Dictionary) -> bool: return point.position.y >= threshold)
		if points.size() < 4:
			admitted_geometry = false
			last_key = []
			return
		centre = Vector3.ZERO
		normal = Vector3.ZERO
		for point in points:
			centre += point.position
			normal += point.normal
		centre /= float(points.size())
		normal = Vector3(normal.x, 0, normal.z).normalized()
		if normal.is_zero_approx():
			admitted_geometry = false
			last_key = []
			return
		var side := Vector3.UP.cross(normal).normalized()
		var left: Dictionary = points[0]
		var right: Dictionary = points[0]
		for point in points:
			if point.position.dot(side) < left.position.dot(side): left = point
			if point.position.dot(side) > right.position.dot(side): right = point
		for entry in entries:
			var material: ShaderMaterial = entry.material
			material.set_shader_parameter("gpu_head_heading", -normal)
			material.set_shader_parameter("gpu_head_side", side)
			material.set_shader_parameter("gpu_head_left", left.position - centre + left.normal * .035)
			material.set_shader_parameter("gpu_head_right", right.position - centre + right.normal * .035)
			material.set_shader_parameter("gpu_head_left_normal", left.normal)
			material.set_shader_parameter("gpu_head_right_normal", right.normal)
			entry.node.position = centre
			entry.node.show()
		admitted_geometry = true
		uploads += 1
		return
	normal = normal.normalized()
	if normal.is_zero_approx():
		admitted_geometry = false
		last_key = []
		return
	var up := Vector3.UP.slide(normal).normalized()
	if up.is_zero_approx():
		up = Vector3.FORWARD.slide(normal).normalized()
	if kind == "patches":
		# Preserve receiving_patches' original principal-axis fit. Laughter
		# already uses a prone body; a fixed vertical frame would leave the
		# original material floating above its head instead of on the torso.
		up = Vector3(.31, 1.0, .17).slide(normal).normalized()
		for iteration in 12:
			var multiplied := Vector3.ZERO
			for point in points:
				var delta: Vector3 = (point.position - centre).slide(normal)
				multiplied += delta * delta.dot(up)
			if multiplied.is_zero_approx():
				admitted_geometry = false
				last_key = []
				return
			up = multiplied.normalized()
		if up.dot(Vector3.UP) < 0.0:
			up = -up
	var side := normal.cross(up).normalized()
	var height_radius := .025
	var width_radius := .025
	for point in points:
		height_radius = maxf(height_radius, absf((point.position - centre).dot(up)))
		width_radius = maxf(width_radius, absf((point.position - centre).dot(side)))
	if kind == "vanes":
		var body_height: float = high - origin.y
		points = points.filter(func(point: Dictionary) -> bool:
			var fraction: float = (point.position.y - origin.y) / maxf(.001, body_height)
			return point.slot in ["body", "chest", "belt", "cloak"] and fraction >= .43 and fraction <= .9)
		if points.size() < 8:
			admitted_geometry = false
			last_key = []
			return
		centre = Vector3.ZERO
		normal = Vector3.ZERO
		for point in points:
			centre += point.position
			normal += point.normal
		centre /= float(points.size())
		normal = Vector3(normal.x, 0.0, normal.z).normalized()
		up = Vector3.UP
		side = up.cross(normal).normalized()
		width_radius = .04
		for point in points:
			width_radius = maxf(width_radius, absf((point.position - centre).dot(side)))
	var relative: Vector3 = origin if kind in ["vanes", "support", "electric_contact", "droplets"] else centre
	var image := Image.create_empty(points.size(), 2, false, Image.FORMAT_RGBAF)
	for index in points.size():
		var point: Vector3 = points[index].position - relative
		var direction: Vector3 = points[index].normal
		image.set_pixel(index, 0, Color(point.x, point.y, point.z, 1.0))
		image.set_pixel(index, 1, Color(direction.x, direction.y, direction.z, 1.0))
	if texture != null and texture.get_size() == Vector2(image.get_size()):
		texture.update(image)
	else:
		texture = ImageTexture.create_from_image(image)
	uploads += 1
	admitted_geometry = true
	for entry in entries:
		var material: ShaderMaterial = entry.material
		var settings: Dictionary = entry.settings
		if kind == "droplets":
			material.set_shader_parameter("vfx_droplet_points", texture)
			material.set_shader_parameter("vfx_droplet_count", points.size())
		elif kind == "electric_contact":
			material.set_shader_parameter("gpu_contact_points", texture)
			material.set_shader_parameter("gpu_contact_count", points.size())
			material.set_shader_parameter("gpu_contact_origin", origin)
			material.set_shader_parameter("gpu_contact_to_local", Projection.IDENTITY)
		elif kind == "support":
			material.set_shader_parameter("gpu_support_points", texture)
			material.set_shader_parameter("gpu_support_count", points.size())
			material.set_shader_parameter("gpu_support_centre", centre - origin)
			material.set_shader_parameter("gpu_support_normal", normal)
			material.set_shader_parameter("gpu_support_up", up)
			material.set_shader_parameter("gpu_support_side", side)
			material.set_shader_parameter("gpu_support_bottom", low - origin.y)
			material.set_shader_parameter("gpu_support_height", high - low)
			material.set_shader_parameter("gpu_support_half_width", width_radius)
			if settings.get("vine_bounds", false):
				var left := INF
				var right := -INF
				for point in points:
					var across: float = (point.position - origin).dot(side)
					left = minf(left, across)
					right = maxf(right, across)
				material.set_shader_parameter("gpu_vine_left", left)
				material.set_shader_parameter("gpu_vine_right", right)
				material.set_shader_parameter("gpu_vine_height", high - origin.y)
		else:
			material.set_shader_parameter("gpu_body_points", texture)
			material.set_shader_parameter("gpu_body_count", points.size())
			material.set_shader_parameter("gpu_body_up", up)
			material.set_shader_parameter("gpu_body_side", side)
			var height := height_radius
			var width := width_radius
			if kind == "forms":
				if settings.get("readable", false):
					height = clampf(height, .055, float(settings.height_cap_cells))
					width = clampf(width, .07, float(settings.width_cap_cells))
				else:
					height = minf(height, float(settings.height_cap_cells))
					width = minf(width, float(settings.width_cap_cells))
			if kind == "vanes":
				height = high - origin.y
				material.set_shader_parameter("gpu_vane_centre", centre - origin)
			material.set_shader_parameter("gpu_body_radii", Vector2(height, width))
		entry.node.position = Vector3.ZERO if kind == "electric_contact" else relative
		entry.node.show()
