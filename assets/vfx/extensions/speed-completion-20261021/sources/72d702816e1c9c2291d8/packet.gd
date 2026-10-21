extends RefCounted
## Existing exact optional optical view. Unknown views retain the legacy path.
const PointView = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/24740997d533fc6e3ec5/point_view.gd")
const Legacy = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/9fabdaca118c979b7899/packet.gd")


static func pack(source: Node3D) -> Dictionary:
	var view: Variant = source.surface.get(PointView.FIELD)
	if not view is RefCounted or view.get_script() != PointView or not view.matches(source.surface):
		return Legacy.pack(source)
	var actual_points: Array = source.surface.get("points", [])
	source.points = actual_points
	var count := actual_points.size()
	if count < 8:
		return {"valid": false}
	var positions: PackedVector3Array = view.positions
	var normals: PackedVector3Array = view.normals
	var centre := Vector3.ZERO
	var normal := Vector3.ZERO
	for index: int in count:
		centre += positions[index]
		normal += normals[index]
	centre /= float(count)
	normal = normal.normalized()
	source.centre = centre
	source.normal = normal
	if normal.is_zero_approx():
		return {"valid": false}
	var bytes := positions.to_byte_array()
	bytes.append_array(normals.to_byte_array())
	# Preserve the existing private native allocation/update contract (32N).
	# The typed decoder consumes only24N; trailing native zeros are not points.
	bytes.resize(count * 32)
	return {"valid": true, "count": count, "points": bytes, "typed": true,
		"centre": centre, "normal": normal,
		"axis": Vector3(.31, 1., .17).slide(normal).normalized()}
