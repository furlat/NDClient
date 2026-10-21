extends "res://assets/vfx/extensions/speed-completion-20261021/sources/9c2c3dad79b8acdd920e/producer.gd"
## Only previously observed world normals are reused. Current positions, source
## admission, painter order, keys and ordered centre reduction remain live.
var normal_reuse_hits := 0
var normal_reuse_misses := 0
var normalized_points_reused := 0


func _basis_bytes(selected: Array[Dictionary]) -> PackedByteArray:
	var result := PackedByteArray()
	for description: Dictionary in selected:
		var basis: Basis = description.transform.basis
		# Native f32 bytes distinguish signed zero. Translation does not occur
		# in inverse-transpose normal mapping; source/ordinal identity belongs
		# to the inherited certified roster, not to a weaker numeric key.
		result.append_array(PackedVector3Array([basis.x, basis.y, basis.z]).to_byte_array())
	return result


func sample_packed(world: Node, actor: String, slots: Array) -> Resource:
	var result := {"actor": actor, "actor_uuid": actor, "entity_uuid": actor,
		"origin": Vector3.ZERO, "pose_key": [], "gpu_geometry_key": [],
		"ready": false, "reason": "actor_not_displayed"}
	if not world.visual_actors.has(actor):
		_clear_rosters()
		return PackedPacket.publish(result, PackedVector3Array(), PackedVector3Array(), [], Vector3.ZERO, Vector3.ZERO)
	var visual: Dictionary = world.visual_actors[actor]
	if not visual.get("valid", false) or visual.get("row", {}).is_empty():
		_clear_rosters()
		return PackedPacket.publish(result, PackedVector3Array(), PackedVector3Array(), [], Vector3.ZERO, Vector3.ZERO)
	result.origin = world.get_node(world.actor_markers[actor]).global_position
	var selected: Array[Dictionary] = []
	var revision: Array = []
	var entries: Array = visual.entries
	var source_capture_changed := false
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		var slot: String = entry.actor_layer.slot
		if slot not in slots or entry.role == "shadow" or not entry.node.is_visible_in_tree():
			continue
		if not entry.actor_layer.get("effect", {}).is_empty():
			continue
		var builds_before := source_builds
		var captured := _current_source(world, entry)
		source_capture_changed = source_capture_changed or source_builds != builds_before
		if not captured.ready:
			_clear_rosters()
			result.reason = captured.reason
			return PackedPacket.publish(result, PackedVector3Array(), PackedVector3Array(), [], Vector3.ZERO, Vector3.ZERO)
		var transform: Transform3D = entry.node.global_transform
		selected.append({"key": captured.key, "pixels": captured.pixels, "uvs": captured.uvs,
			"source_entry": cache[captured.key], "slot": slot, "transform": transform})
		result.pose_key.append(captured.key)
		revision.append([captured.key, slot, transform.basis, transform.origin - result.origin])
	result.gpu_geometry_key = revision
	var owner_key: Array = [actor, slots]
	var world_key: Array = [revision, result.origin, emit_typed_view]
	if not source_capture_changed and packed_packets.has(owner_key) and packed_packets[owner_key].revision == world_key:
		return packed_packets[owner_key].packet
	var stage_started := Time.get_ticks_usec() if profile_provider else 0
	var roster := _roster(selected)
	if roster.count == 0:
		_clear_rosters()
	var columns := _admitted_columns(roster, selected)
	if profile_provider:
		record_span("observed_admission_and_admitted_local_projection", stage_started)
	var positions := PackedVector3Array()
	var signature := _basis_bytes(selected)
	var retained: Dictionary = roster.get("observed_world_normals", {})
	var reuse: bool = not retained.is_empty() and retained.basis_bytes == signature
	var normals := PackedVector3Array()
	if reuse:
		normals = retained.values
		normal_reuse_hits += 1
		normalized_points_reused += roster.count
	else:
		normals.resize(roster.count)
		normal_reuse_misses += 1
	var centre := Vector3.ZERO
	var normal_sum: Vector3 = retained.ordered_sum if reuse else Vector3.ZERO
	var output_ordinal := 0
	for index: int in selected.size():
		var column: Dictionary = columns[index]
		if column.positions.is_empty():
			continue
		stage_started = Time.get_ticks_usec() if profile_provider else 0
		var transform: Transform3D = selected[index].transform
		var world_positions: PackedVector3Array = transform * column.positions
		var world_normals := PackedVector3Array()
		if not reuse:
			var normal_basis: Basis = transform.basis.inverse().transposed()
			world_normals = Transform3D(normal_basis, Vector3.ZERO) * column.normals
		positions.append_array(world_positions)
		world_points_mapped += world_positions.size()
		if profile_provider:
			record_span("admitted_native_world_mapping_and_position_append", stage_started)
			stage_started = Time.get_ticks_usec()
		if reuse:
			# Current positions and the original ordered f32 centre reduction
			# remain live. No translation/affine-centroid reassociation.
			for ordinal: int in world_positions.size():
				var position: Vector3 = world_positions[ordinal]
				centre += position
		else:
			# Same native/vector arithmetic and ordered sum as the frozen source.
			for ordinal: int in world_positions.size():
				var position: Vector3 = world_positions[ordinal]
				var normal: Vector3 = world_normals[ordinal].normalized()
				centre += position
				normal_sum += normal
				normals[output_ordinal] = normal
				output_ordinal += 1
		if profile_provider:
			record_span("actual_world_normals_and_ordered_reductions", stage_started)
	if not reuse:
		# One last result belongs to this exact certified roster. Its original
		# 32-entry eviction/lifetime releases these arrays as well. Packed-array
		# COW leaves previously published packets unchanged on the next miss.
		roster.observed_world_normals = {"basis_bytes": signature, "values": normals,
			"ordered_sum": normal_sum}
	packed_point_writes += positions.size() * (1 if reuse else 2)
	result.ready = not positions.is_empty()
	result.reason = "" if result.ready else "no_admitted_optical_points"
	var packet := PackedPacket.publish(result, positions, normals, roster.groups, centre, normal_sum)
	world_packet_builds += 1
	if not packed_packets.has(owner_key):
		packed_order.append(owner_key.duplicate(true))
	packed_packets[owner_key.duplicate(true)] = {"revision": world_key, "packet": packet}
	if packed_order.size() > PACKET_LIMIT:
		packed_packets.erase(packed_order.pop_front())
	return packet
