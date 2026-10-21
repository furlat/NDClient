extends RefCounted
## Full admitted neighbors and bounded, disjoint draw subsets are separate.
## Pure data only: no owner registry, area solver, clock or per-frame partition.
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func owner(owner_uuid: String, cells: Array) -> Dictionary:
	if owner_uuid.is_empty(): return {"error": "Actual owner UUID required"}
	var points: Array[Vector2i] = []
	var members := {}
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for cell: Variant in cells:
		if not cell is Array or cell.size() != 2:
			return {"error": "Every admitted cell must be a two-coordinate array"}
		for axis: Variant in cell:
			if typeof(axis) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(axis)) or float(axis) != floor(float(axis)):
				return {"error": "Finite integral admitted cells required"}
		var point := Vector2i(cell[0], cell[1])
		if members.has(point): return {"error": "Duplicate admitted cell"}
		members[point] = true
		points.append(point)
		low = low.min(Vector2(point) - Vector2.ONE * .5)
		high = high.max(Vector2(point) + Vector2.ONE * .5)
	return {"error": "", "owner_uuid": owner_uuid, "cells": points, "members": members,
		"minimum": Vector2.ZERO if points.is_empty() else low,
		"maximum": Vector2.ZERO if points.is_empty() else high}


static func subset(full: Dictionary, draw_cells: Array, capacity: int) -> Dictionary:
	if not full.get("error", "Missing full admitted topology").is_empty(): return {"error": "Invalid full admitted topology"}
	if capacity not in [32, 128]: return {"error": "Use the actual source's32 or128 cell capacity"}
	var drawn := {}
	var required := {}
	for cell: Variant in draw_cells:
		if not cell is Vector2i or not full.members.has(cell) or drawn.has(cell):
			return {"error": "Draw cells must be a unique subset of actual admitted cells"}
		drawn[cell] = true
		# Original programs overlap by0.00001 at cell boundaries. Read the
		# original neighbors there, but assign each fragment to only one draw.
		for y in range(-1, 2):
			for x in range(-1, 2):
				var neighbor: Vector2i = cell + Vector2i(x, y)
				if full.members.has(neighbor): required[neighbor] = true
	if required.size() > capacity:
		return {"error": "Draw subset plus original-neighbor support exceeds source capacity"}
	var points := PackedVector2Array()
	var edges := PackedVector4Array()
	var flags := PackedFloat32Array()
	for cell: Vector2i in full.cells:
		if not required.has(cell): continue
		points.append(Vector2(cell))
		edges.append(Vector4(0. if full.members.has(cell + DIRECTIONS[0]) else 1.,
			0. if full.members.has(cell + DIRECTIONS[1]) else 1.,
			0. if full.members.has(cell + DIRECTIONS[2]) else 1.,
			0. if full.members.has(cell + DIRECTIONS[3]) else 1.))
		flags.append(1. if drawn.has(cell) else 0.)
	var count := points.size()
	while points.size() < capacity:
		points.append(Vector2.ZERO)
		edges.append(Vector4.ZERO)
		flags.append(0.)
	return {"error": "", "owner_uuid": full.owner_uuid, "points": points, "edges": edges,
		"draw_flags": flags, "count": count, "draw_count": drawn.size(), "capacity": capacity,
		"minimum": full.minimum, "maximum": full.maximum}


static func partition(full: Dictionary, capacity: int) -> Dictionary:
	if not full.get("error", "Missing full admitted topology").is_empty(): return {"error": "Invalid full admitted topology"}
	if capacity not in [32, 128]: return {"error": "Use the actual source capacity"}
	var result := []
	var current: Array[Vector2i] = []
	var support := {}
	for cell: Vector2i in full.cells:
		var additions := {}
		for y in range(-1, 2):
			for x in range(-1, 2):
				var neighbor := cell + Vector2i(x, y)
				if full.members.has(neighbor) and not support.has(neighbor):
					additions[neighbor] = true
		if support.size() + additions.size() > capacity:
			result.append(subset(full, current, capacity))
			current.clear()
			support.clear()
			for y in range(-1, 2):
				for x in range(-1, 2):
					var neighbor := cell + Vector2i(x, y)
					if full.members.has(neighbor): support[neighbor] = true
		else:
			support.merge(additions)
		current.append(cell)
	if not current.is_empty(): result.append(subset(full, current, capacity))
	return {"error": "", "partitions": result,
		"scope": "Create once at actual footprint change; caller owns stable draw IDs and the one real owner clock"}
