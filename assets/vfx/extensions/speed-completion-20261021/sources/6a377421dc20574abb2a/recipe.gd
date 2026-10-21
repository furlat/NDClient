extends Resource
## Immutable source pixels only. No world transform, owner, clock or body pose.
@export var descriptor: Dictionary = {}
@export var frame_uv := Vector4.ZERO
@export var region := Rect2i()
@export var image_witnesses: Array[Dictionary] = []
@export var pixels: Array[Vector2i] = []
@export var centres := PackedVector2Array()
@export var uvs := PackedVector2Array()
@export var depth_red := PackedFloat32Array()
@export var raw_normals := PackedVector3Array()


func valid() -> bool:
	var count := pixels.size()
	return region.has_area() and image_witnesses.size() == 5 \
		and centres.size() == count and uvs.size() == count \
		and depth_red.size() == count and raw_normals.size() == count


func project(units: float, elevation: float, origin: Vector2,
		depth_range: Vector2, pivot: Vector2, ground: float,
		camera_basis: Basis) -> Dictionary:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	positions.resize(pixels.size())
	normals.resize(pixels.size())
	var toward: Vector3 = camera_basis.z
	var horizontal := Vector3(toward.x, 0, toward.z).normalized()
	var normal_basis := camera_basis.inverse() * Basis(camera_basis.x,
		Vector3(0, cos(elevation), 0) - horizontal * sin(elevation),
		horizontal * cos(elevation) + Vector3(0, sin(elevation), 0))
	# Keep the original scalar grouping and native Vector arithmetic order.
	for ordinal: int in pixels.size():
		var centre: Vector2 = centres[ordinal]
		var decoded: float = depth_range.x + (depth_red[ordinal] * 255.0 - 32.0) * (depth_range.y - depth_range.x) / 192.0
		var height: float = ((origin.y - centre.y) * cos(elevation) + decoded * sin(elevation) - ground) * units
		var painted := Vector3(centre.x - pivot.x, pivot.y - centre.y, 0) * units
		var ray: float = (height - (camera_basis * painted).y) / toward.y
		positions[ordinal] = painted + Vector3(0, 0, ray)
		normals[ordinal] = (normal_basis * raw_normals[ordinal]).normalized()
	return {"positions": positions, "normals": normals, "pixels": pixels, "uvs": uvs}
