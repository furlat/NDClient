extends Node3D
## Original native masks on different open receiving forms. Actual sampled
## surfaces own placement; supplied condition/damage facts own lifetime.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Values = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")

var settings: Dictionary = {}
var surface: Dictionary = {}
var endpoints: Array = []
var pieces: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var local_clock := 0.0
var envelope := 0.0
var owner_visibility := 1.0
var owner_state: Dictionary = {}
var current_owner_state: Dictionary = {}
var points: Array = []
var centre := Vector3.ZERO
var normal := Vector3.FORWARD
var up := Vector3.UP
var side := Vector3.RIGHT
var height_radius := .1
var width_radius := .1
var heading := Vector3.FORWARD

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/db0b913465a389ae3bc7/receiving_forms.gd", input)


static func construct(script_path: String, input: Dictionary) -> Node3D:
	assert(input.profile in ["leaves", "pressure_folds", "descending_fronds", "offbeat_lobes", "unthreading"])
	var instance: Node3D = VfxPackageIO_db0b913465.resource(script_path).new()
	instance.settings = input.duplicate(true)
	instance.owner_state = input.get("initial_owner_state", {"present": true, "observed": true, "suppressed": false}).duplicate(true)
	instance.current_owner_state = instance.owner_state.duplicate(true)
	for layer in input.layers:
		var donor: Node3D = VfxPackageIO_db0b913465.resource(layer.scene).instantiate()
		var original: ShaderMaterial = donor.get_node(layer.node).material_override
		var material := original.duplicate(true) as ShaderMaterial
		var code: String = original.shader.code.replace("TIME", "control_clock")
		# The source particle/billboard vertex stage is replaced by actual
		# receiving geometry. All source fragment masks/noise samplers remain.
		var begin := code.find("void vertex()")
		var fragment := code.find("void fragment()")
		assert(fragment >= 0)
		if begin >= 0:
			var opening := code.find("{", begin)
			var cursor := opening + 1
			var depth := 1
			while depth > 0 and cursor < code.length():
				if code[cursor] == "{":
					depth += 1
				elif code[cursor] == "}":
					depth -= 1
				cursor += 1
			code = code.substr(0, begin) + "void vertex() {}\n" + code.substr(cursor)
		code = code.replace("blend_add", "blend_mix").replace("cull_back", "cull_disabled")
		if not code.contains("cull_disabled"):
			var render_end := code.find(";", code.find("render_mode"))
			code = code.insert(render_end, ", cull_disabled")
		code = code.replace("diffuse_toon, specular_toon", "unshaded")
		code = Sources.stable_proximity(code)
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float control_clock=0.0;\nuniform float control_envelope=0.0;\nuniform float control_opacity=1.0;\n")
		var finish := "\nALPHA=pow(clamp(ALPHA,0.0,1.0)," + str(float(layer.get("alpha_power", .7))) + ");\n"
		finish += "ALPHA=" + str(float(layer.get("alpha_floor", 0.0))) + "+ALPHA*(1.0-" + str(float(layer.get("alpha_floor", 0.0))) + ");\n"
		finish += "ALPHA*=pow(max(0.0,sin(UV.y*3.14159265)),0.65)*control_envelope*control_opacity*" + str(float(layer.alpha)) + ";\n"
		assert(not code.contains("ALPHA_SCISSOR_THRESHOLD"))
		var shader := Shader.new()
		shader.code = Sources.finish_fragment(code, finish)
		Sources.replace_shader(material, shader)
		for key in layer.get("uniforms", {}):
			material.set_shader_parameter(key, Values.uniform_value(layer.uniforms[key]))
		instance.materials.append(material)
		for number in int(input.count):
			var piece := MeshInstance3D.new()
			piece.name = "ReceivingForm%dLayer%d" % [number, instance.materials.size() - 1]
			piece.mesh = ArrayMesh.new()
			piece.material_override = material
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.top_level = true
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

func set_owner_state(value: Dictionary) -> void:
	if not settings.get("owner_uuid", "").is_empty() and value.get("owner_uuid", "") != settings.owner_uuid:
		return
	current_owner_state = value.duplicate(true)
	sample(local_clock)

func set_owner_visibility(value: float) -> void:
	owner_visibility = clampf(value, 0.0, 1.0)
	sample(local_clock)

func sample(seconds: float) -> void:
	local_clock = seconds
	# These rows are explicitly supplied review observations, not native turns.
	owner_state = current_owner_state.duplicate(true)
	for row in settings.get("review_owner_states", []):
		if seconds >= float(row.at_seconds):
			owner_state = row.state.duplicate(true)
	var present: bool = owner_state.get("present", false) and owner_state.get("observed", false) and not owner_state.get("suppressed", false)
	envelope = smoothstep(0.0, float(settings.apply_seconds), seconds) * owner_visibility if present else 0.0
	if settings.mode != "hold":
		envelope *= 1.0 - smoothstep(float(settings.seconds) - float(settings.retire_seconds), float(settings.seconds), seconds)
	for material in materials:
		material.set_shader_parameter("control_clock", seconds + float(settings.get("source_offset_seconds", 0.0)))
		material.set_shader_parameter("control_envelope", envelope)
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
	if endpoints.size() >= 2:
		heading = (endpoints[1].point - endpoints[0].point).normalized()
	return true

func _support(along: float, across: float) -> Dictionary:
	var neighbours := []
	for point in points:
		var delta: Vector3 = point.position - centre
		var distance: float = pow(delta.dot(up) - along, 2.0) + pow(delta.dot(side) - across, 2.0)
		if neighbours.size() < 4 or distance < float(neighbours.back().distance):
			neighbours.append({"point": point, "distance": distance})
			neighbours.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
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

func _station(number: int, u: float) -> Dictionary:
	var parity := -1.0 if number % 2 == 0 else 1.0
	var clock := (local_clock + float(settings.get("source_offset_seconds", 0.0))) * float(settings.motion_rate)
	var phase := clock + float(number) * 2.17
	# The actual incoming source direction biases the moving receiving fold;
	# normal/depth still come from this recipient, never a camera-facing proxy.
	phase += clampf(-heading.dot(side), -1.0, 1.0) * .45
	var h := minf(height_radius, float(settings.height_cap_cells))
	var w := minf(width_radius, float(settings.width_cap_cells))
	var along: float
	var across: float
	var clearance: float
	match settings.profile:
		"leaves":
			# Separated low shoulder roots curl inward at different depths.
			along = h * (-.35 + 1.1 * u) + .03 * sin(phase + u * PI)
			across = parity * w * (.95 - .65 * u + .1 * sin(phase + u * PI))
			clearance = .045 + .10 * sin(u * PI) + .018 * sin(phase)
		"pressure_folds":
			# Short inward-moving temple folds stay below the head's upper
			# outline. They never become two long horns or a crossing glyph.
			along = h * (-.65 + .75 * u + .22 * float(number / 2))
			across = parity * w * (.95 - .42 * u + .09 * sin(phase + u * TAU))
			clearance = .035 + .03 * float(number / 2) + .045 * sin(u * PI - phase * .5)
		"descending_fronds":
			# Three long separated side fronds fall with independent folds;
			# measured torso/leg surfaces set their volume, not an area shell.
			along = h * (.85 - 1.7 * u + .1 * sin(phase))
			across = w * (float(number) - 1.0) * .73 + .035 * sin(u * TAU + phase)
			clearance = .055 + .045 * float(number) + .06 * sin(u * PI + phase)
		"offbeat_lobes":
			# Open asynchronous S lobes, three different heights and depths.
			# This is a material cue for compulsion, not an actor dance clip.
			along = h * ((float(number) - 1.0) * .5 + (u - .5) * .65 + .10 * sin(phase * 1.3))
			across = w * (.7 * sin(u * PI * 1.35 + phase * .7) + parity * .22)
			clearance = .065 + .04 * float(number) + .07 * sin(u * PI) * (.5 + .5 * sin(phase))
		"unthreading":
			# Disconnected brow/temple flows peel in opposing directions.
			# Keep the face open; no filled head volume or arbitrary symbol.
			along = h * ((float(number) - 1.0) * .42 + .18 * sin(u * TAU + phase))
			across = w * ((u - .5) * 1.6 + .12 * sin(phase * parity))
			clearance = .04 + .045 * float(number) + .035 * sin(u * PI + phase)
	var support := _support(along, across)
	# Sparse support points retain normal/depth while exact measured tangent
	# coordinates avoid all curves clamping to the same topmost pixel.
	var delta: Vector3 = support.position - centre
	support.position += up * (along - delta.dot(up)) + side * (across - delta.dot(side))
	return {"point": support.position + support.normal * clearance, "normal": support.normal,
		"width": float(settings.width_cells) * pow(maxf(0.0, sin(u * PI)), .85)}

func _mesh(number: int, layer: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var stations := []
	for row in 33:
		stations.append(_station(number, float(row) / 32.0))
	for row in 33:
		var u := float(row) / 32.0
		var station: Dictionary = stations[row]
		var tangent: Vector3 = (stations[mini(32, row + 1)].point - stations[maxi(0, row - 1)].point).normalized()
		var across: Vector3 = station.normal.cross(tangent).normalized()
		for column in 5:
			var v := float(column) / 4.0
			var edge := v * 2.0 - 1.0
			vertices.append(station.point - centre + across * edge * float(station.width) + station.normal * (1.0 - edge * edge) * float(settings.camber_cells) * sin(u * PI))
			normals.append(across.cross(tangent).normalized())
			var bounds: Array = layer.get("uv_longitude_bounds", [0.0, 1.0])
			uv.append(Vector2(v, lerpf(float(bounds[0]), float(bounds[1]), u)))
			# Raw vertex data is a source mask input, not a white emission.
			colours.append(Color(1.0, 1.0, 1.0, float(settings.source_alpha)))
			if row > 0 and column > 0:
				var first := (row - 1) * 5 + column - 1
				indices.append_array(PackedInt32Array([first, first + 1, first + 5, first + 1, first + 6, first + 5]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
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
		var piece := pieces[index]
		piece.mesh = _mesh(index % int(settings.count), settings.layers[index / int(settings.count)])
		piece.global_transform = Transform3D(Basis.IDENTITY, centre)
		piece.show()

func capture_observation() -> Dictionary:
	return {"profile": settings.profile, "measured_points": points.size(), "actual_pose_key": surface.get("pose_key", []),
		"receiving_centre": centre, "receiving_normal": normal, "source_heading": heading,
		"native_material_layers": materials.size(), "open_forms": pieces.size(), "optical_lights": 0,
		"source_clock": local_clock + float(settings.get("source_offset_seconds", 0.0)),
		"owner_uuid": settings.get("owner_uuid", ""), "state": owner_state, "rule_solver": false}

const VfxPackageIO_db0b913465 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
