extends RefCounted
## Current optical pixel supports. Immutable indexed quads are prepared once;
## only measured points/topology and axes upload when the actual pose changes.
## The vertex shader retains MeasuredSurface's connected-corner reconstruction.
var entries: Array = []
var settings: Dictionary = {}
var texture: ImageTexture
var uploads := 0
var admitted_geometry := false
var last_key: Array = []
var weapon_binding: Dictionary = {}
var current_surface: Dictionary = {}
## Share immutable optical tables across effects using the same recipient pose.
## Eviction only releases this cache's reference; active materials retain theirs.
static var table_cache: Dictionary = {}
static var table_order: Array = []
const TABLE_CACHE_LIMIT := 64
var table_builds := 0
var cache_hits := 0


func set_weapon_binding(value: Dictionary) -> void:
	if weapon_binding == value:
		return
	weapon_binding = value.duplicate(true)
	last_key = []
	update(current_surface)


func configure(visual: Node3D, specification: Dictionary, geometry: Array) -> void:
	settings = specification.settings
	for entry in geometry:
		if entry.node.has_meta("condition_measured_template"):
			entries.append({"node": entry.node, "material": entry.node.material_override, "visual": visual, "kind": "measured"})
			entry.node.hide()
	assert(not entries.is_empty(), "Missing explicit measured source channel")


func update(surface: Dictionary) -> void:
	current_surface = surface
	if settings.get("requires_equipped_item", false):
		var admitted: bool = weapon_binding.get("present", false) and weapon_binding.get("observed", false) and weapon_binding.get("equipped", false) and not weapon_binding.get("suppressed", true)
		admitted = admitted and not str(weapon_binding.get("item_uuid", "")).is_empty()
		admitted = admitted and str(surface.get("item_uuid", "")) == str(weapon_binding.get("item_uuid", ""))
		admitted = admitted and str(surface.get("actor", "")) == str(weapon_binding.get("holder_uuid", ""))
		if not admitted:
			admitted_geometry = false
			last_key = []
			for entry in entries:
				entry.node.hide()
			return
	var identity: Array = surface.get("gpu_geometry_key", [])
	if admitted_geometry and not identity.is_empty() and identity == last_key:
		return
	admitted_geometry = false
	for entry in entries:
		entry.node.hide()
	last_key = []
	var inverse: Transform3D = entries[0].visual.global_transform.affine_inverse()
	var cache_key: Array = [surface.get("actor", ""), identity.duplicate(true), inverse,
		settings.slot, settings.get("fraction_min", .43), settings.get("fraction_max", .8),
		settings.get("capacity", 8192), weapon_binding.get("render_slot", settings.slot),
		inverse * weapon_binding.hand if weapon_binding.get("hand") is Vector3 else null]
	if not identity.is_empty() and table_cache.has(cache_key):
		apply_table(table_cache[cache_key])
		last_key = identity.duplicate(true)
		cache_hits += 1
		return
	var chosen := {}
	var low_height := INF
	var high_height := -INF
	for point in surface.get("points", []):
		if point.get("slot", "") in ["body", "chest", "cloak", "belt"]:
			low_height = minf(low_height, point.position.y)
			high_height = maxf(high_height, point.position.y)
	for point in surface.get("points", []):
		if not point.get("pixel") is Vector2i:
			continue
		if settings.slot == "recipient_patch":
			if point.get("slot", "") not in ["body", "chest", "cloak"]:
				continue
			var fraction: float = (point.position.y - low_height) / maxf(.001, high_height - low_height)
			if fraction < float(settings.get("fraction_min", .43)) or fraction > float(settings.get("fraction_max", .8)):
				continue
		elif point.get("slot", "") != weapon_binding.get("render_slot", settings.slot):
			continue
		chosen[point.pixel] = {"position": inverse * point.position,
			"normal": (inverse.basis * point.normal).normalized()}
	var selected := {}
	var horizontal := Vector3.ZERO
	var vertical := Vector3.ZERO
	var horizontal_count := 0
	var vertical_count := 0
	var normal := Vector3.ZERO
	var diagonal_pixel := Vector2.ZERO
	var diagonal_world := Vector3.ZERO
	var directions := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP,
		Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]
	for pixel: Vector2i in chosen:
		normal += chosen[pixel].normal
		for direction in directions:
			if not chosen.has(pixel + direction):
				continue
			var difference: Vector3 = chosen[pixel + direction].position - chosen[pixel].position
			if difference.length() > .07 or difference.length() < .00001:
				continue
			selected[pixel] = chosen[pixel]
			if direction == Vector2i.RIGHT:
				horizontal += difference
				horizontal_count += 1
			elif direction == Vector2i.DOWN:
				vertical += difference
				vertical_count += 1
			elif diagonal_pixel.is_zero_approx():
				diagonal_pixel = Vector2(direction)
				diagonal_world = difference
	if selected.size() < 2 or selected.size() > int(settings.get("capacity", 8192)):
		return
	normal = normal.normalized()
	if horizontal_count > 0:
		horizontal /= float(horizontal_count)
	if vertical_count > 0:
		vertical /= float(vertical_count)
	if horizontal_count == 0 and vertical_count == 0 and not diagonal_pixel.is_zero_approx():
		var tangent := diagonal_world.normalized()
		var transverse := tangent.cross(normal).normalized()
		var direction := diagonal_pixel.normalized()
		var size := diagonal_world.length() / diagonal_pixel.length()
		horizontal = (tangent * direction.x - transverse * direction.y) * size
		vertical = (tangent * direction.y + transverse * direction.x) * size
		horizontal_count = 1
		vertical_count = 1
	if horizontal_count == 0:
		horizontal = vertical.cross(normal).normalized() * vertical.length()
	if vertical_count == 0:
		vertical = normal.cross(horizontal).normalized() * horizontal.length()
	if horizontal.is_zero_approx() or vertical.is_zero_approx():
		return
	var centre := Vector2.ZERO
	var keys := selected.keys()
	var indices := {}
	for index in keys.size():
		indices[keys[index]] = index
		centre += Vector2(keys[index])
	centre /= float(keys.size())
	var covariance := Vector3.ZERO
	for pixel: Vector2i in keys:
		var delta := Vector2(pixel) - centre
		covariance += Vector3(delta.x * delta.x, delta.x * delta.y, delta.y * delta.y)
	var angle := .5 * atan2(2.0 * covariance.y, covariance.x - covariance.z)
	var along := Vector2(cos(angle), sin(angle))
	var across := Vector2(-along.y, along.x)
	var low := Vector2(INF, INF)
	var high := -low
	for pixel: Vector2i in keys:
		var projected := Vector2(Vector2(pixel).dot(across), Vector2(pixel).dot(along))
		low = low.min(projected)
		high = high.max(projected)
	var reverse := false
	if weapon_binding.get("hand") is Vector3:
		var low_point := Vector3.ZERO
		var high_point := Vector3.ZERO
		var min_projection := INF
		var max_projection := -INF
		for pixel: Vector2i in keys:
			var projection := Vector2(pixel).dot(along)
			if projection < min_projection:
				min_projection = projection
				low_point = selected[pixel].position
			if projection > max_projection:
				max_projection = projection
				high_point = selected[pixel].position
		var hand: Vector3 = inverse * weapon_binding.hand
		reverse = high_point.distance_squared_to(hand) < low_point.distance_squared_to(hand)
	var image := Image.create_empty(keys.size(), 5, false, Image.FORMAT_RGBAF)
	for index in keys.size():
		var pixel: Vector2i = keys[index]
		var point: Dictionary = selected[pixel]
		image.set_pixel(index, 0, Color(point.position.x, point.position.y, point.position.z, 1))
		image.set_pixel(index, 1, Color(point.normal.x, point.normal.y, point.normal.z, 1))
		image.set_pixel(index, 2, Color(pixel.x, pixel.y, 0, 0))
		var neighbors := []
		for direction in directions:
			var neighbor := -1
			if selected.has(pixel + direction) and point.position.distance_to(selected[pixel + direction].position) <= .07:
				neighbor = int(indices[pixel + direction])
			neighbors.append(float(neighbor))
		image.set_pixel(index, 3, Color(neighbors[0], neighbors[1], neighbors[2], neighbors[3]))
		image.set_pixel(index, 4, Color(neighbors[4], neighbors[5], neighbors[6], neighbors[7]))
	var table := {"texture": ImageTexture.create_from_image(image), "count": keys.size(),
		"horizontal": horizontal, "vertical": vertical, "along": along, "across": across,
		"low": low, "extent": high - low + Vector2.ONE, "reverse": reverse}
	table_builds += 1
	if not identity.is_empty():
		table_cache[cache_key] = table
		table_order.append(cache_key)
		while table_order.size() > TABLE_CACHE_LIMIT:
			table_cache.erase(table_order.pop_front())
	apply_table(table)
	last_key = identity.duplicate(true)


func apply_table(table: Dictionary) -> void:
	texture = table.texture
	for entry in entries:
		var material: ShaderMaterial = entry.material
		material.set_shader_parameter("vfx_measured_points", texture)
		material.set_shader_parameter("vfx_measured_count", table.count)
		material.set_shader_parameter("vfx_measured_horizontal", table.horizontal)
		material.set_shader_parameter("vfx_measured_vertical", table.vertical)
		material.set_shader_parameter("vfx_measured_along", table.along)
		material.set_shader_parameter("vfx_measured_across", table.across)
		material.set_shader_parameter("vfx_measured_low", table.low)
		material.set_shader_parameter("vfx_measured_extent", table.extent)
		material.set_shader_parameter("vfx_measured_clearance", float(settings.get("clearance_cells", .012)))
		material.set_shader_parameter("vfx_measured_reverse", table.reverse)
		entry.node.show()
	admitted_geometry = true
	uploads += 1
