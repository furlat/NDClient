extends RefCounted
## Stable interior anchors and short connected branches on the actual spill.
## Uses the original water density kernel; it never invents another footprint.
const ANCHOR_COUNT := 18
const EDGE_COUNT := 22


static func covered(point: Vector3, fluid: PackedVector4Array) -> bool:
	var density := 0.0
	for drop in fluid:
		var floor_weight := 1.0 - smoothstep(0.03, 0.09, drop.y)
		var distance := Vector2(point.x - drop.x, point.z - drop.z).length() / 0.26
		density += pow(maxf(0.0, 1.0 - distance * distance), 2.0) * floor_weight
	return density >= 0.66


static func layout(support: Array[Vector3], fluid: PackedVector4Array) -> Dictionary:
	var candidates: Array[Vector3] = []
	var centre := Vector3.ZERO
	for point in support:
		if covered(point, fluid):
			var flat := Vector3(point.x, 0.018, point.z)
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
	# Farthest-point sampling reaches the lobes as well as the centre. It is
	# deterministic and unrelated to screen angle or a synthetic circular rim.
	while points.size() < mini(ANCHOR_COUNT, candidates.size()):
		var farthest := -1
		var largest_gap := 0.000001
		for index in candidates.size():
			var gap := INF
			for chosen in points:
				gap = minf(gap, candidates[index].distance_squared_to(chosen))
			if gap > largest_gap:
				largest_gap = gap
				farthest = index
		if farthest < 0:
			break
		points.append(candidates[farthest])
	# Prim's tree connects nearby wet anchors rather than joining their angular
	# order into a perimeter. Extra short chords give the current local forks.
	var edges: Array[Vector2i] = []
	var connected: Array[int] = [0]
	while connected.size() < points.size():
		var nearest := Vector2i(-1, -1)
		var shortest := INF
		for source in connected:
			for target in points.size():
				if target in connected:
					continue
				var distance := points[source].distance_squared_to(points[target])
				if distance < shortest:
					shortest = distance
					nearest = Vector2i(source, target)
		if nearest.x < 0:
			break
		edges.append(nearest)
		connected.append(nearest.y)
	while edges.size() < EDGE_COUNT:
		var nearest := Vector2i(-1, -1)
		var shortest := INF
		for source in points.size():
			for target in range(source + 1, points.size()):
				if Vector2i(source, target) in edges or Vector2i(target, source) in edges:
					continue
				var distance := points[source].distance_squared_to(points[target])
				if distance < shortest:
					shortest = distance
					nearest = Vector2i(source, target)
		if nearest.x < 0:
			break
		edges.append(nearest)
	return {"points": points, "edges": edges}
