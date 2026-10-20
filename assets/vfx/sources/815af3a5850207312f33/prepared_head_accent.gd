extends "res://assets/vfx/sources/35053d9088ac18c0b474/head_accent.gd"
## Same psychic path equations, with source programs/templates prepared offline.
static var banks := {}
static var measured_frames := {}
static var measured_order: Array = []
var station_image: Image
var station_texture: ImageTexture

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_head)]

static func make_component(input: Dictionary) -> Node3D:
	var path: String = input.prepared_head
	if not banks.has(path):
		banks[path] = VfxPackageIO_815af3a585.resource(path)
	var bank: Resource = banks[path]
	assert(bank.constructor == "res://assets/vfx/sources/35053d9088ac18c0b474/head_accent.gd")
	var node: Node3D = VfxPackageIO_815af3a585.resource("res://assets/vfx/sources/815af3a5850207312f33/prepared_head_accent.gd").new()
	node.settings = input.duplicate(true)
	# Source stations already have to be evaluated for transparent draw bounds.
	# Share that one small upload across the private materials instead of
	# deriving different tangents from analytically rounded GPU coordinates.
	node.station_image = Image.create(33, bank.meshes.size(), false, Image.FORMAT_RGBAF)
	node.station_texture = ImageTexture.create_from_image(node.station_image)
	for original in bank.materials:
		var material: ShaderMaterial = original.duplicate(false)
		material.set_shader_parameter("gpu_head_source_stations", true)
		material.set_shader_parameter("gpu_head_stations", node.station_texture)
		material.set_shader_parameter("gpu_head_count", int(input.count))
		node.materials.append(material)
	for index in bank.meshes.size():
		var piece := MeshInstance3D.new()
		piece.name = "PsychicPiece" + str(index)
		piece.top_level = true
		piece.mesh = bank.meshes[index]
		piece.custom_aabb = bank.bounds[index]
		piece.material_override = node.materials[bank.material_indices[index]]
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for uniform in bank.instance_uniforms[index]:
			piece.set_instance_shader_parameter(uniform, bank.instance_uniforms[index][uniform])
		piece.hide()
		node.add_child(piece)
		node.pieces.append(piece)
	return node

func source_bindings() -> Dictionary:
	return {"geometry": Array(pieces), "materials": Array(materials), "static_material_topology": true}

func set_entity_geometry(value: Dictionary) -> void:
	surface = value

func set_live_endpoints(value: Array) -> void:
	endpoints = value

func _rebuild() -> void:
	if envelope <= .0001 or not _frame():
		_hide()
		return
	# Keep the source's world-space operation order and float station upload.
	# Its fragment uses NORMAL, so almost identical analytic paths are not
	# interchangeable: their finite-difference tangents can change the streaks.
	# One compact atlas supplies all layers; no triangle generation or per-piece
	# texture update is needed. Preserve full layer bounds for transparent sort.
	var count := int(settings.count)
	var amount := float(settings.get("intensity", 1.0))
	for number in count:
		var sign_value := -1.0 if number % 2 == 0 else 1.0
		var contact := _support(sign_value)
		var anchor: Vector3 = contact.position + contact.normal * .035
		if settings.get("mode", "") == "voice":
			anchor = endpoints[0].point + heading * .055
		var bounds := AABB()
		var maximum_width := 0.0
		for station in 33:
			var u := float(station) / 32.0
			var point: Vector3
			if settings.shape == "folds":
				var pulse := sin(local_clock * 3.0 - u * TAU + float(number))
				point = anchor + side * sign_value * (.028 + .018 * sin(u * PI) + .008 * pulse)
				point += heading * ((u - .5) * .17 + float(number / 2) * .026)
				point += Vector3.UP * (.038 * sin(u * TAU + .35 * sign_value) + .006 * pulse)
				point += contact.normal * (.012 * sin(u * PI) + .006 * sin(local_clock * 2.0 + u * PI + number))
			else:
				var angle := lerpf(-1.2, 1.2, u) + .12 * sin(local_clock * 3.0 + number)
				var r := .11 + float(number / 2) * .045
				point = anchor + side * sign_value * (.025 + r * (1.0 - cos(angle)))
				point += Vector3.UP * (sin(angle) * r) + heading * (.05 * sin(u * PI + local_clock * 1.4 + number))
			if settings.get("mode", "") == "voice":
				point = anchor + heading * (u * .16) + side * ((u - .5) * .06) + Vector3.UP * (.035 * sin(u * PI + number))
			elif settings.get("mode", "") == "saved":
				point += contact.normal * (.10 * smoothstep(0.0, .3, local_clock))
			point -= centre
			bounds = AABB(point, Vector3.ZERO) if station == 0 else bounds.expand(point)
			var width := float(settings.get("width_cells", .025)) * pow(maxf(0.0, sin(u * PI)), .75) * amount * (1.0 + .12 * sin(local_clock * 4.0 - u * TAU + number))
			maximum_width = maxf(maximum_width, width)
			for layer in materials.size():
				station_image.set_pixel(station, layer * count + number, Color(point.x, point.y, point.z, width * (1.0 + float(layer) * .25)))
		for layer in materials.size():
			var piece: MeshInstance3D = pieces[layer * count + number]
			piece.custom_aabb = bounds.grow(maximum_width * (1.0 + float(layer) * .25) + .001)
			piece.global_transform = Transform3D(Basis.IDENTITY, centre)
			piece.show()
	station_texture.update(station_image)

func _frame() -> bool:
	if endpoints.size() < 2 or surface.get("points", []).is_empty():
		return false
	heading = (endpoints[1].point - endpoints[0].point).normalized()
	var pose := preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	# Only immutable measured identities qualify; an absent identity never
	# turns unknown/changed geometry into a stale cached result.
	var key := [pose, heading]
	if not pose.is_empty() and measured_frames.has(key):
		var frame: Dictionary = measured_frames[key]
		relative_centre = frame.relative_centre
		centre = surface.origin + relative_centre
		side = frame.side
		radius = frame.radius
		head_points = frame.head_points
		fallback_normal = frame.fallback_normal
		measured_key = frame.measured_key.duplicate(true)
		# The parent clears/refills this dictionary when the next pose changes.
		# Never let that mutate a shared immutable frame's support offsets.
		support_cache = frame.supports.duplicate(true)
		return true
	if not super._frame():
		return false
	_support(-1.)
	_support(1.)
	if not pose.is_empty():
		if measured_order.size() == 64:
			measured_frames.erase(measured_order.pop_front())
		measured_order.append(key)
		measured_frames[key] = {"relative_centre": relative_centre, "side": side,
			"radius": radius, "head_points": head_points, "fallback_normal": fallback_normal,
			"measured_key": measured_key.duplicate(true), "supports": support_cache.duplicate(true)}
	return true

const VfxPackageIO_815af3a585 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
