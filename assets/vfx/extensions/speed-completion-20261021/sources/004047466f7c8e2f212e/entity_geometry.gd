extends RefCounted
## Measured visible surfaces for fitting external VFX, not a replacement actor.
## Uses the same source-over ownership and optical reconstruction as the host.
const Geometry = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/44494a78aa3243d89297/character_geometry.gd")

var cache: Dictionary = {}
var world_packets: Dictionary = {}
var packet_order: Array = []
var world_packet_builds := 0
const PACKET_LIMIT := 32

func sample(world: Node, actor: String, slots: Array) -> Dictionary:
	var result := {"actor": actor, "points": [], "origin": Vector3.ZERO, "pose_key": []}
	if not world.visual_actors.has(actor):
		return result
	result.origin = world.get_node(world.actor_markers[actor]).global_position
	var selected := []
	var relative_frames := []
	var entries: Array = world.visual_actors[actor].entries
	for index in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		var slot: String = entry.actor_layer.slot
		if not entry.node.visible or not slots.has(slot) or entry.role == "shadow":
			continue
		var key: Array = [entry.texture_path, entry.material.get_shader_parameter("frame_uv"),
			world.quarter, world.character_light_profile]
		result.pose_key.append(key)
		relative_frames.append([entry.node.global_basis, entry.node.global_position-result.origin])
		selected.append({"entry":entry,"key":key,"slot":slot})
	result.gpu_geometry_key = [result.pose_key.duplicate(true),relative_frames]
	var owner_key: Array = [actor, slots]
	var revision: Array = [result.gpu_geometry_key, result.origin]
	if world_packets.has(owner_key) and world_packets[owner_key].revision == revision:
		# Packets/point arrays are read-only inputs. The shallow dictionary copy
		# isolates per-occurrence annotations without repacking every optical pixel.
		return world_packets[owner_key].packet.duplicate(false)
	var owned: Dictionary = {}
	for description in selected:
		var entry: Dictionary = description.entry
		if not cache.has(description.key):
			cache[description.key] = _source_points(world, entry)
		for point in cache[description.key]:
			if owned.has(point.pixel):
				continue
			owned[point.pixel] = true
			result.points.append({"position":entry.node.global_transform*point.local,
				"normal":point.normal,"uv":point.uv,"pixel":point.pixel,"slot":description.slot})
	world_packet_builds += 1
	if not world_packets.has(owner_key):
		packet_order.append(owner_key.duplicate(true))
	world_packets[owner_key.duplicate(true)] = {"revision":revision.duplicate(true),"packet":result}
	if packet_order.size() > PACKET_LIMIT:
		world_packets.erase(packet_order.pop_front())
	return result.duplicate(false)

func _source_points(world: Node, entry: Dictionary) -> Array:
	var result: Array = []
	var source := Geometry.record(entry.texture_path, entry.actor_layer.slot, world.catalog_cache)
	# Creature receivers use their registered optical_camera/normal_profiles
	# contract instead of a modular reference filename. Both bind the same
	# validated reconstruction uniforms in the actual renderer.
	if source.is_empty():
		return result
	var root: String = Geometry._root(source)
	var normal_paths: Dictionary = Geometry.normal_paths(entry.texture_path, entry.actor_layer.slot, world.catalog_cache)
	if not normal_paths.ok:
		return result
	var paths := {"depth": root.path_join(source.files.depth), "support": root.path_join(source.files.support),
		"normal_valid": root.path_join(source.files.normal_valid),
		"normal": normal_paths.value[world.character_light_profile]}
	for path in paths.values():
		if not world.source_images.has(path):
			world.presentation_errors.append("Measured VFX surface not prepared: " + path)
			return result
	var colour: Image = world.source_images[entry.texture_path]
	var frame: Vector4 = entry.material.get_shader_parameter("frame_uv")
	var offset := Vector2i(roundi(frame.x * colour.get_width()), roundi(frame.y * colour.get_height()))
	var size := Vector2i(roundi(frame.z * colour.get_width()), roundi(frame.w * colour.get_height()))
	var units: float = entry.material.get_shader_parameter("component_units")
	var elevation: float = entry.material.get_shader_parameter("component_elevation")
	var origin: Vector2 = entry.material.get_shader_parameter("component_reconstruction_origin")
	var depth_range: Vector2 = entry.material.get_shader_parameter("component_depth_range")
	var toward: Vector3 = world.camera.global_basis.z
	var horizontal := Vector3(toward.x, 0.0, toward.z).normalized()
	var source_up := Vector3(0.0, cos(elevation), 0.0) - horizontal * sin(elevation)
	var source_toward := horizontal * cos(elevation) + Vector3(0.0, sin(elevation), 0.0)
	var normal_basis := Basis(world.camera.global_basis.x, source_up, source_toward)
	# Full-resolution weapon edges matter. This is a cached pose measurement, not
	# a renderer readback or per-frame traversal of the entire sprite library.
	for y in size.y:
		for x in size.x:
			var pixel := Vector2i(x, y)
			var sheet_pixel := pixel + offset
			if colour.get_pixelv(sheet_pixel).a < 0.99:
				continue
			var depth: Color = world.source_images[paths.depth].get_pixelv(sheet_pixel)
			var normal: Color = world.source_images[paths.normal].get_pixelv(sheet_pixel)
			if depth.a < .5 or normal.a < .5 or world.source_images[paths.support].get_pixelv(sheet_pixel).r < .5:
				continue
			if world.source_images[paths.normal_valid].get_pixelv(sheet_pixel).r < .5:
				continue
			var centre := Vector2(x + .5, y + .5)
			var decoded: float = depth_range.x + (depth.r * 255.0 - 32.0) * (depth_range.y - depth_range.x) / 192.0
			var height: float = ((origin.y - centre.y) * cos(elevation) + decoded * sin(elevation)) * units
			height -= float(entry.get("geometry_ground_pixels", 19.0)) * units
			var painted := Vector3(centre.x - entry.pivot.x, entry.pivot.y - centre.y, 0.0) * units
			var view_depth: float = (height - (world.camera.global_basis * painted).y) / toward.y
			var direction := Vector3(normal.r, normal.g, normal.b) * 2.0 - Vector3.ONE
			result.append({"local": painted + Vector3(0, 0, view_depth),
				"normal": (normal_basis * direction.normalized()).normalized(),
				"uv": centre / Vector2(size), "pixel": pixel})
	return result
