extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/fae4c7db23bbb957ca04/patches.gd"
## Same receiving frame/support shader. Only pure per-pose CPU operands are
## retained in typed arrays, preserving the original ordered native sums.
const BulkRestore = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/e7f3db6ad538ef3f298c/restore.gd")
var measured_positions := PackedVector3Array()
var measured_normals := PackedVector3Array()
var measured_deltas := PackedVector3Array()


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_receiving_bank)]


static func make_component(input: Dictionary) -> Node3D:
	return BulkRestore.make("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/746d81fc985c8abf0259/patches.gd",
		"res://assets/vfx/extensions/cloud-body-speed-20261021/sources/fae4c7db23bbb957ca04/patches.gd", input)


func _measure() -> bool:
	points = surface.get("points", [])
	if points.size() < 8:
		return false
	centre = Vector3.ZERO
	normal = Vector3.ZERO
	measured_positions.resize(points.size())
	measured_normals.resize(points.size())
	for index in points.size():
		var position: Vector3 = points[index].position
		var receiving_normal: Vector3 = points[index].normal
		measured_positions[index] = position
		measured_normals[index] = receiving_normal
		centre += position
		normal += receiving_normal
	centre /= float(points.size())
	normal = normal.normalized()
	if normal.is_zero_approx():
		return false
	var axis := Vector3(.31, 1.0, .17).slide(normal).normalized()
	measured_deltas.resize(points.size())
	var projected := PackedVector3Array()
	projected.resize(points.size())
	for index in points.size():
		var delta: Vector3 = measured_positions[index] - centre
		measured_deltas[index] = delta
		projected[index] = delta.slide(normal)
	for iteration in 12:
		var multiplied := Vector3.ZERO
		for delta: Vector3 in projected:
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
	# Radius and image use the original unprojected deltas; substituting the
	# covariance projection here would change native rounding and body shape.
	for delta: Vector3 in measured_deltas:
		long_radius = maxf(long_radius, absf(delta.dot(principal)))
		cross_radius = maxf(cross_radius, absf(delta.dot(transverse)))
	return true


func _refresh_body() -> bool:
	if surface.get("points", []).size() < 8:
		return false
	var key: Array = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	var origin: Vector3 = surface.get("origin", Vector3.ZERO)
	if key.is_empty() or geometry_key != key or body_texture == null:
		if not _measure():
			return false
		geometry_key = key.duplicate(true)
		relative_centre = centre - origin
		var values := PackedVector4Array()
		values.resize(points.size() * 2)
		for index in points.size():
			var point: Vector3 = measured_deltas[index]
			var receiving_normal: Vector3 = measured_normals[index]
			values[index] = Vector4(point.x, point.y, point.z, 1.)
			values[points.size() + index] = Vector4(receiving_normal.x, receiving_normal.y, receiving_normal.z, 1.)
		var image := Image.create_from_data(points.size(), 2, false, Image.FORMAT_RGBAF, values.to_byte_array())
		if body_texture != null and body_texture.get_size() == Vector2(image.get_size()):
			body_texture.update(image)
		else:
			body_texture = ImageTexture.create_from_image(image)
		geometry_uploads += 1
		for material: ShaderMaterial in materials:
			material.set_shader_parameter("gpu_body_points", body_texture)
			material.set_shader_parameter("gpu_body_count", points.size())
			material.set_shader_parameter("gpu_body_up", principal)
			material.set_shader_parameter("gpu_body_side", transverse)
			material.set_shader_parameter("gpu_body_radii", Vector2(long_radius, cross_radius))
	else:
		centre = origin + relative_centre
	var bearing := Vector3.UP
	if absf(principal.y) < .3 and endpoints.size() >= 2:
		bearing = (endpoints[1].point - endpoints[0].point).normalized()
	if principal.dot(bearing) < 0.:
		principal = -principal
		transverse = -transverse
		for material: ShaderMaterial in materials:
			material.set_shader_parameter("gpu_body_up", principal)
			material.set_shader_parameter("gpu_body_side", transverse)
	return true
