extends "res://assets/vfx/extensions/speed-completion-20261021/sources/746d81fc985c8abf0259/patches.gd"
## Optional numerical frame only: ordinary actual packet, no typed producer field.
## Covariance reduction order differs; original equality/raster flags stay raw.
const NativeRestore = preload("res://assets/vfx/extensions/input-reduction-20261021/sources/0b6e30d472c4c9c2d0b5/restore.gd")
const ORIGINAL_ADAPTER := "res://assets/vfx/extensions/speed-completion-20261021/sources/fae4c7db23bbb957ca04/patches.gd"


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_receiving_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var script: Script = VfxPackageIO_ed4d797836.resource("res://assets/vfx/extensions/speed-completion-20261021/sources/ed4d797836efe191ff94/patches.gd")
	return NativeRestore.restore(script.new(), input, ORIGINAL_ADAPTER)


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
	var first_column := Vector3.ZERO
	var second_column := Vector3.ZERO
	var third_column := Vector3.ZERO
	for index: int in points.size():
		var delta: Vector3 = measured_positions[index] - centre
		measured_deltas[index] = delta
		var projected: Vector3 = delta.slide(normal)
		first_column += projected * projected.x
		second_column += projected * projected.y
		third_column += projected * projected.z
	var covariance := Basis(first_column, second_column, third_column)
	for iteration: int in 12:
		var multiplied: Vector3 = covariance * axis
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


const VfxPackageIO_ed4d797836 = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
