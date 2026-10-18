extends "res://assets/vfx/sources/fe6a0d81ec5daed7ad4a/force_construction.gd"
## Original approved long projectile, corona, charge and impact, with live
## endpoints and a perpendicular cross section in every cast direction.
var endpoints: Array = []

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/ff65d5f8d1d289d3f69b/live_disintegrate.gd", input)

func set_live_endpoints(value: Array) -> void:
	endpoints = value

func advance_lifecycle(delta: float) -> void:
	if endpoints.size() >= 2:
		var inverse := subject.global_transform.affine_inverse()
		var target: Vector3 = inverse * endpoints[1].point
		var displacement: Vector3 = target - ray_end
		ray_start = inverse * endpoints[0].point
		ray_end = target
		charge.position = ray_start
		burst.position = ray_end
		for index in mote_origins.size():
			mote_origins[index] += displacement
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			var view: Vector3 = inverse.basis * camera.global_basis.z
			camera_sign = Vector2(view.x, view.z).normalized()
	super.advance_lifecycle(delta)

func ray_mesh(head: float = 0.0, width_scale: float = 1.0) -> ArrayMesh:
	var direction: Vector3 = (ray_end - ray_start).normalized()
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx():
		right = Vector3.RIGHT
	var up: Vector3 = right.cross(direction).normalized()
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var tail := maxf(0., head - .70)
	for angle in [0., PI / 3., PI * 2. / 3.]:
		var across: Vector3 = right * cos(angle) + up * sin(angle)
		var start := vertices.size()
		for index in 17:
			var phase := float(index) / 16.
			var along := lerpf(tail, head, phase)
			var width := .52 * width_scale * pow(phase, .65) * pow(maxf(0., 1. - phase), .25) * minf(1., head / .14)
			var centre: Vector3 = ray_start.lerp(ray_end, along)
			vertices.append_array(PackedVector3Array([centre - across * width, centre + across * width]))
			uv.append_array(PackedVector2Array([Vector2(phase, 0), Vector2(phase, 1)]))
		for index in 16:
			var offset := start + index * 2
			indices.append_array(PackedInt32Array([offset, offset + 1, offset + 2, offset + 1, offset + 3, offset + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func capture_observation() -> Dictionary:
	return {"source_world": _coordinates(subject.to_global(ray_start)),
		"target_world": _coordinates(subject.to_global(ray_end)), "native_tick": tick,
		"projectile_visible": beam.visible}

func _coordinates(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
