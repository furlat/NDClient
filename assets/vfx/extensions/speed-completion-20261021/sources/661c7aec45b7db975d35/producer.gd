extends "res://assets/vfx/extensions/speed-completion-20261021/sources/b78804f570db4b32534d/producer.gd"
## Reuse only observed immutable painter admission; world geometry stays live.
const ROSTER_LIMIT := 32
var admission_rosters: Dictionary = {}
var roster_order: Array = []
var roster_builds := 0
var roster_hits := 0
var roster_invalidations := 0
var roster_source_points_scanned := 0


func _clear_rosters() -> void:
	roster_invalidations += admission_rosters.size()
	admission_rosters.clear()
	roster_order.clear()


func _roster(selected: Array[Dictionary]) -> Dictionary:
	var key: Array = []
	for description: Dictionary in selected:
		key.append([description.key, description.slot])
	if admission_rosters.has(key):
		var retained: Dictionary = admission_rosters[key]
		var current: bool = retained.entries.size() == selected.size()
		for index: int in selected.size():
			var source_key: Array = selected[index].key
			if not cache.has(source_key) or not is_same(cache[source_key], retained.entries[index]):
				current = false
				break
		if current:
			roster_hits += 1
			roster_order.erase(key)
			roster_order.append(key)
			return retained
		admission_rosters.erase(key)
		roster_order.erase(key)
		roster_invalidations += 1
	var entries: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	var owned: Dictionary = {}
	var count := 0
	var retainable := true
	for description: Dictionary in selected:
		var actual_pixels: Array[Vector2i] = description.pixels
		var accepted := PackedInt32Array()
		roster_source_points_scanned += actual_pixels.size()
		for ordinal: int in actual_pixels.size():
			var pixel: Vector2i = actual_pixels[ordinal]
			if owned.has(pixel):
				continue
			owned[pixel] = true
			accepted.append(ordinal)
			count += 1
		groups.append({"pixels": actual_pixels, "uvs": description.uvs,
			"slot": description.slot, "accepted": accepted})
		if not cache.has(description.key) or not is_same(cache[description.key], description.source_entry):
			retainable = false
		entries.append(description.source_entry)
	var result := {"groups": groups, "entries": entries, "count": count}
	roster_builds += 1
	# A stack can exceed the source-cache capacity. Its complete observed data
	# still renders; do not retain an uncertifiable roster or impose a body cap.
	if retainable:
		admission_rosters[key.duplicate(true)] = result
		roster_order.append(key.duplicate(true))
		if roster_order.size() > ROSTER_LIMIT:
			admission_rosters.erase(roster_order.pop_front())
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
		selected.append({"key": captured.key, "pixels": captured.pixels,
			"uvs": captured.uvs, "positions": captured.positions, "normals": captured.normals,
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
	if profile_provider:
		record_span("observed_painter_roster_admission", stage_started)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	positions.resize(roster.count)
	normals.resize(roster.count)
	var centre := Vector3.ZERO
	var normal_sum := Vector3.ZERO
	var output_ordinal := 0
	for index: int in selected.size():
		var description: Dictionary = selected[index]
		var group: Dictionary = roster.groups[index]
		var accepted: PackedInt32Array = group.accepted
		if accepted.is_empty():
			continue
		stage_started = Time.get_ticks_usec() if profile_provider else 0
		var transform: Transform3D = description.transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var world_positions: PackedVector3Array = transform * description.positions
		var world_normals: PackedVector3Array = Transform3D(normal_basis, Vector3.ZERO) * description.normals
		if profile_provider:
			record_span("native_world_mapping", stage_started)
			stage_started = Time.get_ticks_usec()
		for ordinal: int in accepted:
			var position: Vector3 = world_positions[ordinal]
			var normal: Vector3 = world_normals[ordinal].normalized()
			centre += position
			normal_sum += normal
			positions[output_ordinal] = position
			normals[output_ordinal] = normal
			output_ordinal += 1
		if profile_provider:
			record_span("actual_world_normal_ordered_sums_and_packed_writes", stage_started)
	packed_point_writes += positions.size() * 2
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
