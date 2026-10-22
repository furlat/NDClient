extends RefCounted
## One actual Dragon receiver. Cold selection uses current EntitySurface local
## rows; sampling transforms only those rows using the original surface math.
var current: Dictionary = {}


func clear() -> void:
	current.clear()


func prepare(captured: Dictionary, sources: Dictionary, authored: Dictionary,
		bank_key: String, frame: int, layout: String) -> Dictionary:
	var bound: Dictionary = _binding(captured, sources, authored, bank_key, frame, layout)
	if not bound.ready:
		clear()
		return bound
	if _same(bound, authored, bank_key, frame, layout):
		return {"ready": true, "reason": "", "selected_points": current.indices.size()}
	var offset: Array = bound.registration.pixel_to_canonical_offset
	var indices: Array[int] = []
	var retained: Array[Dictionary] = []
	for pixel: Array in bound.pose.pixels:
		var target := Vector2i(int(pixel[0]) - int(offset[0]), int(pixel[1]) - int(offset[1]))
		var index: int = _raster_index(bound.points, target)
		if index >= 0 and not indices.has(index):
			indices.append(index)
	indices.sort()
	for index: int in indices:
		retained.append(bound.points[index])
	current = {"source_key": bound.source_key, "points": bound.points,
		"authored": authored, "pose": bound.pose, "registration": bound.registration,
		"entry": bound.entry, "key": bank_key, "frame": frame, "layout": layout,
		"indices": indices, "retained": retained}
	return {"ready": true, "reason": "", "selected_points": indices.size()}


static func _raster_index(points: Array, target: Vector2i) -> int:
	# Exact current EntitySurface.measure emits admitted pixels in y/x order.
	# Search only sparse authored pixels; do not rescan the whole body per pose.
	var low: int = 0
	var high: int = points.size()
	while low < high:
		var middle: int = (low + high) / 2
		var pixel: Vector2i = points[middle].pixel
		if pixel.y < target.y or pixel.y == target.y and pixel.x < target.x:
			low = middle + 1
		else:
			high = middle
	return low if low < points.size() and points[low].pixel == target else -1


func select(captured: Dictionary, sources: Dictionary, authored: Dictionary,
		bank_key: String, frame: int, layout: String, actor: String) -> Dictionary:
	var result: Dictionary = {"actor": actor, "actor_uuid": actor, "entity_uuid": actor,
		"points": [], "origin": captured.get("origin", Vector3.ZERO),
		"pose_key": captured.get("pose_key", []), "gpu_geometry_key": [],
		"ready": false, "pending": false, "reason": ""}
	var bound: Dictionary = _binding(captured, sources, authored, bank_key, frame, layout)
	if not bound.ready:
		clear()
		result.reason = bound.reason
		result.pending = captured.get("pending", false)
		return result
	if not _same(bound, authored, bank_key, frame, layout):
		clear()
		result.reason = "mouth_surface_selection_not_prepared"
		result.pending = true
		return result
	var transform: Transform3D = bound.entry.node.global_transform
	var normal_basis: Basis = transform.basis.inverse().transposed()
	var centre := Vector3.ZERO
	for selected in current.indices.size():
		var index: int = current.indices[selected]
		if index >= bound.points.size() or not is_same(bound.points[index], current.retained[selected]):
			clear()
			result.reason = "mouth_source_point_order_changed"
			return result
		var point: Dictionary = bound.points[index]
		var position: Vector3 = transform * point.local
		result.points.append({"position": position, "normal": (normal_basis * point.normal).normalized(),
			"uv": point.uv, "pixel": point.pixel, "slot": "body"})
		centre += position
	result.ready = not result.points.is_empty()
	result.reason = "" if result.ready else "no_current_admitted_mouth_pixels"
	if result.ready:
		result.optical_anchor = centre / float(result.points.size())
		result.geometry_slots = ["body"]
		result.region_id = "mouth"
		result.region_revision = [captured.get("revision", []), captured.get("origin", Vector3.ZERO), authored.get("revision", ""), bank_key, frame, layout]
		result.gpu_geometry_key = result.region_revision
	return result


func _same(bound: Dictionary, authored: Dictionary, bank_key: String, frame: int, layout: String) -> bool:
	return not current.is_empty() and current.key == bank_key and current.frame == frame and current.layout == layout \
		and current.source_key == bound.source_key and is_same(current.points, bound.points) \
		and is_same(current.entry, bound.entry) and is_same(current.authored, authored) \
		and is_same(current.pose, bound.pose) and is_same(current.registration, bound.registration)


static func _binding(captured: Dictionary, sources: Dictionary, authored: Dictionary,
		bank_key: String, frame: int, layout: String) -> Dictionary:
	if not str(captured.get("reason", "actor_not_displayed")).is_empty():
		return {"ready": false, "reason": str(captured.get("reason", "actor_not_displayed"))}
	var selected: Array = captured.get("selected", [])
	# Exact selected Dragon body only. Do not reveal a lower layer through a
	# rejected painter owner or claim a general multi-layer region algorithm.
	if selected.size() != 1 or str(selected[0].get("slot", "")) != "body":
		return {"ready": false, "reason": "mouth_requires_exact_dragon_body_owner"}
	var description: Dictionary = selected[0]
	var entry: Dictionary = description.entry
	if not is_instance_valid(entry.get("node")) or not entry.node.is_visible_in_tree():
		return {"ready": false, "reason": "actor_not_displayed"}
	var bank: Dictionary = authored.get("banks", {}).get(bank_key, {})
	var poses: Array = bank.get("frames", [])
	if frame < 0 or frame >= poses.size():
		return {"ready": false, "reason": "authentic_mouth_pose_not_authored"}
	var pose: Dictionary = poses[frame]
	if int(pose.get("frame", -1)) != frame or pose.get("status") != "visible_lip":
		return {"ready": false, "reason": str(pose.get("reason", "authentic_mouth_pose_not_authored"))}
	var registration: Dictionary = bank.get("layouts", {}).get(layout, {})
	if registration.is_empty():
		return {"ready": false, "reason": "mouth_source_layout_not_bound"}
	var source_key: Array = description.key
	var source: String = str(registration.get("source_path", ""))
	var rect: Array = registration.frame_uvs[frame]
	var expected := Vector4(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	# Current EntitySurface._source_key: path, profile, five actual Image IDs,
	# then the native pose whose first field is frame_uv.
	if source_key.size() != 8 or str(source_key[0]) != source or not source_key[7] is Array \
			or source_key[7].is_empty() or source_key[7][0] != expected:
		return {"ready": false, "reason": "mouth_source_pose_not_bound"}
	if not sources.has(source_key):
		return {"ready": false, "reason": "mouth_source_points_not_prepared"}
	return {"ready": true, "reason": "", "pose": pose, "registration": registration,
		"source_key": source_key, "points": sources[source_key], "entry": entry}
