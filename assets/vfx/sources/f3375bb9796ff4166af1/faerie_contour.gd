extends Node3D
## Actual received Faerie Fire membership. Only its disclosed dim-light owner
## emits light; the articulated outline follows source alpha/depth/normals.
const Boundary = preload("res://assets/vfx/sources/2a27d065b490c7cfdfe2/pixel_boundary.gd")

var specification: Dictionary = {}
var receiving_geometry: Dictionary = {}
var topology: Array = []
var topology_key: Array = []
var draws: Array[MeshInstance3D] = []
var material: ShaderMaterial
var optical_light: OmniLight3D
var membership_present := true
var current_seconds := 0.0
var envelope := 0.0
var fitted_key: Array=[]
var fitted_origin:=Vector3.ZERO
var fitted_root:=Vector3.ZERO
var geometry_builds:=0

static func make_component(input: Dictionary) -> Node3D:
	var effect: Node3D = VfxPackageIO_f3375bb979.resource("res://assets/vfx/sources/f3375bb9796ff4166af1/faerie_contour.gd").new()
	effect.specification = input.duplicate(true)
	effect.prepare()
	return effect

func set_entity_geometry(value: Dictionary) -> void:
	receiving_geometry = value

func set_membership_present(value: bool) -> void:
	membership_present = value

func prepare() -> void:
	material = ShaderMaterial.new()
	material.shader = VfxPackageIO_f3375bb979.resource("res://assets/vfx/sources/8c3a2317a76384635dbc/faerie_flow.gdshader")
	material.set_shader_parameter("native_wind_mask", VfxPackageIO_f3375bb979.resource(specification.wind_mask))
	material.set_shader_parameter("native_flow_mask", VfxPackageIO_f3375bb979.resource(specification.flow_mask))
	material.set_shader_parameter("deep_colour", Color(specification.colours[0]))
	material.set_shader_parameter("flow_colour", Color(specification.colours[1]))
	material.set_shader_parameter("crest_colour", Color(specification.colours[2]))
	optical_light = OmniLight3D.new()
	optical_light.name = "ObservedRevealDimLight"
	optical_light.omni_range = float(specification.dim_range_cells)
	optical_light.light_energy = 0.0
	optical_light.light_color = Color(specification.colours[1])
	optical_light.set_meta("factory_light_role", "optical")
	add_child(optical_light)
	# Material/geometry owners exist when the shared native sampler registers
	# clocks and opacity. Empty meshes carry no pixels before geometry arrives.
	var draw := MeshInstance3D.new()
	draw.name = "ArticulatedFeyOutline0"
	draw.material_override = material
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
	draws.append(draw)

func sample(seconds: float) -> void:
	if material == null:
		prepare()
	current_seconds = seconds
	var points: Array = receiving_geometry.get("points", [])
	envelope = smoothstep(0.0, .22, seconds) if membership_present and not points.is_empty() else 0.0
	material.set_shader_parameter("local_clock_seconds", seconds)
	material.set_shader_parameter("presence_alpha", envelope)
	optical_light.light_energy = float(specification.get("dim_energy", .12)) * envelope
	for draw in draws:
		draw.visible = envelope > 0.0
	if envelope <= 0.0:
		return
	var pose: Array=preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(receiving_geometry)
	var fit: Array=[pose,global_basis]
	if not pose.is_empty() and fit==fitted_key:
		var delta: Vector3=global_basis.inverse()*(receiving_geometry.origin-fitted_origin-(global_position-fitted_root))
		for draw in draws:
			draw.position=delta
		optical_light.position=global_transform.affine_inverse()*receiving_geometry.origin+Vector3.UP*.42
		return
	fitted_key=fit
	fitted_origin=receiving_geometry.origin
	fitted_root=global_position
	geometry_builds+=1
	for draw in draws:draw.position=Vector3.ZERO
	var key: Array = points.map(func(point: Dictionary) -> Vector2i: return point.pixel)
	if key != topology_key:
		topology_key = key
		topology = Boundary.chains(points)
		while draws.size() < topology.size():
			var draw := MeshInstance3D.new()
			draw.name = "ArticulatedFeyOutline" + str(draws.size())
			draw.material_override = material
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(draw)
			draws.append(draw)
	var receiving_frame := Boundary.frame(points)
	for index in draws.size():
		draws[index].visible = index < topology.size()
		if index < topology.size():
			draws[index].mesh = _mesh(topology[index], receiving_frame)
	optical_light.position = global_transform.affine_inverse() * receiving_geometry.origin + Vector3.UP * .42

func _mesh(chain: Array, receiving_frame: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var coordinates := PackedVector2Array()
	var indices := PackedInt32Array()
	var inverse := global_transform.affine_inverse()
	var inverse_basis := global_basis.inverse()
	var path: Array = chain.map(func(key: Vector2i) -> Dictionary: return Boundary.corner(key, receiving_frame))
	var arc_length := 0.0
	for index in path.size():
		var point: Dictionary = path[index]
		if index > 0:
			arc_length += path[index - 1].position.distance_to(point.position)
		var tangent: Vector3 = (path[mini(index + 1, path.size() - 1)].position - path[maxi(index - 1, 0)].position).normalized()
		var normal: Vector3 = point.normal
		var side := tangent.cross(normal).normalized()
		if side.is_zero_approx():
			side = receiving_frame.right.normalized()
		for edge in [-1.0, 1.0]:
			vertices.append(inverse * (point.position + normal * .014 + side * float(specification.width_cells) * edge))
			normals.append((inverse_basis * normal).normalized())
			coordinates.append(Vector2((edge + 1.0) * .5, arc_length * 2.8))
		if index > 0:
			var start := (index - 1) * 2
			indices.append_array(PackedInt32Array([start, start + 1, start + 2, start + 1, start + 3, start + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = coordinates
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func capture_observation() -> Dictionary:
	return {"body_points": receiving_geometry.get("points", []).size(), "source_boundary_chains": topology.size(),
		"local_seconds": current_seconds, "membership_present": membership_present, "envelope": envelope,
		"cue_opacity": material.get_shader_parameter("cue_opacity") if material != null else null,
		"material_seconds": material.get_shader_parameter("local_clock_seconds") if material != null else null,
		"light_owner": specification.light_owner_uuid, "dim_range_cells": specification.dim_range_cells,
		"original_invisibility_removed": false, "area_enter_damage": false}

const VfxPackageIO_f3375bb979 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
