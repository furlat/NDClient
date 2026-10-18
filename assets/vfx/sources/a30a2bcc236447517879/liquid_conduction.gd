extends RefCounted
## Same source kernel and deterministic tie order; no full pairwise rescans.
const Original = preload("res://assets/vfx/sources/cf721dfb3774a72b8d38/liquid_conduction.gd")
const CELL_WIDTH := .26


static func _covered(point: Vector3, fluid: PackedVector4Array, buckets: Dictionary) -> bool:
	var cell := Vector2i(floori(point.x / CELL_WIDTH), floori(point.z / CELL_WIDTH))
	var indices: Array[int] = []
	for x in range(cell.x - 1, cell.x + 2):
		for z in range(cell.y - 1, cell.y + 2):
			indices.append_array(buckets.get(Vector2i(x, z), []))
	# Original accumulation order matters at the density threshold.
	indices.sort()
	var density := 0.0
	for index in indices:
		var drop := fluid[index]
		var floor_weight := 1.0 - smoothstep(.03, .09, drop.y)
		var distance := Vector2(point.x - drop.x, point.z - drop.z).length() / .26
		density += pow(maxf(0.0, 1.0 - distance * distance), 2.0) * floor_weight
	return density >= .66


static func layout(support: Array[Vector3], fluid: PackedVector4Array) -> Dictionary:
	var buckets := {}
	for index in fluid.size():
		var drop := fluid[index]
		var cell := Vector2i(floori(drop.x / CELL_WIDTH), floori(drop.z / CELL_WIDTH))
		if not buckets.has(cell):
			buckets[cell] = []
		buckets[cell].append(index)
	var candidates: Array[Vector3] = []
	var centre := Vector3.ZERO
	for point in support:
		if _covered(point, fluid, buckets):
			var flat := Vector3(point.x, .018, point.z)
			candidates.append(flat)
			centre += flat
	if candidates.size() < 2:
		return {"points": [], "edges": []}
	centre /= float(candidates.size())
	var first := 0
	for index in range(1, candidates.size()):
		if candidates[index].distance_squared_to(centre) < candidates[first].distance_squared_to(centre):
			first = index
	var points: Array[Vector3] = [candidates[first]]
	var gaps := PackedFloat64Array()
	gaps.resize(candidates.size())
	gaps.fill(INF)
	while points.size() < mini(Original.ANCHOR_COUNT, candidates.size()):
		var farthest := -1
		var largest_gap := .000001
		for index in candidates.size():
			gaps[index] = minf(gaps[index], candidates[index].distance_squared_to(points.back()))
			if gaps[index] > largest_gap:
				largest_gap = gaps[index]
				farthest = index
		if farthest < 0:
			break
		points.append(candidates[farthest])
	# Keep original connected-source order when distances tie.
	var edges: Array[Vector2i] = []
	var ranks := PackedInt32Array()
	ranks.resize(points.size())
	ranks.fill(-1)
	ranks[0] = 0
	var nearest_sources := PackedInt32Array()
	nearest_sources.resize(points.size())
	var distances := PackedFloat64Array()
	distances.resize(points.size())
	for target in points.size():
		distances[target] = points[0].distance_squared_to(points[target])
	var last := 0
	for rank in range(1, points.size()):
		var chosen := -1
		for target in points.size():
			if ranks[target] >= 0:
				continue
			var distance := points[last].distance_squared_to(points[target])
			if distance < distances[target]:
				distances[target] = distance
				nearest_sources[target] = last
			if chosen < 0 or distances[target] < distances[chosen] or (distances[target] == distances[chosen] and ranks[nearest_sources[target]] < ranks[nearest_sources[chosen]]):
				chosen = target
		edges.append(Vector2i(nearest_sources[chosen], chosen))
		ranks[chosen] = rank
		last = chosen
	var chords: Array = []
	for source in points.size():
		for target in range(source + 1, points.size()):
			if Vector2i(source, target) in edges or Vector2i(target, source) in edges:
				continue
			chords.append({"edge": Vector2i(source, target), "distance": points[source].distance_squared_to(points[target])})
	chords.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.distance != b.distance:
			return a.distance < b.distance
		return a.edge.x < b.edge.x or (a.edge.x == b.edge.x and a.edge.y < b.edge.y))
	for chord in chords:
		if edges.size() == Original.EDGE_COUNT:
			break
		edges.append(chord.edge)
	return {"points": points, "edges": edges}
