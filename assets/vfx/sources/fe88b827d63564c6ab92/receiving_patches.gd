extends Node3D
## Native moving material on small open cambered shapes. Receiving points and
## normals own their spatial support; observed outcomes own admission/lifetime.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const MaterialValues = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")

var settings: Dictionary = {}
var surface: Dictionary = {}
var endpoints: Array = []
var pieces: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var local_clock := 0.0
var envelope := 0.0
var owner_visibility := 1.0
var points: Array = []
var centre := Vector3.ZERO
var normal := Vector3.FORWARD
var principal := Vector3.UP
var transverse := Vector3.RIGHT
var long_radius := .1
var cross_radius := .1

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fe88b827d63564c6ab92/receiving_patches.gd", input)

static func construct(path: String, input: Dictionary) -> Node3D:
	assert(input.shape in ["petal", "pressure"] and int(input.count) > 0)
	var instance: Node3D = VfxPackageIO_fe88b827d6.resource(path).new()
	instance.settings = input.duplicate(true)
	for layer in input.layers:
		var scene: PackedScene = VfxPackageIO_fe88b827d6.resource(layer.scene)
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
		code = SourceMaterials.stable_proximity(code)
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float receiving_clock=0.0;\nuniform float receiving_envelope=0.0;\nuniform float receiving_opacity=1.0;\n")
		# The original wind's very low mask values vanished against a dark body.
		# A monotonic alpha response keeps its moving noise/mask hierarchy while
		# giving the bounded, open receiving shape a readable continuous body.
		var finish := "\nALPHA=pow(clamp(ALPHA,0.0,1.0)," + str(float(layer.get("alpha_power", 1.0))) + ");\n"
		finish += "ALPHA*=receiving_envelope*receiving_opacity*" + str(float(layer.alpha)) + ";\n"
		code = SourceMaterials.finish_fragment(code, finish)
		assert(not code.contains("MODELVIEW_MATRIX =") and not code.contains("ALPHA_SCISSOR_THRESHOLD"))
		var shader := Shader.new()
		shader.code = code
		SourceMaterials.replace_shader(material, shader)
		for name in layer.get("uniforms", {}):
			material.set_shader_parameter(name, MaterialValues.uniform_value(layer.uniforms[name]))
		instance.materials.append(material)
		for number in int(input.count):
			var piece := MeshInstance3D.new()
			piece.name = "ReceivingLayer%dPatch%d" % [instance.materials.size() - 1, number]
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
	envelope = smoothstep(0.0, float(settings.get("apply_seconds", .15)), seconds)
	if settings.mode != "condition":
		envelope *= 1.0 - smoothstep(float(settings.seconds) - float(settings.get("retire_seconds", .3)), float(settings.seconds), seconds)
	envelope *= owner_visibility
	for material in materials:
		material.set_shader_parameter("receiving_clock", seconds)
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
	# Covariance in the actual visible support plane. This follows a fallen
	# torso or a horizontal beast without imposing a humanoid vertical axis.
	var axis := Vector3(.31, 1.0, .17).slide(normal).normalized()
	for iteration in 12:
		var multiplied := Vector3.ZERO
		for point in points:
			var delta: Vector3 = (point.position - centre).slide(normal)
			multiplied += delta * delta.dot(axis)
		if multiplied.is_zero_approx():
			return false
		axis = multiplied.normalized()
	principal = axis
	var bearing := Vector3.UP
	if absf(principal.y) < .3 and endpoints.size() >= 2:
		bearing = (endpoints[1].point - endpoints[0].point).normalized()
	if principal.dot(bearing) < 0.0:
		principal = -principal
	transverse = normal.cross(principal).normalized()
	long_radius = .04
	cross_radius = .04
	for point in points:
		long_radius = maxf(long_radius, absf((point.position - centre).dot(principal)))
		cross_radius = maxf(cross_radius, absf((point.position - centre).dot(transverse)))
	return true

func _support(along: float, across: float) -> Dictionary:
	var neighbours := []
	for point in points:
		var delta: Vector3 = point.position - centre
		var distance: float = pow(delta.dot(principal) - along, 2.0) + pow(delta.dot(transverse) - across, 2.0)
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

func _mesh(number: int, layer: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var sign_value := -1.0 if number % 2 == 0 else 1.0
	var phase := local_clock * float(settings.motion_rate) + float(number) * 1.9
	var source_colour := Color.html(settings.colour).srgb_to_linear()
	source_colour.a = float(settings.get("source_alpha", .8))
	var stations := []
	for row in 33:
		var u := float(row) / 32.0
		var along: float
		var across: float
		var clearance: float
		if settings.shape == "petal":
			along = (u - .5) * minf(long_radius * 1.1, .29) + .06 * sin(phase * .6)
			across = sign_value * cross_radius * (.55 + .16 * sin(u * PI))
			clearance = .045 + .04 * sin(u * PI) + .015 * sin(phase)
		else:
			along = (u - .5) * minf(long_radius * 1.35, .44)
			across = sign_value * cross_radius * .55 + .025 * sin(u * TAU + phase)
			clearance = .045 + .035 * sin(u * TAU * 1.5 - phase)
		var support := _support(along, across)
		var width := float(settings.width_cells) * pow(maxf(0.0, sin(u * PI)), .8)
		stations.append({"point": support.position + support.normal * clearance, "normal": support.normal, "width": width})
	for row in 33:
		var u := float(row) / 32.0
		var station: Dictionary = stations[row]
		var tangent: Vector3 = (stations[mini(32, row + 1)].point - stations[maxi(0, row - 1)].point).normalized()
		for column in 5:
			var v := float(column) / 4.0
			var edge := v * 2.0 - 1.0
			var point: Vector3 = station.point + transverse * edge * float(station.width)
			point += station.normal * (1.0 - edge * edge) * .035 * sin(u * PI)
			vertices.append(point - centre)
			normals.append(transverse.cross(tangent).normalized())
			var bounds: Array = layer.get("uv_longitude_bounds", [0.0, 1.0])
			coordinates.append(Vector2(v, lerpf(float(bounds[0]), float(bounds[1]), u)))
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
	return {"control_patches": {"shape": settings.shape, "mode": settings.mode,
		"owner": surface.get("actor"), "points": points.size(), "centre": centre,
		"principal": principal, "normal": normal, "long_radius": long_radius,
		"cross_radius": cross_radius, "clock": local_clock, "envelope": envelope,
		"pieces": pieces.size(), "optical_lights": 0,
		"visible": not pieces.is_empty() and pieces[0].is_visible_in_tree()}}

const VfxPackageIO_fe88b827d6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
