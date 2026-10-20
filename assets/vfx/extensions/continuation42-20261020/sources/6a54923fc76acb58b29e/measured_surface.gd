extends RefCounted
## Exact original cold reduction; deduplicate identical corner operations only.
## No new axis, geometry source, layout/actor recording or shader is introduced.
const CORNERS := [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]
const NEIGHBORS := [
	[Vector2i(-1,0),Vector2i(0,-1),Vector2i(-1,-1)],
	[Vector2i(1,0),Vector2i(0,-1),Vector2i(1,-1)],
	[Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)],
	[Vector2i(-1,0),Vector2i(0,1),Vector2i(-1,1)],
]
const TRIANGLE_ORDER := [0,1,2,0,2,3]
static var geometry_builds := 0
const Original = preload("res://assets/vfx/sources/2e511bee2be14a679d5d/measured_surface.gd")
const GeometryKey = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd")

static func build(surface: Dictionary, slot: String, hand: Vector3, clearance_cells: float) -> Dictionary:
	# Retain the existing public cache/key/return semantics, including its
	# documented relative-hand translation approximation. Only cold geometry
	# construction changes. Actual renderer input/support is never pre-baked.
	var pose := GeometryKey.from_surface(surface)
	var origin: Vector3 = surface.get("origin",Vector3.ZERO)
	if pose.is_empty():
		Original.geometry_builds += 1
		return _build(surface,slot,hand,clearance_cells)
	var key: Array = [surface.get("actor",""),surface.get("item_uuid",""),pose,slot,hand-origin,clearance_cells]
	if not Original.pose_meshes.has(key):
		Original.geometry_builds += 1
		var measured := _build(surface,slot,hand,clearance_cells)
		Original.pose_meshes[key.duplicate(true)] = {"measurement":measured,"origin":origin}
		Original.pose_order.append(key.duplicate(true))
		if Original.pose_order.size() > Original.CACHE_LIMIT:
			Original.pose_meshes.erase(Original.pose_order.pop_front())
	var stored: Dictionary = Original.pose_meshes[key]
	var result: Dictionary = stored.measurement.duplicate()
	var translation: Vector3 = origin-stored.origin
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
		var has_connected_neighbor := false
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
			Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]:
			if not chosen.has(pixel + direction):
				continue
			var difference: Vector3 = chosen[pixel + direction].position - chosen[pixel].position
			var edge_length := difference.length()
			if edge_length > .07 or edge_length < .00001:
				continue
			has_connected_neighbor = true
			if direction == Vector2i.RIGHT:
				horizontal += difference
				horizontal_count += 1
			elif direction == Vector2i.DOWN:
				vertical += difference
				vertical_count += 1
			elif diagonal_pixel.is_zero_approx():
				diagonal_pixel = Vector2(direction)
				diagonal_world = difference
		if has_connected_neighbor:
			selected[pixel] = chosen[pixel]
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
	# The original six triangle vertices repeat corners0/2. Evaluate each
	# identical corner once, keeping every native f32 operation/order, then
	# expand the unchanged triangle order. Half-axis products depend only on
	# this source mesh, not on a pixel, so retain those exact products once.
	var horizontal_terms := PackedVector3Array()
	var vertical_terms := PackedVector3Array()
	for corner_index in 4:
		var corner: Vector2 = CORNERS[corner_index]
		horizontal_terms.append(horizontal*corner.x)
		vertical_terms.append(vertical*corner.y)
		for offset: Vector2i in NEIGHBORS[corner_index]:
			horizontal_terms.append(horizontal*(corner.x-offset.x))
			vertical_terms.append(vertical*(corner.y-offset.y))
	var corner_positions := PackedVector3Array()
	var corner_normals := PackedVector3Array()
	var corner_uv := PackedVector2Array()
	corner_positions.resize(4)
	corner_normals.resize(4)
	corner_uv.resize(4)
	for pixel: Vector2i in selected:
		var point: Dictionary = selected[pixel]
		var boundary := not selected.has(pixel + Vector2i.RIGHT) or not selected.has(pixel + Vector2i.LEFT) \
			or not selected.has(pixel + Vector2i.UP) or not selected.has(pixel + Vector2i.DOWN)
		var colour := Color(1.0 if boundary else 0.0,0.0,0.0,1.0)
		for corner_index in 4:
			var corner: Vector2 = CORNERS[corner_index]
			var term := corner_index*4
			var source_position: Vector3 = point.position + horizontal_terms[term] + vertical_terms[term]
			var source_normal: Vector3 = point.normal
			var contributions := 1
			# Same original X,Y,diagonal order and same source distance gate.
			for neighbor_index in 3:
				var offset: Vector2i = NEIGHBORS[corner_index][neighbor_index]
				if not selected.has(pixel + offset):
					continue
				var neighbor: Dictionary = selected[pixel + offset]
				if point.position.distance_to(neighbor.position) > .07:
					continue
				source_position += neighbor.position + horizontal_terms[term+neighbor_index+1] + vertical_terms[term+neighbor_index+1]
				source_normal += neighbor.normal
				contributions += 1
			source_normal = source_normal.normalized()
			corner_positions[corner_index] = source_position / float(contributions) - origin + source_normal * clearance_cells
			corner_normals[corner_index] = source_normal
			var coordinate := Vector2(pixel) + corner
			var axis_uv := (Vector2(coordinate.dot(across),coordinate.dot(along)) - low + Vector2(.5,.5)) / extent
			if reverse:
				axis_uv.y = 1.0-axis_uv.y
			corner_uv[corner_index] = axis_uv
		for corner_index: int in TRIANGLE_ORDER:
			vertices.append(corner_positions[corner_index])
			normals.append(corner_normals[corner_index])
			texture_uv.append(corner_uv[corner_index])
			motif_uv.append(corner_uv[corner_index])
			colours.append(colour)
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
