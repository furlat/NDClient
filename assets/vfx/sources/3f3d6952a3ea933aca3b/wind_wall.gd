extends Node3D
## Shared exact native Wind Wall sheet. Current authored path creates instances
## of ONE grid; vertices/miters/arc UVs execute in the prepared source shader.
const CELL := 2.121320344
const HEIGHT := 6.363961032
var bank: Resource
var parameters: Dictionary = {}
var settings: Dictionary = {}
var mats: Array[ShaderMaterial] = []
var hit_mats: Array[ShaderMaterial] = []
var flow_draws: Array[MeshInstance3D] = []
var hit_meshes: Array[MeshInstance3D] = []
var debris: Array[MeshInstance3D] = []
var debris_roots: Array[Vector3] = []
var feed_mat: StandardMaterial3D
var modules: Array = []
var geometry: Array = []
var tick := 0
var last_tick := -1
var camera_ground := Vector2(1, 1).normalized()
var foreground := false
var split_layers := false
var actor_ground := Vector2(100, 100)
var previous_source_transform := Transform3D.IDENTITY
var source_transform_known := false
var source_materials: Array[ShaderMaterial] = []

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.wind_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource = VfxPackageIO_3f3d6952a3.resource(str(input.wind_bank))
	assert(prepared != null and prepared.flow_materials.size() == 3 and prepared.hit_materials.size() == 2,
		"Native Wind Wall bank must be prepared offline")
	# Existing authoring path_points stay parametric. All other prepared source
	# choices (noise, side, seed, clocks) must match, not silently become defaults.
	var expected: Dictionary = prepared.source_parameters.duplicate(true)
	var actual: Dictionary = input.duplicate(true)
	actual.erase("wind_bank")
	expected.settings.erase("path_points")
	actual.settings.erase("path_points")
	assert(actual == expected, "Wind source material/clock variant needs explicit preparation")
	var node: Node3D = VfxPackageIO_3f3d6952a3.resource("res://assets/vfx/sources/3f3d6952a3ea933aca3b/wind_wall.gd").new()
	node.bank = prepared
	node.parameters = input.duplicate(true)
	node.settings = input.settings.duplicate(true)
	node.camera_ground = Vector2(input.clip_ground[0], input.clip_ground[1]).normalized()
	node._build()
	return node

func _draw(mesh: Mesh, material: Material, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	geometry.append(node)
	return node

func _build() -> void:
	for source: ShaderMaterial in bank.flow_materials:
		var material: ShaderMaterial = source.duplicate(false)
		material.set_shader_parameter("camera_ground", camera_ground)
		material.set_shader_parameter("foreground", foreground)
		mats.append(material)
		source_materials.append(material)
	for source: ShaderMaterial in bank.hit_materials:
		var material: ShaderMaterial = source.duplicate(false)
		material.set_shader_parameter("camera_ground", camera_ground)
		material.set_shader_parameter("foreground", foreground)
		hit_mats.append(material)
		source_materials.append(material)
	feed_mat = bank.feed_material.duplicate(false)
	var paths: Array = stations(settings.path_points)
	var vertices: Array = paths[0]
	var arcs: Array = paths[1]
	var normals: Array = paths[2]
	var distance: float = paths[3]
	for index in 12:
		debris.append(_draw(bank.debris_mesh, feed_mat, "WindDebris%02d" % index))
		var slot := (index * 7) % maxi(1, vertices.size() - 1)
		debris_roots.append(vertices[slot].lerp(vertices[slot + 1], fmod(float(index) * .618, 1.0)))
	for index in vertices.size() - 1:
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var na: Vector3 = normals[index]
		var nb: Vector3 = normals[index + 1]
		for layer in 3:
			var draw := _draw(bank.grid, mats[layer], "WindModule_%02d_layer%d" % [index, layer])
			draw.set_instance_shader_parameter("wind_segment_start", Vector4(a.x, a.y, a.z, arcs[index]))
			draw.set_instance_shader_parameter("wind_segment_end", Vector4(b.x, b.y, b.z, arcs[index + 1]))
			draw.set_instance_shader_parameter("wind_segment_normal_start", Vector4(na.x, na.y, na.z, distance))
			draw.set_instance_shader_parameter("wind_segment_normal_end", Vector4(nb.x, nb.y, nb.z, float(index % 3)))
			# Native vertex motion includes .045+.018 displacement and source
			# body-clearance warp. Culling bound encloses the mitered source.
			var minimum := Vector3(minf(a.x, b.x), 0., minf(a.z, b.z)) - Vector3(1.3, .8, 1.3)
			var maximum := Vector3(maxf(a.x, b.x), HEIGHT, maxf(a.z, b.z)) + Vector3(1.3, .8, 1.3)
			draw.custom_aabb = AABB(minimum, maximum - minimum)
			flow_draws.append(draw)
			modules.append({"index": index, "start": a, "end": b, "normal_start": na,
				"normal_end": nb, "arc_start": arcs[index], "arc_end": arcs[index + 1],
				"total": distance, "layer": layer, "variant": index % 3})
	for index in 2:
		var draw := _draw(bank.hit_mesh, hit_mats[index], "WindFormationHit%d" % index)
		draw.custom_aabb = bank.hit_mesh.get_aabb().grow(.1)
		hit_meshes.append(draw)

static func stations(path: Array) -> Array:
	assert(path.size() >= 2, "Actual native Wind Wall path needs at least two points")
	var points: Array[Vector3] = []
	for point in path:
		assert(point.size() == 2 and is_finite(float(point[0])) and is_finite(float(point[1])), "Actual finite path point required")
		points.append(Vector3(point[0] * CELL, 0., point[1] * CELL))
	var distance := 0.0
	var vertices: Array[Vector3] = []
	var arcs: Array[float] = []
	for segment in points.size() - 1:
		var length := points[segment].distance_to(points[segment + 1])
		assert(length > 0.000001, "Repeated zero-length source path point is unsupported")
		var steps := int(ceil(length / CELL))
		for index in steps:
			vertices.append(points[segment].lerp(points[segment + 1], float(index) / steps))
			arcs.append(distance + length * float(index) / steps)
		distance += length
	vertices.append(points[-1])
	arcs.append(distance)
	var closed := points[0].is_equal_approx(points[-1])
	var normals: Array[Vector3] = []
	for index in vertices.size():
		var previous := vertices[index] - vertices[maxi(0, index - 1)]
		var next := vertices[mini(vertices.size() - 1, index + 1)] - vertices[index]
		if closed and index == 0:
			previous = vertices[-1] - vertices[-2]
		if closed and index == vertices.size() - 1:
			next = vertices[1] - vertices[0]
		if previous.length() < .01:
			previous = next
		if next.length() < .01:
			next = previous
		var n0 := Vector3(-previous.z, 0., previous.x).normalized()
		var n1 := Vector3(-next.z, 0., next.x).normalized()
		var bisector := (n0 + n1).normalized()
		normals.append(bisector / maxf(.5, bisector.dot(n1)))
	return [vertices, arcs, normals, distance]

func _visual_state(age: float) -> void:
	var retire := smoothstep(4., 5., age)
	var fade := 1.0 - clampf(retire, 0., 1.)
	var pulse := exp(-pow((age - .70) / .13, 2.0))
	var hit_phase := clampf((age - .48) / .65, 0., 1.)
	for index in 2:
		hit_meshes[index].position = Vector3(0., 1.0 + float(index) * .35, 0.)
		hit_meshes[index].scale = Vector3.ONE * lerpf(.18, .48, hit_phase)
		hit_meshes[index].rotation = Vector3(.12 * float(index), float(index) * 1.9 + hit_phase * .18, 0.)
		hit_mats[index].set_shader_parameter("phase", hit_phase)
		hit_mats[index].set_shader_parameter("envelope", smoothstep(0., .10, hit_phase) * (1.0 - smoothstep(.55, 1.0, hit_phase)))
		hit_mats[index].set_shader_parameter("actor_ground", actor_ground)
	feed_mat.albedo_color = Color(.66, .68, .61, .6 * smoothstep(0., .35, age) * fade)
	for index in 12:
		var phase := fmod(age * .5 + float(index) / 12.0, 1.0)
		debris[index].position = debris_roots[index] + Vector3(.08 * sin(phase * 6.283 + float(index)), HEIGHT * phase, .07 * cos(phase * 6.283 + float(index)))
		debris[index].visible = (camera_ground.dot(Vector2(debris[index].position.x, debris[index].position.z) - actor_ground) > 0.) == foreground
		debris[index].rotation = Vector3(phase * 5., phase * 9. + float(index), phase * 6.)
		debris[index].scale = Vector3.ONE * smoothstep(0., .08, phase) * (1.0 - smoothstep(.75, 1., phase)) * smoothstep(0., .3, age)
	for material in mats:
		material.set_shader_parameter("split_layers", split_layers)
		material.set_shader_parameter("actor_ground", actor_ground)
		material.set_shader_parameter("formation_pulse", pulse)
		material.set_shader_parameter("wind_clock", fmod(age, 2.0))
		material.set_shader_parameter("reveal", lerpf(0., 1.12, smoothstep(0., .75, age)))
		material.set_shader_parameter("wall_opacity", fade * .36)

func sample(seconds: float) -> void:
	if not is_finite(seconds):
		return
	var desired := int(round(seconds * float(parameters.simulation_hz)))
	if desired != last_tick:
		tick = desired
		# Source tick zero has not yet run its lifecycle callback. Keep its
		# actual prepared initial defaults instead of inventing prebirth state.
		if desired > 0:
			_visual_state(float(desired) / float(parameters.simulation_hz))
		elif last_tick > 0:
			_reset_initial_state()
		last_tick = desired
	if not source_transform_known or previous_source_transform != global_transform:
		previous_source_transform = global_transform
		source_transform_known = true
		var inverse := Projection(global_transform.affine_inverse())
		for material in source_materials:
			material.set_shader_parameter("factory_world_to_source", inverse)

func _reset_initial_state() -> void:
	for material in mats:
		material.set_shader_parameter("wind_clock", 0.)
		material.set_shader_parameter("reveal", 0.)
		material.set_shader_parameter("wall_opacity", 1.)
		material.set_shader_parameter("actor_ground", Vector2.ZERO)
		material.set_shader_parameter("formation_pulse", 0.)
	for material in hit_mats:
		material.set_shader_parameter("phase", 0.)
		material.set_shader_parameter("envelope", 0.)
		material.set_shader_parameter("actor_ground", Vector2.ZERO)
	feed_mat.albedo_color = bank.feed_material.albedo_color
	for node in debris + hit_meshes:
		node.transform = Transform3D.IDENTITY
		node.show()

func source_bindings() -> Dictionary:
	return {"geometry": geometry, "materials": source_materials, "static_material_topology": true}

func capture_observation() -> Dictionary:
	return {"native_tick": tick, "flow_draws": flow_draws.size(), "native_layers_per_module": 3,
		"formation_hits": hit_meshes.size(), "debris": debris.size(), "private_flow_materials": mats.size(),
		"shared_grid": true, "runtime_shader_generation": false, "per_frame_cpu_vertices": false,
		"authoring_path_points": settings.path_points, "human_approval_inferred": false}

const VfxPackageIO_3f3d6952a3 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
