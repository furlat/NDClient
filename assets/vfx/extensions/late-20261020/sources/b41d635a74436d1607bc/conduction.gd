extends RefCounted
## Exact current-liquid-domain lowering. Every admitted support point is an
## actual fluid ordinal with y < .03: its self kernel is 1, already above .66.
## All other finite density terms are nonnegative. Preserve source selection,
## float32 vector accumulation, ordinals and ties; no sampled/coarse footprint.
const Source = preload("res://assets/vfx/extensions/late-20261020/sources/a30a2bcc236447517879/liquid_conduction.gd")
const Original = preload("res://assets/vfx/extensions/late-20261020/sources/cf721dfb3774a72b8d38/liquid_conduction.gd")

static func layout(fluid: PackedVector4Array) -> Dictionary:
	var support: Array[Vector3] = []
	var finite := true
	for drop in fluid:
		finite = finite and drop.is_finite()
		if drop.y < .03: support.append(Vector3(drop.x,drop.y,drop.z))
	return layout_from_actual_support(support,fluid,finite)

static func layout_from_actual_support(support: Array[Vector3], fluid: PackedVector4Array, finite: bool) -> Dictionary:
	# The caller already extracted precisely these source ordinals while
	# updating the actual160-particle field. No second field/support scan.
	if not finite: return Source.layout(support,fluid)
	var candidates: Array[Vector3] = []
	var centre := Vector3.ZERO
	for point in support:
		var flat := Vector3(point.x,.018,point.z)
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
		var newest: Vector3 = points.back()
		for index in candidates.size():
			var gap: float = gaps[index]
			var distance := candidates[index].distance_squared_to(newest)
			if distance < gap:
				gap = distance
				gaps[index] = gap
			if gap > largest_gap:
				largest_gap = gap
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
		var newest: Vector3 = points[last]
		for target in points.size():
			if ranks[target] >= 0:
				continue
			var distance := newest.distance_squared_to(points[target])
			if distance < distances[target]:
				distances[target] = distance
				nearest_sources[target] = last
			if chosen < 0 or distances[target] < distances[chosen] or (distances[target] == distances[chosen] and ranks[nearest_sources[target]] < ranks[nearest_sources[chosen]]):
				chosen = target
		edges.append(Vector2i(nearest_sources[chosen], chosen))
		ranks[chosen] = rank
		last = chosen
	var adjacent := PackedInt32Array()
	adjacent.resize(points.size())
	for edge in edges:
		adjacent[edge.x] |= 1 << edge.y
		adjacent[edge.y] |= 1 << edge.x
	var chords: Array[Vector3] = []
	for source in points.size():
		for target in range(source + 1, points.size()):
			if adjacent[source] & (1 << target):
				continue
			chords.append(Vector3(points[source].distance_squared_to(points[target]), source, target))
	# Vector3's native lexicographic comparator is exactly the old comparator:
	# native-real distance, source ordinal, target ordinal. All tuples are
	# unique. This avoids hundreds of GDScript Dictionary comparator calls.
	chords.sort()
	for chord in chords:
		if edges.size() == Original.EDGE_COUNT:
			break
		edges.append(Vector2i(int(chord.y), int(chord.z)))
	return {"points": points, "edges": edges}
