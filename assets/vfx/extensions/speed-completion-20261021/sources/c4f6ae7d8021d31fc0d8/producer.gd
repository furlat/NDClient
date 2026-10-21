extends "res://assets/vfx/extensions/speed-completion-20261021/sources/8e712bf337c67beda4da/entity_geometry_bounded.gd"
## Factory-only optional transport. Current source/world-normal equations;
## actual legacy points remain present and their cost remains paid.
const PointView = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/24740997d533fc6e3ec5/point_view.gd")
const SourcePoints = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/350385c4a3fd221f0165/source_points.gd")
const SOURCE_LIMIT := 128
var emit_typed_view := true
var source_order: Array = []
var source_builds := 0
var source_build_us := 0
var packed_point_writes := 0


func _current_source(world: Node, entry: Dictionary) -> Dictionary:
	var source: Dictionary = Geometry.record(entry.texture_path, entry.actor_layer.slot, world.catalog_cache)
	if source.is_empty():
		return {"ready": false, "reason": "source_geometry_not_registered"}
	var normal_paths: Dictionary = Geometry.normal_paths(entry.texture_path, entry.actor_layer.slot, world.catalog_cache)
	if not normal_paths.ok or not normal_paths.value.has(world.character_light_profile):
		return {"ready": false, "reason": "normal_profile_not_registered"}
	if not entry.has("geometry_ground_pixels"):
		return {"ready": false, "reason": "source_optical_ground_not_registered"}
	var root_path: String = Geometry._root(source)
	var paths := {"colour": entry.texture_path,
		"depth": root_path.path_join(source.files.depth),
		"support": root_path.path_join(source.files.support),
		"normal_valid": root_path.path_join(source.files.normal_valid),
		"normal": normal_paths.value[world.character_light_profile]}
	var images: Dictionary = {}
	for name: String in paths:
		if not world.source_images.has(paths[name]):
			return {"ready": false, "reason": "source_" + name + "_not_prepared"}
		images[name] = world.source_images[paths[name]]
	var pose: Array = [entry.material.get_shader_parameter("frame_uv"),
		entry.material.get_shader_parameter("component_units"),
		entry.material.get_shader_parameter("component_elevation"),
		entry.material.get_shader_parameter("component_reconstruction_origin"),
		entry.material.get_shader_parameter("component_depth_range"),
		entry.pivot, float(entry.geometry_ground_pixels), world.camera.global_basis]
	var key: Array = [entry.texture_path, world.character_light_profile,
		images.colour.get_instance_id(), images.depth.get_instance_id(),
		images.support.get_instance_id(), images.normal_valid.get_instance_id(),
		images.normal.get_instance_id(), pose]
	if not cache.has(key):
		var began := Time.get_ticks_usec()
		var points: Array = SourcePoints.measure(images, pose[0], pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], pose[7])
		for point: Dictionary in points:
			point.make_read_only()
		points.make_read_only()
		cache[key] = points
		source_builds += 1
		source_build_us += Time.get_ticks_usec() - began
		source_order.append(key)
		if source_order.size() > SOURCE_LIMIT:
			cache.erase(source_order.pop_front())
	return {"ready": true, "key": key, "points": cache[key]}


func sample(world: Node, actor: String, slots: Array) -> Dictionary:
	var result := {"actor": actor, "actor_uuid": actor, "entity_uuid": actor,
		"points": [], "origin": Vector3.ZERO, "pose_key": [],
		"gpu_geometry_key": [], "ready": false, "reason": "actor_not_displayed"}
	if not world.visual_actors.has(actor):
		return result
	var visual: Dictionary = world.visual_actors[actor]
	if not visual.get("valid", false) or visual.get("row", {}).is_empty():
		return result
	result.origin = world.get_node(world.actor_markers[actor]).global_position
	var selected: Array[Dictionary] = []
	var revision: Array = []
	var entries: Array = world.visual_actors[actor].entries
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		var slot: String = entry.actor_layer.slot
		if slot not in slots or entry.role == "shadow" or not entry.node.is_visible_in_tree():
			continue
		if not entry.actor_layer.get("effect", {}).is_empty():
			continue
		var captured := _current_source(world, entry)
		if not captured.ready:
			result.reason = captured.reason
			return result
		var transform: Transform3D = entry.node.global_transform
		selected.append({"entry": entry, "key": captured.key,
			"points": captured.points, "slot": slot, "transform": transform})
		result.pose_key.append(captured.key)
		revision.append([captured.key, slot, transform.basis, transform.origin - result.origin])
	result.gpu_geometry_key = revision
	var owner_key: Array = [actor, slots]
	var world_key: Array = [revision, result.origin, emit_typed_view]
	if world_packets.has(owner_key) and world_packets[owner_key].revision == world_key:
		return world_packets[owner_key].packet.duplicate(false)
	var owned: Dictionary = {}
	var centre := Vector3.ZERO
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	for description: Dictionary in selected:
		var transform: Transform3D = description.transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		for point: Dictionary in description.points:
			if owned.has(point.pixel):
				continue
			owned[point.pixel] = true
			var position: Vector3 = transform * point.local
			var normal: Vector3 = (normal_basis * point.normal).normalized()
			result.points.append({"position": position, "normal": normal,
				"uv": point.uv, "pixel": point.pixel, "slot": description.slot})
			centre += position
			if emit_typed_view:
				positions.append(position)
				normals.append(normal)
				packed_point_writes += 2
	result.ready = not result.points.is_empty()
	result.reason = "" if result.ready else "no_admitted_optical_points"
	if result.ready:
		result.optical_anchor = centre / float(result.points.size())
	if emit_typed_view:
		result[PointView.FIELD] = PointView.finish(result, positions, normals)
	world_packet_builds += 1
	if not world_packets.has(owner_key):
		packet_order.append(owner_key.duplicate(true))
	world_packets[owner_key.duplicate(true)] = {"revision": world_key, "packet": result}
	if packet_order.size() > PACKET_LIMIT:
		world_packets.erase(packet_order.pop_front())
	return result.duplicate(false)
