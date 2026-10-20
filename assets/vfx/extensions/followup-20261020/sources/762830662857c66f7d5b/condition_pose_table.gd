extends RefCounted
## Exact immutable optical tables for the three explicitly opted-in kernels.
## No actor admission, material, clock or lifecycle state belongs in this cache.
const KINDS := ["forms", "support", "electric_contact"]
const LIMIT := 64
static var tables: Dictionary = {}
static var order: Array = []
static var builds := 0
static var hits := 0


static func key(surface: Dictionary, inverse: Transform3D, kind: String, settings: Dictionary) -> Array:
	var revision: Array = surface.get("gpu_geometry_key", [])
	# Absolute operands intentionally remain in the key. Reassociating world
	# transforms to remove translation would change native float32 reductions.
	return [] if revision.is_empty() else [revision, inverse, surface.get("origin", Vector3.ZERO), kind, settings]


static func obtain(surface: Dictionary, inverse: Transform3D, kind: String, settings: Dictionary, identity: Array) -> Dictionary:
	if not identity.is_empty() and tables.has(identity):
		hits += 1
		return tables[identity]
	var result := compile(surface, inverse, kind, settings)
	builds += 1
	if result.is_empty() or identity.is_empty():
		return result
	var frozen := identity.duplicate(true)
	tables[frozen] = result
	order.append(frozen)
	if order.size() > LIMIT:
		tables.erase(order.pop_front())
	return result


static func compile(surface: Dictionary, inverse: Transform3D, kind: String, settings: Dictionary) -> Dictionary:
	assert(kind in KINDS, "Only verified prepared optical kernels")
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var centre := Vector3.ZERO
	var normal := Vector3.ZERO
	var low := INF
	var high := -INF
	var allowed: Array = settings.get("geometry_slots", [])
	for point in surface.points:
		if not allowed.is_empty() and point.get("slot", "body") not in allowed:
			continue
		var position: Vector3 = inverse * point.position
		var direction: Vector3 = (inverse.basis * point.normal).normalized()
		positions.append(position)
		normals.append(direction)
		# Match the frozen source's order and Vector3 float32 reductions.
		centre += position
		normal += direction
		low = minf(low, position.y)
		high = maxf(high, position.y)
	if positions.size() < 8:
		return {}
	centre /= float(positions.size())
	if settings.has("fraction_min") or settings.has("fraction_max"):
		var minimum := float(settings.get("fraction_min", 0.))
		var maximum := float(settings.get("fraction_max", 1.))
		var selected_positions := PackedVector3Array()
		var selected_normals := PackedVector3Array()
		for index in positions.size():
			var fraction: float = (positions[index].y-low)/maxf(.001,high-low)
			if fraction >= minimum and fraction <= maximum:
				selected_positions.append(positions[index])
				selected_normals.append(normals[index])
		positions = selected_positions
		normals = selected_normals
		if positions.size() < 8:
			return {}
		centre = Vector3.ZERO
		for position in positions:
			centre += position
		centre /= float(positions.size())
	# The original normal intentionally includes all slot-admitted points,
	# before the optional height-fraction filter; do not "correct" that art.
	normal = normal.normalized()
	if normal.is_zero_approx():
		return {}
	var up := Vector3.UP.slide(normal).normalized()
	if up.is_zero_approx():
		up = Vector3.FORWARD.slide(normal).normalized()
	var side := normal.cross(up).normalized()
	var height_radius := .025
	var width_radius := .025
	for position in positions:
		height_radius = maxf(height_radius, absf((position-centre).dot(up)))
		width_radius = maxf(width_radius, absf((position-centre).dot(side)))
	var origin: Vector3 = inverse * surface.get("origin", Vector3.ZERO)
	var relative := origin if kind in ["support", "electric_contact"] else centre
	var values := PackedVector4Array()
	values.resize(positions.size()*2)
	for index in positions.size():
		var position := positions[index]-relative
		var direction := normals[index]
		values[index] = Vector4(position.x,position.y,position.z,1.)
		values[index+positions.size()] = Vector4(direction.x,direction.y,direction.z,1.)
	var image := Image.create_from_data(positions.size(),2,false,Image.FORMAT_RGBAF,values.to_byte_array())
	var result := {"count":positions.size(),"image":image,"origin":origin,"relative":relative,
		"centre":centre,"normal":normal,"up":up,"side":side,"low":low,"high":high,
		"height_radius":height_radius,"width_radius":width_radius}
	if kind == "support" and settings.get("vine_bounds",false):
		var left := INF
		var right := -INF
		for position in positions:
			var across: float = (position-origin).dot(side)
			left = minf(left,across)
			right = maxf(right,across)
		result.vine_left = left
		result.vine_right = right
	return result


static func immutable_texture(table: Dictionary) -> ImageTexture:
	if not table.has("texture"):
		table.texture = ImageTexture.create_from_image(table.image)
	return table.texture


static func clear() -> void:
	tables.clear()
	order.clear()
	builds = 0
	hits = 0
