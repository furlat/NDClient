extends "res://assets/vfx/extensions/speed-completion-20261021/sources/6e0c97873ec9ec08561d/producer_native.gd"
## Same source/packet path; hoist repeated private Dictionary/property reads.
## Aggregate only the diagnostic append counter after synchronous point writes.


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
		var actual_points: Array = description.points
		var slot: String = description.slot
		var world_positions: PackedVector3Array = transform * description.positions
		var world_normals: PackedVector3Array = Transform3D(normal_basis, Vector3.ZERO) * description.normals
		if profile_provider:
			record_span("native_world_mapping", stage_started)
			stage_started = Time.get_ticks_usec()
		for ordinal: int in actual_points.size():
			var point: Dictionary = actual_points[ordinal]
			var pixel: Vector2i = point.pixel
			if owned.has(pixel):
				continue
			owned[pixel] = true
			var position: Vector3 = world_positions[ordinal]
			var normal: Vector3 = world_normals[ordinal].normalized()
			point_rows.append({"position": position, "normal": normal,
				"uv": point.uv, "pixel": pixel, "slot": slot})
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
