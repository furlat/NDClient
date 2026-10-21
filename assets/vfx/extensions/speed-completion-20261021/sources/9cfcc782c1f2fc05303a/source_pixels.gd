extends RefCounted
## Optional CPU source reader for the actual RGBA8/L8 source images only.
## Local arrays are appended with the original point, never reconstructed later.
const Original = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/350385c4a3fd221f0165/source_points.gd")
var channels := PackedFloat32Array()


func admitted(images: Dictionary) -> bool:
	for field: String in ["colour", "depth", "normal"]:
		if images[field].get_format() != Image.FORMAT_RGBA8 or images[field].is_compressed():
			return false
	for field: String in ["support", "normal_valid"]:
		if images[field].get_format() != Image.FORMAT_L8 or images[field].is_compressed():
			return false
	return true


func original(images: Dictionary, frame: Vector4, units: float, elevation: float,
		origin: Vector2, depth_range: Vector2, pivot: Vector2, ground: float,
		camera_basis: Basis) -> Dictionary:
	var points := Original.measure(images, frame, units, elevation, origin,
		depth_range, pivot, ground, camera_basis)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	for point: Dictionary in points:
		positions.append(point.local)
		normals.append(point.normal)
	return {"points": points, "positions": positions, "normals": normals, "native_channels": false}


func measure(images: Dictionary, frame: Vector4, units: float, elevation: float,
		origin: Vector2, depth_range: Vector2, pivot: Vector2, ground: float,
		camera_basis: Basis) -> Dictionary:
	if not admitted(images):
		return original(images, frame, units, elevation, origin, depth_range, pivot, ground, camera_basis)
	if channels.is_empty():
		for value: int in 256:
			channels.append(float(value) / 255.0)
	var result: Array = []
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colour: Image = images.colour
	var colour_width := colour.get_width()
	var depth_width: int = images.depth.get_width()
	var normal_width: int = images.normal.get_width()
	var support_width: int = images.support.get_width()
	var valid_width: int = images.normal_valid.get_width()
	var values: PackedFloat32Array = channels
	var colour_values: PackedByteArray = colour.get_data()
	var depth_values: PackedByteArray = images.depth.get_data()
	var normal_values: PackedByteArray = images.normal.get_data()
	var support_values: PackedByteArray = images.support.get_data()
	var valid_values: PackedByteArray = images.normal_valid.get_data()
	var offset := Vector2i(roundi(frame.x * colour.get_width()), roundi(frame.y * colour.get_height()))
	var size := Vector2i(roundi(frame.z * colour.get_width()), roundi(frame.w * colour.get_height()))
	var region := Rect2i(offset, size)
	for image: Image in images.values():
		if size.x <= 0 or size.y <= 0 or not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region):
			return original(images, frame, units, elevation, origin, depth_range, pivot, ground, camera_basis)
	# The original accepts alpha>=.99; every such texel lies in this exact
	# nonzero-alpha rectangle. Frame-local coordinates and row order stay live.
	var occupied := colour.get_region(region).get_used_rect()
	var toward: Vector3 = camera_basis.z
	var horizontal := Vector3(toward.x, 0, toward.z).normalized()
	var normal_basis := camera_basis.inverse() * Basis(camera_basis.x,
		Vector3(0, cos(elevation), 0) - horizontal * sin(elevation),
		horizontal * cos(elevation) + Vector3(0, sin(elevation), 0))
	for y: int in range(occupied.position.y, occupied.end.y):
		for x: int in range(occupied.position.x, occupied.end.x):
			var pixel := Vector2i(x, y)
			var sheet_pixel := pixel + offset
			var colour_index := (sheet_pixel.y * colour_width + sheet_pixel.x) * 4
			if values[colour_values[colour_index + 3]] < .99:
				continue
			var depth_index := (sheet_pixel.y * depth_width + sheet_pixel.x) * 4
			var normal_index := (sheet_pixel.y * normal_width + sheet_pixel.x) * 4
			if values[depth_values[depth_index + 3]] < .5 or values[normal_values[normal_index + 3]] < .5 \
					or values[support_values[sheet_pixel.y * support_width + sheet_pixel.x]] < .5 \
					or values[valid_values[sheet_pixel.y * valid_width + sheet_pixel.x]] < .5:
				continue
			var centre := Vector2(x + .5, y + .5)
			var decoded: float = depth_range.x + (values[depth_values[depth_index]] * 255.0 - 32.0) * (depth_range.y - depth_range.x) / 192.0
			var height: float = ((origin.y - centre.y) * cos(elevation) + decoded * sin(elevation) - ground) * units
			var painted := Vector3(centre.x - pivot.x, pivot.y - centre.y, 0) * units
			var ray: float = (height - (camera_basis * painted).y) / toward.y
			var direction := Vector3(values[normal_values[normal_index]],
				values[normal_values[normal_index + 1]], values[normal_values[normal_index + 2]]) * 2.0 - Vector3.ONE
			var position := painted + Vector3(0, 0, ray)
			var normal := (normal_basis * direction.normalized()).normalized()
			result.append({"local": position, "normal": normal, "uv": centre / Vector2(size), "pixel": pixel})
			positions.append(position)
			normals.append(normal)
	return {"points": result, "positions": positions, "normals": normals, "native_channels": true}
