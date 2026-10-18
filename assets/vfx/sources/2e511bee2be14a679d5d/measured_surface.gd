extends RefCounted
## Connected optical pixel footprints, not an axis-fit sword/cylinder. The
## reconstruction retains source pose, contour, normals and depth. Single-pixel
## shafts work, but isolated pixels and depth-discontinuous bridges do not.

const CACHE_LIMIT := 128
static var pose_meshes: Dictionary = {}
static var pose_order: Array = []
static var geometry_builds := 0

static func build(surface: Dictionary, slot: String, hand: Vector3, clearance_cells: float) -> Dictionary:
	var pose: Array = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd").from_surface(surface)
	var origin: Vector3 = surface.get("origin", Vector3.ZERO)
	if pose.is_empty():
		return _build(surface, slot, hand, clearance_cells)
	var key: Array = [surface.get("actor", ""), surface.get("item_uuid", ""), pose, slot, hand - origin, clearance_cells]
	if not pose_meshes.has(key):
		var measured := _build(surface, slot, hand, clearance_cells)
		pose_meshes[key.duplicate(true)] = {"measurement": measured, "origin": origin}
		pose_order.append(key.duplicate(true))
		if pose_order.size() > CACHE_LIMIT:
			pose_meshes.erase(pose_order.pop_front())
	var stored: Dictionary = pose_meshes[key]
	var result: Dictionary = stored.measurement.duplicate()
	var translation: Vector3 = origin - stored.origin
	result.base += translation
	result.tip += translation
	return result

static func _build(surface: Dictionary, slot: String, hand: Vector3, clearance_cells: float) -> Dictionary:
	geometry_builds += 1
	var chosen := {}
	var normal_sum := Vector3.ZERO
	for point in surface.get("points", []):
		if str(point.slot) == slot:
			chosen[point.pixel] = point
			normal_sum += point.normal
	var empty := {"mesh": ArrayMesh.new(), "cells": 0, "triangles": 0, "base": Vector3.ZERO, "tip": Vector3.ZERO}
	if chosen.size() < 2:
		return empty
	var selected := {}
	var horizontal := Vector3.ZERO
	var vertical := Vector3.ZERO
	var horizontal_count := 0
	var vertical_count := 0
	var diagonal_pixel := Vector2.ZERO
	var diagonal_world := Vector3.ZERO
	for pixel: Vector2i in chosen:
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
			Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]:
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
	if selected.size() < 2:
		return empty
	var normal := normal_sum.normalized()
	if horizontal_count > 0:
		horizontal /= float(horizontal_count)
	if vertical_count > 0:
		vertical /= float(vertical_count)
	if horizontal_count == 0 and vertical_count == 0 and not diagonal_pixel.is_zero_approx():
		# A 45-degree one-pixel shaft may touch only at corners. Its measured
		# tangent and normal supply a footprint without inventing a wider shaft.
		var tangent := diagonal_world.normalized()
		var transverse := tangent.cross(normal).normalized()
		var direction := diagonal_pixel.normalized()
		var pixel_cells := diagonal_world.length() / diagonal_pixel.length()
		horizontal = (tangent*direction.x - transverse*direction.y)*pixel_cells
		vertical = (tangent*direction.y + transverse*direction.x)*pixel_cells
		horizontal_count = 1
		vertical_count = 1
	# Missing width on a one-pixel shaft uses its actual surface tangent scale.
	# No unrelated fallback mesh appears when geometry is absent.
	if horizontal_count == 0:
		horizontal = vertical.cross(normal).normalized() * vertical.length()
	if vertical_count == 0:
		vertical = normal.cross(horizontal).normalized() * horizontal.length()
	if horizontal.is_zero_approx() or vertical.is_zero_approx():
		return empty
	var centre := Vector2.ZERO
	for pixel: Vector2i in selected:
		centre += Vector2(pixel)
	centre /= float(selected.size())
	var covariance := Vector3.ZERO
	for pixel: Vector2i in selected:
		var delta := Vector2(pixel) - centre
		covariance += Vector3(delta.x * delta.x, delta.x * delta.y, delta.y * delta.y)
	var angle := .5 * atan2(2.0 * covariance.y, covariance.x - covariance.z)
	var along := Vector2(cos(angle), sin(angle))
	var across := Vector2(-along.y, along.x)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var closest := Vector3.ZERO
	var farthest := Vector3.ZERO
	var closest_distance := INF
	var farthest_distance := -INF
	for pixel: Vector2i in selected:
		var projected := Vector2(Vector2(pixel).dot(across), Vector2(pixel).dot(along))
		low = low.min(projected)
		high = high.max(projected)
		var distance: float = selected[pixel].position.distance_squared_to(hand)
		if distance < closest_distance:
			closest = selected[pixel].position
			closest_distance = distance
		if distance > farthest_distance:
			farthest = selected[pixel].position
			farthest_distance = distance
	var extent := high - low + Vector2.ONE
	# UV2 follows the real weapon's long axis even through sideways attack poses.
	var low_world := Vector3.ZERO
	var high_world := Vector3.ZERO
	var min_projection := INF
	var max_projection := -INF
	for pixel: Vector2i in selected:
		var projection := Vector2(pixel).dot(along)
		if projection < min_projection:
			min_projection = projection
			low_world = selected[pixel].position
		if projection > max_projection:
			max_projection = projection
			high_world = selected[pixel].position
	var reverse := high_world.distance_squared_to(hand) < low_world.distance_squared_to(hand)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var texture_uv := PackedVector2Array()
	var motif_uv := PackedVector2Array()
	var colours := PackedColorArray()
	var origin: Vector3 = surface.origin
	var corners := [Vector2(-.5,-.5), Vector2(.5,-.5), Vector2(.5,.5), Vector2(-.5,.5)]
	for pixel: Vector2i in selected:
		var point: Dictionary = selected[pixel]
		for corner_index in [0, 1, 2, 0, 2, 3]:
			var corner: Vector2 = corners[corner_index]
			var source_position: Vector3 = point.position + horizontal * corner.x + vertical * corner.y
			var source_normal: Vector3 = point.normal
			var contributions := 1
			# Share positions at touching measured cell corners, only on this item
			# plane. A disconnected guard/shaft or a depth step never bridges.
			for offset in [Vector2i(int(signf(corner.x)),0), Vector2i(0,int(signf(corner.y))), Vector2i(int(signf(corner.x)),int(signf(corner.y)))]:
				if not selected.has(pixel + offset):
					continue
				var neighbor: Dictionary = selected[pixel + offset]
				if point.position.distance_to(neighbor.position) > .07:
					continue
				source_position += neighbor.position + horizontal * (corner.x - offset.x) + vertical * (corner.y - offset.y)
				source_normal += neighbor.normal
				contributions += 1
			source_normal = source_normal.normalized()
			vertices.append(source_position / float(contributions) - origin + source_normal * clearance_cells)
			normals.append(source_normal)
			var coordinate := Vector2(pixel) + corner
			var axis_uv := (Vector2(coordinate.dot(across), coordinate.dot(along)) - low + Vector2(.5,.5)) / extent
			if reverse:
				axis_uv.y = 1.0 - axis_uv.y
			texture_uv.append(axis_uv)
			motif_uv.append(axis_uv)
			var boundary := not selected.has(pixel + Vector2i.RIGHT) or not selected.has(pixel + Vector2i.LEFT) \
				or not selected.has(pixel + Vector2i.UP) or not selected.has(pixel + Vector2i.DOWN)
			colours.append(Color(1.0 if boundary else 0.0, 0.0, 0.0, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = texture_uv
	arrays[Mesh.ARRAY_TEX_UV2] = motif_uv
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh":mesh, "cells":selected.size(), "triangles":vertices.size()/3,
		"base":closest, "tip":farthest, "pixel_axes":[horizontal, vertical], "axis_extent":extent}
