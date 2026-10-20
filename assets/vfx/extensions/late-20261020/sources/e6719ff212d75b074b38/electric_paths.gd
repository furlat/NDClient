extends RefCounted
## Geometry-only port of the accepted electric-live-study ribbon construction.
## The exported native arc material is reused along these paths. Endpoints,
## branches and range come from gameplay; no target configuration is baked.
static func jagged(a: Vector3, b: Vector3, random: RandomNumberGenerator, spread: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var delta: Vector3 = b - a
	var side: Vector3 = delta.normalized().cross(Vector3.UP).normalized()
	if side.is_zero_approx(): side = Vector3.RIGHT
	var count: int = maxi(2, ceili(delta.length() / 0.23))
	for index in range(count + 1):
		var ratio: float = float(index) / count
		var envelope: float = sin(ratio * PI)
		points.append(a.lerp(b, ratio) + side * random.randf_range(-spread, spread) * envelope + Vector3.UP * random.randf_range(-spread, spread) * envelope)
	points[0] = a
	points[count] = b
	return points

static func chain(nodes: Array[Vector3], edges: Array, seed_value: int) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var paths: Array = []
	for edge_index in edges.size():
		var edge: Array = edges[edge_index]
		assert(edge.size() == 2 and edge[0] < nodes.size() and edge[1] < nodes.size())
		var points: Array[Vector3] = jagged(nodes[edge[0]], nodes[edge[1]], random, 0.23)
		paths.append({"points": points, "width": 0.52, "role": "link", "edge": edge_index})
	return paths

static func heavy_bolt(start: Vector3, end: Vector3, seed_value: int) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var length: float = start.distance_to(end)
	assert(length > 0.0)
	var axis: Vector3 = (end - start).normalized()
	var side: Vector3 = axis.cross(Vector3.UP).normalized()
	if side.is_zero_approx():side = Vector3.RIGHT
	var count: int = maxi(18, ceili(length / 0.23))
	var paths: Array = []
	for core in range(5):
		var points: Array[Vector3] = []
		for index in range(count + 1):
			var ratio: float = float(index) / count
			var spread: float = smoothstep(0.0, 0.055, ratio) * (1.0 - 0.4 * smoothstep(0.9, 1.0, ratio))
			var lateral: float = ((core - 2) * 0.125 + random.randf_range(-0.085, 0.085)) * spread
			var vertical: float = ((1.0 if core % 2 else -1.0) * 0.15 + random.randf_range(-0.115, 0.115)) * spread
			points.append(start.lerp(end, ratio) + side * lateral + Vector3.UP * vertical)
		points[0] = start
		points[count] = end
		paths.append({"points": points, "width": 1.18 if core == 0 else 0.52, "power": 0.7 if core == 0 else 0.64, "role": "link"})
	for index in ceili(length * 1.8):
		var anchor: int = 2 + random.randi_range(0, count - 5)
		var a: Vector3 = paths[index % 5].points[anchor]
		var b: Vector3 = paths[(index + 2) % 5].points[mini(count, anchor + 1)]
		paths.append({"points": jagged(a, b, random, 0.09), "width": 0.20, "power": 0.58, "role": "fork", "attach": float(anchor) / count})
	return paths
