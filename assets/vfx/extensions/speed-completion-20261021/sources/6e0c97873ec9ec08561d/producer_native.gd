extends "res://assets/vfx/extensions/speed-completion-20261021/sources/c4f6ae7d8021d31fc0d8/producer.gd"
## Optional same-packet producer: exact occupied source region and native
## world mapping. Every legacy dictionary and ordered sum is still constructed.
const SourcePixels = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/9cfcc782c1f2fc05303a/source_pixels.gd")
var source_reader := SourcePixels.new()
var profile_provider := false
var provider_spans: Dictionary = {}


func record_span(name: String, began: int) -> void:
	if not provider_spans.has(name):
		provider_spans[name] = []
	provider_spans[name].append(Time.get_ticks_usec() - began)


func _current_source(world: Node, entry: Dictionary) -> Dictionary:
	var stage_started := Time.get_ticks_usec() if profile_provider else 0
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
	if profile_provider:
		record_span("source_images_and_metadata", stage_started)
		stage_started = Time.get_ticks_usec()
	var pose: Array = [entry.material.get_shader_parameter("frame_uv"),
		entry.material.get_shader_parameter("component_units"),
		entry.material.get_shader_parameter("component_elevation"),
		entry.material.get_shader_parameter("component_reconstruction_origin"),
		entry.material.get_shader_parameter("component_depth_range"),
		entry.pivot, float(entry.geometry_ground_pixels), world.camera.global_basis]
	if profile_provider:
		record_span("five_shader_getters_and_pose", stage_started)
		stage_started = Time.get_ticks_usec()
	var key: Array = [entry.texture_path, world.character_light_profile,
		images.colour.get_instance_id(), images.depth.get_instance_id(),
		images.support.get_instance_id(), images.normal_valid.get_instance_id(),
		images.normal.get_instance_id(), pose]
	if profile_provider:
		record_span("source_key", stage_started)
	if not cache.has(key):
		var began := Time.get_ticks_usec()
		var captured: Dictionary = source_reader.measure(images, pose[0], pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], pose[7])
		if profile_provider:
			record_span("source_local_measure", began)
			stage_started = Time.get_ticks_usec()
		var points: Array = captured.points
		for point: Dictionary in points:
			point.make_read_only()
		points.make_read_only()
		if profile_provider:
			record_span("source_point_readonly_publication", stage_started)
		cache[key] = captured
		source_builds += 1
		source_build_us += Time.get_ticks_usec() - began
		source_order.append(key)
		if source_order.size() > SOURCE_LIMIT:
			cache.erase(source_order.pop_front())
	return {"ready": true, "key": key, "points": cache[key].points,
		"positions": cache[key].positions, "normals": cache[key].normals}


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
			"points": captured.points, "positions": captured.positions,
			"normals": captured.normals, "slot": slot, "transform": transform})
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
		var stage_started := Time.get_ticks_usec() if profile_provider else 0
		var transform: Transform3D = description.transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var actual_points: Array = description.points
		var world_positions: PackedVector3Array = transform * description.positions
		var world_normals: PackedVector3Array = Transform3D(normal_basis, Vector3.ZERO) * description.normals
		if profile_provider:
			record_span("native_world_mapping", stage_started)
			stage_started = Time.get_ticks_usec()
		for ordinal: int in actual_points.size():
			var point: Dictionary = actual_points[ordinal]
			if owned.has(point.pixel):
				continue
			owned[point.pixel] = true
			var position: Vector3 = world_positions[ordinal]
			var normal: Vector3 = world_normals[ordinal].normalized()
			result.points.append({"position": position, "normal": normal,
				"uv": point.uv, "pixel": point.pixel, "slot": description.slot})
			centre += position
			if emit_typed_view:
				positions.append(position)
				normals.append(normal)
				packed_point_writes += 2
		if profile_provider:
			record_span("world_dictionaries_dedup_ordered_sum_and_packed_appends", stage_started)
	result.ready = not result.points.is_empty()
	result.reason = "" if result.ready else "no_admitted_optical_points"
	if result.ready:
		result.optical_anchor = centre / float(result.points.size())
	if emit_typed_view:
		var stage_started := Time.get_ticks_usec() if profile_provider else 0
		result[PointView.FIELD] = PointView.finish(result, positions, normals)
		if profile_provider:
			record_span("point_view_identity", stage_started)
	world_packet_builds += 1
	if not world_packets.has(owner_key):
		packet_order.append(owner_key.duplicate(true))
	world_packets[owner_key.duplicate(true)] = {"revision": world_key, "packet": result}
	if packet_order.size() > PACKET_LIMIT:
		world_packets.erase(packet_order.pop_front())
	return result.duplicate(false)
