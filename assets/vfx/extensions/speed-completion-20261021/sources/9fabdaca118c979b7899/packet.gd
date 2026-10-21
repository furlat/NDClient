extends RefCounted
## Actual public point packet only. Ordered centre/normal stay on the CPU so
## transparent GeometryInstance transforms retain their original sort origin.


static func pack(source: Node3D) -> Dictionary:
	var actual_points: Array = source.surface.get("points", [])
	source.points = actual_points
	var count: int = actual_points.size()
	if count < 8:
		return {"valid": false}
	var values := PackedVector4Array()
	values.resize(count * 2)
	var centre := Vector3.ZERO
	var normal := Vector3.ZERO
	for index: int in count:
		var point: Dictionary = actual_points[index]
		var position: Vector3 = point.position
		var received_normal: Vector3 = point.normal
		centre += position
		normal += received_normal
		values[index] = Vector4(position.x, position.y, position.z, 1.)
		values[count + index] = Vector4(received_normal.x, received_normal.y, received_normal.z, 1.)
	centre /= float(count)
	normal = normal.normalized()
	source.centre = centre
	source.normal = normal
	if normal.is_zero_approx():
		return {"valid": false}
	return {"valid": true, "count": count, "points": values.to_byte_array(),
		"centre": centre, "normal": normal,
		"axis": Vector3(.31, 1., .17).slide(normal).normalized()}


static func constants(packet: Dictionary, endpoints: Array, orientation_only: bool = false) -> PackedByteArray:
	var has_endpoints := endpoints.size() >= 2
	var bearing := Vector3.UP
	if has_endpoints:
		bearing = (endpoints[1].point - endpoints[0].point).normalized()
	var result := PackedInt32Array([int(packet.count), 1 if orientation_only else 0,
		1 if has_endpoints else 0, 0]).to_byte_array()
	for value: Vector3 in [packet.centre, packet.normal, packet.axis, bearing]:
		result.append_array(PackedFloat32Array([value.x, value.y, value.z, 0.]).to_byte_array())
	return result
