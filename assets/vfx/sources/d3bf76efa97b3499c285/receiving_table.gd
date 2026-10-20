extends RefCounted
## Immutable optical support tables shared by actual pose identity. Clocks,
## materials and actor/event admission remain occurrence-private.
const Frame = preload("res://assets/vfx/sources/02d90ce9caaa3a5e1100/receiving_frame.gd")
const GeometryKey = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd")
const LIMIT := 64
static var tables: Dictionary = {}
static var order: Array = []
static var builds := 0
static var hits := 0

static func local_frame(frame: Dictionary, origin: Vector3) -> Dictionary:
	var result := frame.duplicate(false)
	result.erase("points")
	result.centre -= origin
	result.top -= origin.y
	result.bottom -= origin.y
	result.origin = Vector3.ZERO
	return result

static func world_frame(frame: Dictionary, surface: Dictionary) -> Dictionary:
	var result := frame.duplicate(false)
	result.centre += surface.origin
	result.top += surface.origin.y
	result.bottom += surface.origin.y
	result.origin = surface.origin
	result.points = surface.points
	return result

static func obtain(surface: Dictionary, chest: bool) -> Dictionary:
	var revision: Array = GeometryKey.from_surface(surface)
	var key := [revision, chest]
	if not revision.is_empty() and tables.has(key):
		hits += 1
		return tables[key]
	var full: Dictionary = Frame.measure(surface)
	if full.is_empty():
		return {}
	var receiving: Dictionary = full
	if chest:
		var points: Array = full.points.filter(func(point: Dictionary) -> bool: return str(point.get("slot", "")) == "chest")
		if points.size() < 8:
			points = full.points.filter(func(point: Dictionary) -> bool: return str(point.get("slot", "")) == "body")
		receiving = Frame.measure({"points": points, "actor": surface.actor, "origin": surface.origin})
		if receiving.is_empty():
			return {}
	var image := Image.create(receiving.points.size(), 3, false, Image.FORMAT_RGBAF)
	for index in receiving.points.size():
		var position: Vector3 = receiving.points[index].position - surface.origin
		var normal: Vector3 = receiving.points[index].normal
		image.set_pixel(index, 0, Color(position.x, position.y, position.z, 1.))
		image.set_pixel(index, 1, Color(normal.x, normal.y, normal.z, 1.))
		image.set_pixel(index, 2, Color((receiving.points[index].position - receiving.centre).dot(receiving.side), position.y, 0.0, 0.0))
	var result := {"full": local_frame(full, surface.origin), "receiving": local_frame(receiving, surface.origin),
		"count": receiving.points.size(), "queries": {}, "texture": ImageTexture.create_from_image(image)}
	builds += 1
	if not revision.is_empty():
		tables[key.duplicate(true)] = result
		order.append(key.duplicate(true))
		if order.size() > LIMIT:
			tables.erase(order.pop_front())
	return result

## Static support queries retain their source double-precision coordinates.
## Float shader arithmetic otherwise chooses a different fourth neighbour at
## a tie, creating millimetres of movement despite almost equal distances.
static func fixed_queries(table: Dictionary, kind: int) -> Texture2D:
	if kind not in [1, 3]:
		return null
	if table.queries.has(kind):
		return table.queries[kind]
	var frame: Dictionary = table.receiving
	var values := []
	for piece in 6:
		var parity := -1.0 if piece % 2 == 0 else 1.0
		var tier := float(piece / 2)
		for station in (1 if kind == 1 else 25):
			var u := float(station) / 24.0
			var across: float = parity * frame.half_width * (.65 if kind == 1 else .95 - .32 * (1.0 - absf(u * 2.0 - 1.0)))
			var elevation: float = frame.bottom + frame.height * (.72 - tier * .06 if kind == 1 else .39 + tier * .19 + (u - .5) * .12)
			var high := PackedFloat32Array([across, elevation])
			values.append(Color(high[0], across - high[0], high[1], elevation - high[1]))
	var image := Image.create(values.size(), 1, false, Image.FORMAT_RGBAF)
	for index in values.size():
		image.set_pixel(index, 0, values[index])
	var texture := ImageTexture.create_from_image(image)
	table.queries[kind] = texture
	return texture

## Six feather roots are static in an actual pose. Preserve the CPU source's
## exact tie ordering once per new immutable pose; animate the feathers on GPU.
static func holy_roots(table: Dictionary, surface: Dictionary) -> Texture2D:
	if table.queries.has("holy_roots"):
		return table.queries.holy_roots
	var frame := world_frame(table.full, surface)
	var image := Image.create(6, 2, false, Image.FORMAT_RGBAF)
	for piece in 6:
		var parity := -1.0 if piece % 2 == 0 else 1.0
		var tier := float(piece / 2)
		var support: Dictionary = Frame.support(frame, parity * frame.half_width * .65, frame.bottom + frame.height * (.72 - tier * .06))
		var position: Vector3 = support.position - surface.origin
		var normal: Vector3 = support.normal
		image.set_pixel(piece, 0, Color(position.x, position.y, position.z, 1.))
		image.set_pixel(piece, 1, Color(normal.x, normal.y, normal.z, 1.))
	var texture := ImageTexture.create_from_image(image)
	table.queries.holy_roots = texture
	return texture
