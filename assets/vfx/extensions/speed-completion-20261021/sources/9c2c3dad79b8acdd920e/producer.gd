extends "res://assets/vfx/extensions/speed-completion-20261021/sources/661c7aec45b7db975d35/producer.gd"
## Painter admission precedes local projection; every current world operand stays live.
const PixelRecipe = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/6a377421dc20574abb2a/recipe.gd")
var admitted_local_projection_calls := 0
var admitted_local_projection_us := 0
var actual_source_rows := 0
var admitted_source_rows_projected := 0
var unadmitted_source_rows_not_projected := 0
var fallback_source_rows_materialized := 0
var world_points_mapped := 0


func _current_source(world: Node, entry: Dictionary) -> Dictionary:
	var inputs := _source_inputs(world, entry)
	if not inputs.ready:
		return inputs
	var key: Array = inputs.key
	if not cache.has(key):
		var pose: Array = inputs.pose
		var pixel_key := Preparation.identity_key(inputs.images, pose[0], inputs.descriptor)
		var recipe: Resource = prepared_sources[pixel_key].recipe if prepared_sources.has(pixel_key) else null
		if recipe == null or recipe.get_script() != PixelRecipe:
			# Unsupported publications keep the full original source reader/projector.
			var builds_before := source_builds
			var original := super._current_source(world, entry)
			if source_builds != builds_before and original.ready:
				fallback_source_rows_materialized += original.pixels.size()
			return original
		var began := Time.get_ticks_usec()
		cache[key] = {"pixels": recipe.pixels, "uvs": recipe.uvs,
			"admitted_recipe": recipe, "actual_pose": pose}
		source_builds += 1
		source_build_us += Time.get_ticks_usec() - began
		source_order.append(key)
		if source_order.size() > SOURCE_LIMIT:
			cache.erase(source_order.pop_front())
	var actual: Dictionary = cache[key]
	return {"ready": true, "key": key, "pixels": actual.pixels, "uvs": actual.uvs}


func _project_admitted(recipe: Resource, pose: Array, accepted: PackedInt32Array) -> Dictionary:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	positions.resize(accepted.size())
	normals.resize(accepted.size())
	var units: float = pose[1]
	var elevation: float = pose[2]
	var origin: Vector2 = pose[3]
	var depth_range: Vector2 = pose[4]
	var pivot: Vector2 = pose[5]
	var ground: float = pose[6]
	var camera_basis: Basis = pose[7]
	var toward: Vector3 = camera_basis.z
	var horizontal := Vector3(toward.x, 0, toward.z).normalized()
	# Reuse exact scalar function results; never reassociate the source arithmetic.
	var cosine := cos(elevation)
	var sine := sin(elevation)
	var normal_basis := camera_basis.inverse() * Basis(camera_basis.x,
		Vector3(0, cosine, 0) - horizontal * sine,
		horizontal * cosine + Vector3(0, sine, 0))
	var centres: PackedVector2Array = recipe.centres
	var depth_red: PackedFloat32Array = recipe.depth_red
	var raw_normals: PackedVector3Array = recipe.raw_normals
	for output_ordinal: int in accepted.size():
		var source_ordinal: int = accepted[output_ordinal]
		var centre: Vector2 = centres[source_ordinal]
		var decoded: float = depth_range.x + (depth_red[source_ordinal] * 255.0 - 32.0) * (depth_range.y - depth_range.x) / 192.0
		var height: float = ((origin.y - centre.y) * cosine + decoded * sine - ground) * units
		var painted := Vector3(centre.x - pivot.x, pivot.y - centre.y, 0) * units
		var ray: float = (height - (camera_basis * painted).y) / toward.y
		positions[output_ordinal] = painted + Vector3(0, 0, ray)
		normals[output_ordinal] = (normal_basis * raw_normals[source_ordinal]).normalized()
	return {"positions": positions, "normals": normals}


func _admitted_columns(roster: Dictionary, selected: Array[Dictionary]) -> Array[Dictionary]:
	if roster.has("admitted_columns"):
		return roster.admitted_columns
	var columns: Array[Dictionary] = []
	for index: int in selected.size():
		var actual: Dictionary = selected[index].source_entry
		var accepted: PackedInt32Array = roster.groups[index].accepted
		actual_source_rows += actual.pixels.size()
		if actual.has("admitted_recipe"):
			unadmitted_source_rows_not_projected += actual.pixels.size() - accepted.size()
			if accepted.is_empty():
				columns.append({"positions": PackedVector3Array(), "normals": PackedVector3Array()})
				continue
			var began := Time.get_ticks_usec()
			columns.append(_project_admitted(actual.admitted_recipe, actual.actual_pose, accepted))
			var elapsed := Time.get_ticks_usec() - began
			admitted_local_projection_us += elapsed
			source_build_us += elapsed
			admitted_local_projection_calls += 1
			prepared_source_builds += 1
			admitted_source_rows_projected += accepted.size()
		else:
			var positions := PackedVector3Array()
			var normals := PackedVector3Array()
			positions.resize(accepted.size())
			normals.resize(accepted.size())
			for ordinal: int in accepted.size():
				positions[ordinal] = actual.positions[accepted[ordinal]]
				normals[ordinal] = actual.normals[accepted[ordinal]]
			columns.append({"positions": positions, "normals": normals})
	# The inherited roster verifies each actual cache-entry identity before reuse.
	# This outer private cache is not exported in the unchanged packet groups.
	roster.admitted_columns = columns
	return columns


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
	var normals := PackedVector3Array()
	normals.resize(roster.count)
	var centre := Vector3.ZERO
	var normal_sum := Vector3.ZERO
	var output_ordinal := 0
	for index: int in selected.size():
		var column: Dictionary = columns[index]
		if column.positions.is_empty():
			continue
		stage_started = Time.get_ticks_usec() if profile_provider else 0
		var transform: Transform3D = selected[index].transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var world_positions: PackedVector3Array = transform * column.positions
		var world_normals: PackedVector3Array = Transform3D(normal_basis, Vector3.ZERO) * column.normals
		positions.append_array(world_positions)
		world_points_mapped += world_positions.size()
		if profile_provider:
			record_span("admitted_native_world_mapping_and_position_append", stage_started)
			stage_started = Time.get_ticks_usec()
		for ordinal: int in world_positions.size():
			var position: Vector3 = world_positions[ordinal]
			var normal: Vector3 = world_normals[ordinal].normalized()
			centre += position
			normal_sum += normal
			normals[output_ordinal] = normal
			output_ordinal += 1
		if profile_provider:
			record_span("actual_world_normals_and_ordered_reductions", stage_started)
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
