extends RefCounted
## Visible source-pixel union, including articulated limb gaps. Coordinates use
## actual reconstructed receiver positions; no oval/body-height approximation.

static func chains(points: Array) -> Array:
	var occupied := {}
	for point in points:
		occupied[point.pixel] = true
	var edges := {}
	for pixel: Vector2i in occupied:
		var centre := pixel * 2
		var corners := [centre + Vector2i(-1, -1), centre + Vector2i(1, -1),
			centre + Vector2i(1, 1), centre + Vector2i(-1, 1)]
		var neighbours := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		for side in 4:
			if occupied.has(pixel + neighbours[side]):
				continue
			var start: Vector2i = corners[side]
			if not edges.has(start):
				edges[start] = []
			edges[start].append(corners[(side + 1) % 4])
	var result := []
	while not edges.is_empty():
		var first: Vector2i = edges.keys()[0]
		var current := first
		var chain: Array[Vector2i] = [first]
		while edges.has(current):
			var next: Vector2i = edges[current].pop_back()
			if edges[current].is_empty():
				edges.erase(current)
			chain.append(next)
			current = next
			if current == first:
				break
		# Reject tiny optical validity pinholes, while keeping true limb gaps in
		# the exterior contour. Signed area separates exterior and interior loops.
		var signed_area := 0
		for index in range(1, chain.size()):
			signed_area += chain[index - 1].x * chain[index].y - chain[index].x * chain[index - 1].y
		if current == first and chain.size() >= 9 and signed_area > 0:
			result.append(chain)
	return result

static func frame(points: Array) -> Dictionary:
	var lookup := {}
	for point in points:
		lookup[point.pixel] = point
	var right := Vector3.ZERO
	var down := Vector3.ZERO
	var right_count := 0
	var down_count := 0
	for pixel: Vector2i in lookup:
		if lookup.has(pixel + Vector2i.RIGHT):
			right += lookup[pixel + Vector2i.RIGHT].position - lookup[pixel].position
			right_count += 1
		if lookup.has(pixel + Vector2i.DOWN):
			down += lookup[pixel + Vector2i.DOWN].position - lookup[pixel].position
			down_count += 1
	return {"lookup": lookup, "right": right / maxf(1, right_count), "down": down / maxf(1, down_count)}

static func corner(key: Vector2i, receiving_frame: Dictionary) -> Dictionary:
	var position := Vector3.ZERO
	var normal := Vector3.ZERO
	var count := 0
	for dx in [-1, 1]:
		for dy in [-1, 1]:
			var pixel := Vector2i((key.x + dx) / 2, (key.y + dy) / 2)
			if not receiving_frame.lookup.has(pixel):
				continue
			var point: Dictionary = receiving_frame.lookup[pixel]
			position += point.position - receiving_frame.right * float(dx) * .5 - receiving_frame.down * float(dy) * .5
			normal += point.normal
			count += 1
	assert(count > 0, "Contour corner lost its source support")
	return {"position": position / count, "normal": normal.normalized()}
