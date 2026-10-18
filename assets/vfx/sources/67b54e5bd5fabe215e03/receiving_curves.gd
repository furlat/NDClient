extends Node3D
## Three explicit native material/geometry profiles. Supplied receiving points,
## normals and owner visibility determine placement; no rules or area solver.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const MaterialValues = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")

var settings: Dictionary = {}
var surface: Dictionary = {}
var endpoints: Array = []
var pieces: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var local_clock := 0.0
var owner_visibility := 1.0
var envelope := 0.0
var points: Array = []
var centre := Vector3.ZERO
var normal := Vector3.FORWARD
var up := Vector3.UP
var side := Vector3.RIGHT
var height_radius := .1
var width_radius := .1

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/67b54e5bd5fabe215e03/receiving_curves.gd", input)

static func construct(path: String, input: Dictionary) -> Node3D:
	assert(input.profile in ["crest", "wake", "split_lens"])
	var instance: Node3D = VfxPackageIO_67b54e5bd5.resource(path).new()
	instance.settings = input.duplicate(true)
	for layer in input.layers:
		var scene: PackedScene = VfxPackageIO_67b54e5bd5.resource(layer.scene)
		var donor := scene.instantiate()
		var original: ShaderMaterial = donor.get_node(layer.node).material_override
		var material := original.duplicate(true) as ShaderMaterial
		var code: String = original.shader.code.replace("TIME", "receiving_clock")
		if layer.get("replace_vertex", false):
			var begin := code.find("void vertex()")
			var fragment := code.find("void fragment()")
			assert(begin >= 0 and fragment > begin)
			code = code.substr(0, begin) + "void vertex() {}\n" + code.substr(fragment)
		code = code.replace("blend_add", "blend_mix").replace("cull_back", "cull_disabled")
		code = code.replace("depth_draw_always", "depth_draw_opaque")
		code = SourceMaterials.stable_proximity(code)
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float receiving_clock=0.0;\nuniform float receiving_envelope=0.0;\nuniform float receiving_opacity=1.0;\n")
		if layer.get("soft_smoke", false):
			# Preserve all three original smoke samples and palette lookups; move
			# their UVs independently and feather the original scissor threshold.
			code = code.replace("texture(Dark_variation, n_out49p0)", "texture(Dark_variation, n_out49p0+vec2(.07,-.13)*receiving_clock)")
			code = code.replace("texture(Disapear_Noise, n_out52p0)", "texture(Disapear_Noise, n_out52p0+vec2(-.11,.09)*receiving_clock)")
			code = code.replace("texture(Noise_Color, n_out54p0)", "texture(Noise_Color, n_out54p0+vec2(.04,.17)*receiving_clock)")
			code = code.replace("ALPHA_SCISSOR_THRESHOLD = n_out33p4;", "ALPHA*=smoothstep(n_out33p4-.12,n_out33p4+.12,ALPHA);")
		var finish := "\nALPHA=pow(clamp(ALPHA,0.0,1.0)," + str(float(layer.get("alpha_power", 1.0))) + ");\n"
		finish += "ALPHA*=receiving_envelope*receiving_opacity*" + str(float(layer.alpha)) + ";\n"
		if layer.get("soft_smoke", false):
			finish += "EMISSION*=0.18;\n"
		assert(not code.contains("MODELVIEW_MATRIX =") and not code.contains("ALPHA_SCISSOR_THRESHOLD"))
		var shader := Shader.new()
		shader.code = SourceMaterials.finish_fragment(code, finish)
		SourceMaterials.replace_shader(material, shader)
		for name in layer.get("uniforms", {}):
			material.set_shader_parameter(name, MaterialValues.uniform_value(layer.uniforms[name]))
		instance.materials.append(material)
		for number in int(input.count):
			var piece := MeshInstance3D.new()
			piece.name = "ReceivingLayer%dCurve%d" % [instance.materials.size() - 1, number]
			piece.mesh = ArrayMesh.new()
			piece.top_level = true
			piece.material_override = material
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.hide()
			instance.add_child(piece)
			instance.pieces.append(piece)
		donor.free()
	return instance

func set_entity_geometry(value: Dictionary) -> void:
	surface = value
	_rebuild()

func set_live_endpoints(value: Array) -> void:
	endpoints = value
	_rebuild()

func set_owner_visibility(value: float) -> void:
	owner_visibility = clampf(value, 0.0, 1.0)
	sample(local_clock)

func sample(seconds: float) -> void:
	local_clock = seconds
	envelope = smoothstep(0.0, float(settings.apply_seconds), seconds) * owner_visibility
	if settings.mode != "hold":
		envelope *= 1.0 - smoothstep(float(settings.seconds) - float(settings.retire_seconds), float(settings.seconds), seconds)
	for material in materials:
		material.set_shader_parameter("receiving_clock", seconds + float(settings.get("phase_offset_seconds", 0.0)))
		material.set_shader_parameter("receiving_envelope", envelope)
	_rebuild()

func _measure() -> bool:
	points = surface.get("points", [])
	if points.size() < 8:
		return false
	centre = Vector3.ZERO
	normal = Vector3.ZERO
	for point in points:
		centre += point.position
		normal += point.normal
	centre /= float(points.size())
	normal = normal.normalized()
	if normal.is_zero_approx():
		return false
	up = Vector3.UP.slide(normal).normalized()
	if up.is_zero_approx():
		up = Vector3.FORWARD.slide(normal).normalized()
	side = normal.cross(up).normalized()
	height_radius = .025
	width_radius = .025
	for point in points:
		height_radius = maxf(height_radius, absf((point.position - centre).dot(up)))
		width_radius = maxf(width_radius, absf((point.position - centre).dot(side)))
	return true

func _support(along: float, across: float) -> Dictionary:
	var neighbours := []
	for point in points:
		var delta: Vector3 = point.position - centre
		var distance: float = pow(delta.dot(up) - along, 2.0) + pow(delta.dot(side) - across, 2.0)
		if neighbours.size() < 4 or distance < float(neighbours.back().distance):
			neighbours.append({"point": point, "distance": distance})
			neighbours.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first.distance < second.distance)
			if neighbours.size() > 4:
				neighbours.pop_back()
	var position := Vector3.ZERO
	var receiving_normal := Vector3.ZERO
	var total := 0.0
	for neighbour in neighbours:
		var weight: float = 1.0 / (float(neighbour.distance) + .00015)
		position += neighbour.point.position * weight
		receiving_normal += neighbour.point.normal * weight
		total += weight
	return {"position": position / total, "normal": receiving_normal.normalized()}

func _station(number: int, progress: float) -> Dictionary:
	var parity := -1.0 if number % 2 == 0 else 1.0
	var phase := (local_clock + float(settings.get("phase_offset_seconds", 0.0))) * float(settings.motion_rate) + float(number) * 2.1
	var along: float
	var across: float
	var clearance: float
	match settings.profile:
		"crest":
			# Two separated shoulder crests. Each rises from its own receiving
			# shoulder towards the collar, with a bowed normal-space underside.
			along = height_radius * (.12 + .48 * sin(progress * PI * .78))
			across = parity * width_radius * (.95 - .78 * progress)
			clearance = .055 + .075 * sin(progress * PI) + .012 * sin(phase)
		"wake":
			# Open low spirals beside the actual shins: no ground plane/ring,
			# footprint, disappearance or additional actor opacity treatment.
			along = height_radius * (-.72 + progress * 1.35)
			across = parity * width_radius * (.55 + .32 * sin(progress * TAU - phase))
			clearance = .055 + .075 * (.5 + .5 * cos(progress * TAU - phase))
		"split_lens":
			# The former three upper arcs clamped onto the same top-head
			# support and became a flat cap. These two diagonally flowing open
			# sweeps span measured brow-to-cheek height at different depths.
			var measured_height := minf(height_radius * 1.25, .13)
			var measured_width := minf(width_radius * 1.6, .17)
			along = measured_height * ((progress - .5) * 1.35 + parity * .28) + .015 * sin(phase + progress * TAU)
			across = measured_width * ((.5 - progress) * 1.6 + .2 * sin(progress * TAU + phase) + parity * .18)
			clearance = .045 + .035 * float(number) + .025 * sin(progress * PI + phase)
	var receiving := _support(along, across)
	if settings.profile == "split_lens":
		# Keep the actual support's normal-space depth and normal. Restore
		# only the requested measured tangent coordinates when sparse head
		# points clamp to a neighbouring sample; no camera/body proxy.
		var delta: Vector3 = receiving.position - centre
		receiving.position += up * (along - delta.dot(up)) + side * (across - delta.dot(side))
	return {"point": receiving.position + receiving.normal * clearance, "normal": receiving.normal,
		"width": float(settings.width_cells) * pow(maxf(0.0, sin(progress * PI)), .8)}

func _mesh(number: int, layer: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var source_colour := Color.html(settings.colour).srgb_to_linear()
	source_colour.a = float(settings.source_alpha)
	var stations := []
	for row in 33:
		stations.append(_station(number, float(row) / 32.0))
	for row in 33:
		var progress := float(row) / 32.0
		var station: Dictionary = stations[row]
		var tangent: Vector3 = (stations[mini(32, row + 1)].point - stations[maxi(0, row - 1)].point).normalized()
		var across: Vector3 = station.normal.cross(tangent).normalized()
		for column in 5:
			var fraction := float(column) / 4.0
			var edge := fraction * 2.0 - 1.0
			var point: Vector3 = station.point + across * edge * float(station.width)
			point += station.normal * (1.0 - edge * edge) * float(settings.camber_cells) * sin(progress * PI)
			vertices.append(point - centre)
			normals.append(across.cross(tangent).normalized())
			var bounds: Array = layer.get("uv_longitude_bounds", [0.0, 1.0])
			var lateral_coordinate := fraction
			if layer.has("uv_latitude_bounds"):
				lateral_coordinate = lerpf(float(layer.uv_latitude_bounds[0]), float(layer.uv_latitude_bounds[1]), fraction)
			coordinates.append(Vector2(lateral_coordinate, lerpf(float(bounds[0]), float(bounds[1]), progress)))
			colours.append(source_colour)
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

func _rebuild() -> void:
	if envelope <= .0001 or not _measure():
		for piece in pieces:
			piece.hide()
		return
	for index in pieces.size():
		var layer: Dictionary = settings.layers[index / int(settings.count)]
		pieces[index].global_transform = Transform3D(Basis.IDENTITY, centre)
		pieces[index].mesh = _mesh(index % int(settings.count), layer)
		pieces[index].show()

func capture_observation() -> Dictionary:
	return {"ward_trace_illusion": {"profile": settings.profile, "owner": surface.get("actor"),
		"points": points.size(), "centre": centre, "normal": normal,
		"height_radius": height_radius, "width_radius": width_radius,
		"clock": local_clock, "envelope": envelope, "pieces": pieces.size(),
		"optical_lights": 0, "visible": not pieces.is_empty() and pieces[0].is_visible_in_tree()}}

const VfxPackageIO_67b54e5bd5 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
