extends RefCounted
## Pose-local bounded-grid candidate search. Final distances retain the source
## equations and equal-distance ties retain the legacy ordering. No sampling,
## nearest-query result, owner, material or clock is held in this index.
var points: Array = []
var frame_centre := Vector3.ZERO
var frame_side := Vector3.ZERO
var frame_up := Vector3.ZERO
var tangent := false
var horizontal := PackedFloat64Array()
var vertical := PackedFloat64Array()
var cells: Array = []
var columns := 4
var minimum_x := INF
var minimum_y := INF
var maximum_x := -INF
var maximum_y := -INF
var step_x := 1.0
var step_y := 1.0
var coordinate_scale := 1.0
var visited_last_query := 0


static func obtain(frame: Dictionary, tangent_query: bool) -> RefCounted:
	var indices: Dictionary = frame.get("_support_query_indexes", {})
	if indices.has(tangent_query):
		var previous: RefCounted = indices[tangent_query]
		if not is_same(previous.points, frame.points) or previous.frame_centre != frame.centre \
				or previous.frame_side != frame.side or previous.frame_up != frame.up:
			# A shallow diagnostic/local-frame copy must not mutate its sibling's
			# index or retain the sibling's world points after translation.
			indices = indices.duplicate(false)
			indices.erase(tangent_query)
	if not indices.has(tangent_query):
		var index: RefCounted = VfxPackageIO_7861b47ba3.resource("res://assets/vfx/sources/7861b47ba3b77bbd762a/support_query_index.gd").new()
		index.build(frame, tangent_query)
		indices[tangent_query] = index
		frame._support_query_indexes = indices
	return indices[tangent_query]


func build(frame: Dictionary, tangent_query: bool) -> void:
	points = frame.points
	frame_centre = frame.centre
	frame_side = frame.side
	frame_up = frame.up
	tangent = tangent_query
	for ordinal in points.size():
		var position: Vector3 = points[ordinal].position
		var delta := position - frame_centre
		var across := delta.dot(frame_side)
		var rise := delta.dot(frame_up) if tangent else position.y
		horizontal.append(across)
		vertical.append(rise)
		minimum_x = minf(minimum_x, across)
		maximum_x = maxf(maximum_x, across)
		minimum_y = minf(minimum_y, rise)
		maximum_y = maxf(maximum_y, rise)
		coordinate_scale = maxf(coordinate_scale, maxf(absf(position.x), maxf(absf(position.y), absf(position.z))))
	columns = clampi(ceili(sqrt(float(points.size()) / 4.0)), 4, 64)
	step_x = maxf((maximum_x - minimum_x) / float(columns), .00001)
	step_y = maxf((maximum_y - minimum_y) / float(columns), .00001)
	for index in columns * columns:
		cells.append([])
	for ordinal in points.size():
		var column := clampi(floori((horizontal[ordinal] - minimum_x) / step_x), 0, columns - 1)
		var row := clampi(floori((vertical[ordinal] - minimum_y) / step_y), 0, columns - 1)
		cells[row * columns + column].append(ordinal)


func nearest(centre: Vector3, across: float, rise: float) -> Dictionary:
	var relative := centre - frame_centre
	var query_x := across + relative.dot(frame_side) if tangent else across
	var query_y := rise + relative.dot(frame_up) if tangent else rise
	# The reordered index projections prune only distant cells. Final distances
	# below use the original subtraction/dot equations. Conservative padding
	# covers single-precision Vector3 projection/cancellation at large origins.
	var magnitude := maxf(coordinate_scale, maxf(absf(centre.x), maxf(absf(centre.y), absf(centre.z))))
	var padding := 64.0 * 1.1920928955078125e-7 * (magnitude + absf(across) + absf(rise) + 1.0)
	var result := {"indices": [], "distances": [], "ambiguous": false}
	var column := clampi(floori((query_x - minimum_x) / step_x), 0, columns - 1)
	var row := clampi(floori((query_y - minimum_y) / step_y), 0, columns - 1)
	visited_last_query = 0
	for radius in columns:
		var left := maxi(0, column - radius)
		var right := mini(columns - 1, column + radius)
		var bottom := maxi(0, row - radius)
		var top := mini(columns - 1, row + radius)
		for y in range(bottom, top + 1):
			for x in range(left, right + 1):
				if radius > 0 and absi(x - column) < radius and absi(y - row) < radius:
					continue
				_visit(x, y, query_x, query_y, padding, centre, across, rise, result)
		if result.indices.size() == 4:
			var remaining := INF
			if left > 0:
				remaining = minf(remaining, pow(maxf(0.0, query_x - (minimum_x + left * step_x) - padding), 2.0))
			if right < columns - 1:
				remaining = minf(remaining, pow(maxf(0.0, minimum_x + (right + 1) * step_x - query_x - padding), 2.0))
			if bottom > 0:
				remaining = minf(remaining, pow(maxf(0.0, query_y - (minimum_y + bottom * step_y) - padding), 2.0))
			if top < columns - 1:
				remaining = minf(remaining, pow(maxf(0.0, minimum_y + (top + 1) * step_y - query_y - padding), 2.0))
			if remaining > float(result.distances[-1]):
				break
	for index in range(1, result.distances.size()):
		if result.distances[index] == result.distances[index - 1]:
			result.ambiguous = true
	return result


func _visit(column: int, row: int, query_x: float, query_y: float, padding: float,
		centre: Vector3, across: float, rise: float, result: Dictionary) -> void:
	var low_x := minimum_x + column * step_x
	var low_y := minimum_y + row * step_y
	var dx := maxf(0.0, maxf(low_x - query_x, query_x - low_x - step_x) - padding)
	var dy := maxf(0.0, maxf(low_y - query_y, query_y - low_y - step_y) - padding)
	if result.indices.size() == 4 and dx * dx + dy * dy > float(result.distances[-1]):
		return
	for ordinal in cells[row * columns + column]:
		visited_last_query += 1
		var point: Dictionary = points[ordinal]
		var delta: Vector3 = point.position - centre
		var distance := pow(delta.dot(frame_side) - across, 2.0)
		distance += pow(delta.dot(frame_up) - rise, 2.0) if tangent else pow(point.position.y - rise, 2.0)
		var at := 0
		while at < result.distances.size() and float(result.distances[at]) < distance:
			at += 1
		if at < result.distances.size() and float(result.distances[at]) == distance:
			result.ambiguous = true
		if at < 4:
			result.indices.insert(at, ordinal)
			result.distances.insert(at, distance)
			if result.indices.size() > 4:
				result.indices.pop_back()
				result.distances.pop_back()

const VfxPackageIO_7861b47ba3 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
