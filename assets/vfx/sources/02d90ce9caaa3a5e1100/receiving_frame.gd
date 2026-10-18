extends RefCounted
## Measured current receiving support; no canonical body dimensions or rules.


static func measure(surface: Dictionary) -> Dictionary:
	var points: Array = surface.get("points", [])
	if points.size() < 8:
		return {}
	var centre := Vector3.ZERO
	var normal := Vector3.ZERO
	var low := INF
	var high := -INF
	for point in points:
		centre += point.position
		normal += point.normal
		low = minf(low, point.position.y)
		high = maxf(high, point.position.y)
	centre /= float(points.size())
	normal = normal.normalized()
	if normal.is_zero_approx() or high - low < .015:
		return {}
	var up := Vector3.UP.slide(normal).normalized()
	if up.is_zero_approx():
		return {}
	var side := normal.cross(up).normalized()
	var half_width := .0
	for point in points:
		half_width = maxf(half_width, absf((point.position - centre).dot(side)))
	return {"points":points,"origin":surface.origin,"centre":centre,"normal":normal,"up":up,"side":side,
		"top":high,"bottom":low,"height":high-low,"half_width":half_width,"actor":surface.actor}


static func support(frame: Dictionary, across_cells: float, elevation_cells: float) -> Dictionary:
	var cached: Dictionary=frame.get("_support_cache",{})
	var cache_key: Vector2=Vector2(across_cells,elevation_cells-frame.origin.y)
	if cached.has(cache_key):
		return {"position":cached[cache_key][0]+frame.origin,"normal":cached[cache_key][1]}
	var neighbours := []
	for point in frame.points:
		var delta: Vector3 = point.position - frame.centre
		var distance := pow(delta.dot(frame.side) - across_cells, 2.0) + pow(point.position.y - elevation_cells, 2.0)
		if neighbours.size() < 4 or distance < float(neighbours.back().distance):
			neighbours.append({"point":point,"distance":distance})
			neighbours.sort_custom(func(first:Dictionary,second:Dictionary)->bool:return first.distance<second.distance)
			if neighbours.size() > 4:
				neighbours.pop_back()
	var position := Vector3.ZERO
	var normal := Vector3.ZERO
	var weight := .0
	for neighbour in neighbours:
		var contribution := 1.0 / (float(neighbour.distance) + .00015)
		position += neighbour.point.position * contribution
		normal += neighbour.point.normal * contribution
		weight += contribution
	var result: Dictionary={"position":position/weight,"normal":normal.normalized()}
	if cached.size()>1024:cached.clear()
	cached[cache_key]=[result.position-frame.origin,result.normal]
	frame._support_cache=cached
	return result


static func tangent_support(frame: Dictionary, centre: Vector3, across: float, rise: float) -> Dictionary:
	var cached: Dictionary=frame.get("_tangent_cache",{})
	var cache_key: Array=[centre-frame.origin,across,rise]
	if cached.has(cache_key):
		return {"position":cached[cache_key][0]+frame.origin,"normal":cached[cache_key][1]}
	var neighbours: Array = []
	for point in frame.points:
		var delta: Vector3 = point.position-centre
		var distance: float = pow(delta.dot(frame.side)-across,2.0)+pow(delta.dot(frame.up)-rise,2.0)
		neighbours.append({"point":point,"distance":distance})
	neighbours.sort_custom(func(first:Dictionary,second:Dictionary)->bool:return first.distance<second.distance)
	var position: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.ZERO
	var weight: float = .0
	for index in mini(4,neighbours.size()):
		var contribution: float = 1.0/(float(neighbours[index].distance)+.00015)
		position += neighbours[index].point.position*contribution
		normal += neighbours[index].point.normal*contribution
		weight += contribution
	position /= weight
	# Preserve the requested source UV grid and its tangent axes. Only the
	# measured normal-space depth varies; a prone chest cannot collapse a cross
	# into a vertical-Y nearest-neighbour fan.
	position += frame.side*(across-(position-centre).dot(frame.side))
	position += frame.up*(rise-(position-centre).dot(frame.up))
	var result: Dictionary={"position":position,"normal":normal.normalized()}
	if cached.size()>1024:cached.clear()
	cached[cache_key]=[position-frame.origin,result.normal]
	frame._tangent_cache=cached
	return result
