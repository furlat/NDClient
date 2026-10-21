extends "res://assets/vfx/extensions/speed-completion-20261021/sources/c2ad44b8231d8abd1228/producer_local.gd"
## Optional prepared immutable pixels. Complete public Dictionaries are built
## once; all local/world operands and private packet identities remain live.
const Preparation = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/75c165fc1e64ba310420/preparation.gd")
var prepared_sources: Dictionary = {}
var prepared_source_builds := 0
var fallback_source_builds := 0


func _source_inputs(world: Node, entry: Dictionary) -> Dictionary:
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
	return {"ready": true, "reason": "", "images": images, "pose": pose, "key": key,
		"descriptor": {"source_path": entry.texture_path,
			"normal_profile": world.character_light_profile, "paths": paths}}


func begin_source_preparation(world: Node, entry: Dictionary) -> Dictionary:
	var inputs := _source_inputs(world, entry)
	if not inputs.ready:
		return {"done": true, "error": inputs.reason}
	return Preparation.begin(inputs.images, inputs.pose[0], inputs.descriptor)


func _current_source(world: Node, entry: Dictionary) -> Dictionary:
	var inputs := _source_inputs(world, entry)
	if not inputs.ready:
		return inputs
	var key: Array = inputs.key
	if not cache.has(key):
		var began := Time.get_ticks_usec()
		var pose: Array = inputs.pose
		var pixel_key := Preparation.identity_key(inputs.images, pose[0], inputs.descriptor)
		var captured: Dictionary
		if prepared_sources.has(pixel_key):
			var recipe: Resource = prepared_sources[pixel_key].recipe
			captured = recipe.project(pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], pose[7])
			prepared_source_builds += 1
		else:
			# Unknown format, region or absent publication keeps the exact reader.
			var original: Dictionary = source_reader.measure(inputs.images, pose[0],
				pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], pose[7])
			var pixels: Array[Vector2i] = []
			var uvs := PackedVector2Array()
			for point: Dictionary in original.points:
				pixels.append(point.pixel)
				uvs.append(point.uv)
			pixels.make_read_only()
			captured = {"positions": original.positions, "normals": original.normals,
				"pixels": pixels, "uvs": uvs}
			fallback_source_builds += 1
		cache[key] = captured
		source_builds += 1
		source_build_us += Time.get_ticks_usec() - began
		source_order.append(key)
		if source_order.size() > SOURCE_LIMIT:
			cache.erase(source_order.pop_front())
	var actual: Dictionary = cache[key]
	return {"ready": true, "key": key, "positions": actual.positions,
		"normals": actual.normals, "pixels": actual.pixels, "uvs": actual.uvs}


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
			"pixels": captured.pixels, "uvs": captured.uvs, "positions": captured.positions,
			"normals": captured.normals, "slot": slot, "transform": transform})
		result.pose_key.append(captured.key)
		revision.append([captured.key, slot, transform.basis, transform.origin - result.origin])
	result.gpu_geometry_key = revision
	var owner_key: Array = [actor, slots]
	var world_key: Array = [revision, result.origin, emit_typed_view]
	if world_packets.has(owner_key) and world_packets[owner_key].revision == world_key:
		return world_packets[owner_key].packet.duplicate(false)
	var point_rows: Array = result.points
	var typed_output: bool = emit_typed_view
	var owned: Dictionary = {}
	var centre := Vector3.ZERO
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	for description: Dictionary in selected:
		var stage_started := Time.get_ticks_usec() if profile_provider else 0
		var transform: Transform3D = description.transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var actual_pixels: Array[Vector2i] = description.pixels
		var actual_uvs: PackedVector2Array = description.uvs
		var slot: String = description.slot
		var world_positions: PackedVector3Array = transform * description.positions
		var world_normals: PackedVector3Array = Transform3D(normal_basis, Vector3.ZERO) * description.normals
		if profile_provider:
			record_span("native_world_mapping", stage_started)
			stage_started = Time.get_ticks_usec()
		for ordinal: int in actual_pixels.size():
			var pixel: Vector2i = actual_pixels[ordinal]
			if owned.has(pixel):
				continue
			owned[pixel] = true
			var position: Vector3 = world_positions[ordinal]
			var normal: Vector3 = world_normals[ordinal].normalized()
			point_rows.append({"position": position, "normal": normal,
				"uv": actual_uvs[ordinal], "pixel": pixel, "slot": slot})
			centre += position
			if typed_output:
				positions.append(position)
				normals.append(normal)
		if profile_provider:
			record_span("world_dictionaries_dedup_ordered_sum_and_packed_appends", stage_started)
	if typed_output:
		packed_point_writes += positions.size() * 2
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
