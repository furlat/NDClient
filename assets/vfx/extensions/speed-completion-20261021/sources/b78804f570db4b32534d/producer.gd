extends "res://assets/vfx/extensions/speed-completion-20261021/sources/84e701f587d5841914ff/producer.gd"
## Explicit Factory-only packed output; no implicit client protocol adoption.
const PackedPacket = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/713a49dfb1d669ead5fe/packet.gd")
var packed_packets: Dictionary = {}
var packed_order: Array = []


func sample(world: Node, actor: String, slots: Array) -> Dictionary:
	return sample_packed(world, actor, slots).legacy(emit_typed_view)


func sample_packed(world: Node, actor: String, slots: Array) -> Resource:
	var result := {"actor": actor, "actor_uuid": actor, "entity_uuid": actor,
		"origin": Vector3.ZERO, "pose_key": [],
		"gpu_geometry_key": [], "ready": false, "reason": "actor_not_displayed"}
	if not world.visual_actors.has(actor):
		return PackedPacket.publish(result, PackedVector3Array(), PackedVector3Array(), [], Vector3.ZERO, Vector3.ZERO)
	var visual: Dictionary = world.visual_actors[actor]
	if not visual.get("valid", false) or visual.get("row", {}).is_empty():
		return PackedPacket.publish(result, PackedVector3Array(), PackedVector3Array(), [], Vector3.ZERO, Vector3.ZERO)
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
			return PackedPacket.publish(result, PackedVector3Array(), PackedVector3Array(), [], Vector3.ZERO, Vector3.ZERO)
		var transform: Transform3D = entry.node.global_transform
		selected.append({"entry": entry, "key": captured.key,
			"pixels": captured.pixels, "uvs": captured.uvs, "positions": captured.positions,
			"normals": captured.normals, "slot": slot, "transform": transform})
		result.pose_key.append(captured.key)
		revision.append([captured.key, slot, transform.basis, transform.origin - result.origin])
	result.gpu_geometry_key = revision
	var owner_key: Array = [actor, slots]
	var world_key: Array = [revision, result.origin, emit_typed_view]
	if packed_packets.has(owner_key) and packed_packets[owner_key].revision == world_key:
		return packed_packets[owner_key].packet
	var groups: Array[Dictionary] = []
	var owned: Dictionary = {}
	var centre := Vector3.ZERO
	var normal_sum := Vector3.ZERO
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	for description: Dictionary in selected:
		var stage_started := Time.get_ticks_usec() if profile_provider else 0
		var transform: Transform3D = description.transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var actual_pixels: Array[Vector2i] = description.pixels
		var actual_uvs: PackedVector2Array = description.uvs
		var slot: String = description.slot
		var accepted := PackedInt32Array()
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
			accepted.append(ordinal)
			centre += position
			normal_sum += normal
			positions.append(position)
			normals.append(normal)
		groups.append({"pixels": actual_pixels, "uvs": actual_uvs, "slot": slot, "accepted": accepted})
		if profile_provider:
			record_span("packed_painter_admission_ordered_sums_and_appends", stage_started)
	packed_point_writes += positions.size() * 2
	result.ready = not positions.is_empty()
	result.reason = "" if result.ready else "no_admitted_optical_points"
	var packet := PackedPacket.publish(result, positions, normals, groups, centre, normal_sum)
	world_packet_builds += 1
	if not packed_packets.has(owner_key):
		packed_order.append(owner_key.duplicate(true))
	packed_packets[owner_key.duplicate(true)] = {"revision": world_key, "packet": packet}
	if packed_order.size() > PACKET_LIMIT:
		packed_packets.erase(packed_order.pop_front())
	return packet
