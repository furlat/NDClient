extends Node3D
## Open cambered support vanes fitted to measured torso and shoulder support.
## Admission, removed controls, grants and owner visibility come from the caller.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const MaterialValues = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")

var settings: Dictionary = {}
var surface: Dictionary = {}
var pieces: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var local_clock := 0.0
var envelope := 0.0
var owner_visibility := 1.0
var measured: Array = []
var origin := Vector3.ZERO
var centre := Vector3.ZERO
var side := Vector3.RIGHT
var outward := Vector3.FORWARD
var height_cells := 0.0
var half_width_cells := 0.0

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/5441f2ac6be4f01f1671/receiving_vanes.gd", input)

static func construct(path: String, input: Dictionary) -> Node3D:
	assert(input.style in ["ascending", "unfurl"])
	assert(input.mode in ["apply", "hold", "response", "remove"])
	assert(float(input.seconds) > 0.0 and not input.layers.is_empty())
	var instance: Node3D = VfxPackageIO_5441f2ac6b.resource(path).new()
	instance.settings = input.duplicate(true)
	for layer in input.layers:
		var scene: PackedScene = VfxPackageIO_5441f2ac6b.resource(layer.scene)
		var donor := scene.instantiate()
		var original: ShaderMaterial = donor.get_node(layer.node).material_override
		var material := original.duplicate(true) as ShaderMaterial
		var code: String = original.shader.code.replace("TIME", "support_clock")
		if layer.get("remove_billboard_vertex", false):
			var start := code.find("void vertex()")
			var finish := code.find("void fragment()")
			assert(start >= 0 and finish > start)
			code = code.substr(0, start) + "void vertex() {}\n" + code.substr(finish)
		code = code.replace("cull_back", "cull_disabled").replace("diffuse_toon", "unshaded")
		code = SourceMaterials.stable_proximity(code)
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=0.0;\nuniform float support_opacity=1.0;\n")
		var finish := "\n"
		if input.get("sheet_animation", false):
			# v67 showed only isolated wind-mask pixels on these small sheets.
			# Keep the native moving sheet colour/alpha, with a quiet continuous
			# cambered body and soft ends so the actual 3D fan remains readable.
			finish += "ALBEDO=mix(COLOR.rgb*0.6,ALBEDO,0.65);\n"
			finish += "ALPHA=(0.25+0.75*clamp(ALPHA,0.0,1.0))*pow(max(0.0,sin(UV.x*3.14159265)),0.7)*pow(max(0.0,sin(UV.y*3.14159265)),0.65);\n"
		finish += "ALPHA*=support_envelope*support_opacity*" + str(float(layer.alpha)) + ";\n"
		code = SourceMaterials.finish_fragment(code, finish)
		assert(not code.contains("MODELVIEW_MATRIX =") and not code.contains("ALPHA_SCISSOR_THRESHOLD"))
		var shader := Shader.new()
		shader.code = code
		SourceMaterials.replace_shader(material, shader)
		for name in layer.get("uniforms", {}):
			material.set_shader_parameter(name, MaterialValues.uniform_value(layer.uniforms[name]))
		instance.materials.append(material)
		for index in int(input.count):
			var piece := MeshInstance3D.new()
			piece.name = "SupportLayer%dVane%d" % [instance.materials.size() - 1, index]
			piece.top_level = true
			piece.mesh = ArrayMesh.new()
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

func set_owner_visibility(value: float) -> void:
	owner_visibility = clampf(value, 0.0, 1.0)
	sample(local_clock)

func sample(seconds: float) -> void:
	local_clock = seconds
	envelope = smoothstep(0.0, float(settings.get("apply_seconds", .2)), seconds)
	if settings.mode != "hold":
		envelope *= 1.0 - smoothstep(float(settings.seconds) - float(settings.get("retire_seconds", .35)), float(settings.seconds), seconds)
	envelope *= owner_visibility
	for material in materials:
		material.set_shader_parameter("support_clock", seconds)
		var accent := 1.0
		if settings.mode == "hold":
			accent += .3 * (1.0 - smoothstep(.35, .9, seconds))
		material.set_shader_parameter("support_envelope", envelope * accent)
	_rebuild()

func _hide() -> void:
	for piece in pieces:
		piece.hide()

func _measure() -> bool:
	measured.clear()
	if surface.get("points", []).is_empty():
		return false
	origin = surface.origin
	height_cells = 0.0
	for point in surface.points:
		height_cells = maxf(height_cells, point.position.y - origin.y)
	if height_cells < .1:
		return false
	centre = Vector3.ZERO
	var normal_sum := Vector3.ZERO
	for point in surface.points:
		var fraction: float = (point.position.y - origin.y) / height_cells
		if point.slot not in ["body", "chest", "belt", "cloak"] or fraction < .43 or fraction > .9:
			continue
		measured.append(point)
		centre += point.position
		normal_sum += point.normal
	if measured.size() < 8:
		return false
	centre /= float(measured.size())
	outward = Vector3(normal_sum.x, 0, normal_sum.z).normalized()
	if outward.is_zero_approx():
		return false
	side = Vector3.UP.cross(outward).normalized()
	half_width_cells = .04
	for point in measured:
		half_width_cells = maxf(half_width_cells, absf((point.position - centre).dot(side)))
	return true

func _support(across_cells: float, elevation_cells: float) -> Dictionary:
	var neighbours := []
	for point in measured:
		var across: float = (point.position - centre).dot(side)
		var distance: float = pow(across - across_cells, 2.0) + pow(point.position.y - origin.y - elevation_cells, 2.0)
		if neighbours.size() < 4 or distance < float(neighbours.back().distance):
			neighbours.append({"point": point, "distance": distance})
			neighbours.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first.distance < second.distance)
			if neighbours.size() > 4:
				neighbours.pop_back()
	var position := Vector3.ZERO
	var normal := Vector3.ZERO
	var total := 0.0
	for neighbour in neighbours:
		var weight: float = 1.0 / (float(neighbour.distance) + .00015)
		position += neighbour.point.position * weight
		normal += neighbour.point.normal * weight
		total += weight
	return {"position": position / total, "normal": normal.normalized()}

func _station(number: int, u: float) -> Dictionary:
	var sign_value := -1.0 if number % 2 == 0 else 1.0
	var tier := float(number / 2)
	var wave := sin(local_clock * float(settings.motion_rate) - u * TAU + float(number))
	var across: float
	var elevation: float
	var clearance: float
	var width: float
	if settings.style == "ascending":
		across = sign_value * half_width_cells * (.78 + .18 * sin(u * PI))
		elevation = height_cells * (.49 + u * .32 + tier * .035)
		clearance = .045 + .035 * sin(u * PI) + .009 * wave
		width = float(settings.width_cells) * pow(maxf(0.0, sin(u * PI)), .8)
	else:
		across = sign_value * (half_width_cells * .68 + u * .16)
		elevation = height_cells * (.74 - tier * .085) + .035 * sin(u * PI + local_clock * .7 + number)
		clearance = .04 + .065 * sin(u * PI) + .01 * wave
		width = float(settings.width_cells) * pow(maxf(0.0, sin(u * PI)), .65)
	var support := _support(across, elevation)
	var point: Vector3 = support.position + support.normal * clearance
	if settings.style == "ascending":
		point += side * sign_value * (.02 * sin(u * PI) + tier * .02)
	else:
		# An open, cambered lateral fan rather than a band enclosing the body.
		point += side * sign_value * u * .08
	if settings.mode == "remove":
		point += support.normal * .045 * smoothstep(0.0, float(settings.seconds), local_clock)
	return {"centre": point - origin, "normal": support.normal, "width": width, "camber": .028 * sin(u * PI)}

func _mesh(number: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var colour := Color.html(settings.colour).srgb_to_linear()
	var frame_age: float = fposmod(local_clock / float(settings.get("sheet_period_seconds", 1.8)) + float(number) * .19, 1.0)
	colour.a = frame_age if settings.get("sheet_animation", false) else float(settings.get("source_alpha", .7))
	var stations := []
	for row in 33:
		stations.append(_station(number, float(row) / 32.0))
	var across_axis := side if settings.style == "ascending" else Vector3.UP
	for row in 33:
		var u := float(row) / 32.0
		var station: Dictionary = stations[row]
		var tangent: Vector3 = (stations[mini(row + 1, 32)].centre - stations[maxi(row - 1, 0)].centre).normalized()
		for column in 5:
			var transverse := float(column) / 2.0 - 1.0
			var position: Vector3 = station.centre + across_axis * transverse * float(station.width)
			position += station.normal * (1.0 - transverse * transverse) * float(station.camber)
			var derivative: Vector3 = across_axis * float(station.width) - station.normal * 2.0 * transverse * float(station.camber)
			vertices.append(position)
			normals.append(derivative.cross(tangent).normalized())
			coordinates.append(Vector2(float(column) / 4.0, u))
			colours.append(colour)
			if row > 0 and column > 0:
				var start := (row - 1) * 5 + column - 1
				indices.append_array(PackedInt32Array([start, start + 1, start + 5, start + 1, start + 6, start + 5]))
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
		_hide()
		return
	for index in pieces.size():
		var number := index % int(settings.count)
		pieces[index].global_transform = Transform3D(Basis.IDENTITY, origin)
		pieces[index].mesh = _mesh(number)
		pieces[index].show()

func capture_observation() -> Dictionary:
	return {"support": {"style": settings.style, "mode": settings.mode, "clock": local_clock,
		"owner": surface.get("actor"), "envelope": envelope, "points": measured.size(),
		"origin": origin, "height_cells": height_cells, "half_width_cells": half_width_cells,
		"pieces": pieces.size(), "visible": not pieces.is_empty() and pieces[0].is_visible_in_tree(),
		"optical_lights": 0, "state_owner": "supplied condition UUID; no mechanics or autonomous hold expiry"}}

const VfxPackageIO_5441f2ac6b = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
