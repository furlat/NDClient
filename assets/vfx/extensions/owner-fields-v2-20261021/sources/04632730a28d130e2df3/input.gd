extends RefCounted
## Actual public solid-wall values. No section IDs or review lifetime.
const CELL := 2.121320344
const MAX_MODULES := 20
const MAX_CUTS := 64
const MAX_MASK_SIDE := 128
const CONTENT := {"ice":"spatial_effect.spell.wall_of_ice", "stone":"spatial_effect.spell.wall_of_stone"}

static func number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func point(value: Variant, integral: bool = false) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for axis: Variant in value:
		if not number(axis) or (integral and float(axis) != floor(float(axis))):
			return false
	return true

static func geometry(value: Variant, kind: String) -> String:
	if not value is Dictionary or value.get("shape") != "wall_assembly":
		return "Actual wall_assembly required"
	if not number(value.get("base_height_steps")) or float(value.base_height_steps) != floor(float(value.base_height_steps)):
		return "Actual integral base_height_steps required"
	for key in ["width_feet", "height_feet"]:
		if not number(value.get(key)) or float(value[key]) <= 0.0:
			return "Actual positive " + key + " required"
	var path: Variant = value.get("path")
	if not path is Dictionary:
		return "Actual wall path required"
	if path.get("form") == "dome":
		if kind != "ice" or not point(path.get("center")) or not number(path.get("radius_feet")) or float(path.radius_feet) not in [5.0, 10.0]:
			return "Only backend-supported Ice domes of five or ten feet are admitted"
	elif path.get("form") in ["segment", "polyline"]:
		var vertices: Array = path.get("points", []) if path.form == "polyline" else [path.get("start"), path.get("end")]
		if vertices.size() < 2 or vertices.size() > 11:
			return "Actual connected panel path required"
		var count := 0
		for index in vertices.size() - 1:
			if not point(vertices[index]) or not point(vertices[index + 1]):
				return "Every path coordinate must be finite"
			var delta := Vector2(vertices[index + 1][0] - vertices[index][0], vertices[index + 1][1] - vertices[index][1])
			if (delta.x != 0.0 and delta.y != 0.0) or delta == Vector2.ZERO or not is_equal_approx(delta.length() / 2.0, round(delta.length() / 2.0)):
				return "Ice and Stone retain four grid directions and complete ten-foot modules"
			count += int(round(delta.length() / 2.0))
		if count > MAX_MODULES:
			return "Wall exceeds the actual two-hundred-foot module capacity"
	else:
		return "Solid wall path must be panels or an admitted Ice dome"
	var removed: Variant = value.get("removed_sections", [])
	if not removed is Array or removed.size() > MAX_CUTS:
		return "Removed-volume capacity exceeded"
	for cut: Variant in removed:
		if not cut is Dictionary or not point(cut.get("minimum_position"), true) or not number(cut.get("base_height_steps")) or float(cut.base_height_steps) != floor(float(cut.base_height_steps)):
			return "Actual ObjectSectionVolume minimum_position/base_height_steps required"
	return ""

static func modules(area: Dictionary, anchor: Vector2) -> Array[Dictionary]:
	if area.path.form == "dome":
		return [{"dome":true, "center":Vector2(area.path.center[0], area.path.center[1]) - anchor, "radius_feet":float(area.path.radius_feet)}]
	var vertices: Array = area.path.get("points", []) if area.path.form == "polyline" else [area.path.start, area.path.end]
	var result: Array[Dictionary] = []
	for index in vertices.size() - 1:
		var start := Vector2(vertices[index][0], vertices[index][1])
		var end := Vector2(vertices[index + 1][0], vertices[index + 1][1])
		var count := int(round(start.distance_to(end) / 2.0))
		for part in count:
			var first := start.lerp(end, float(part) / count)
			var last := start.lerp(end, float(part + 1) / count)
			result.append({"dome":false, "first":first, "last":last, "center":(first + last) * 0.5 - anchor,
				"heading":-atan2(last.y - first.y, last.x - first.x)})
	return result

static func construction(value: Dictionary, kind: String) -> Dictionary:
	if not value.get("wall_uuid") is String or value.wall_uuid.is_empty() or not point(value.get("anchor_position"), true):
		return {"error":"Actual wall_uuid and anchor_position required"}
	var error := geometry(value.get("wall_geometry"), kind)
	if not error.is_empty():
		return {"error":error}
	return {"error":"", "owner":value.wall_uuid, "anchor":Vector2(value.anchor_position[0], value.anchor_position[1]),
		"area":value.wall_geometry.duplicate(true), "modules":modules(value.wall_geometry, Vector2(value.anchor_position[0], value.anchor_position[1]))}

static func observation(value: Dictionary, owner: String, kind: String, construction_area: Dictionary, anchor: Vector2) -> Dictionary:
	if value.get("spatial_effect_uuid") != owner or not value.get("effect") is Dictionary:
		return {"error":"Current disclosure must belong to this wall UUID"}
	var effect: Dictionary = value.effect
	if effect.get("content_ref", {}).get("content_id") != CONTENT[kind] or not point(effect.get("anchor_position"), true):
		return {"error":"Actual matching solid-wall content and anchor required"}
	if Vector2(effect.anchor_position[0], effect.anchor_position[1]) != anchor or effect.get("area_geometry") != construction_area:
		return {"error":"A changed construction/anchor needs a new actual construction binding"}
	if effect.has("anchor_elevation_steps") and effect.anchor_elevation_steps != construction_area.base_height_steps:
		return {"error":"Anchor elevation and construction base disagree"}
	var sections: Variant = effect.get("construction_sections")
	if not sections is Array or sections.size() > 10:
		return {"error":"Actual current construction_sections required, without invented IDs"}
	for section: Variant in sections:
		var error := geometry(section, kind)
		if not error.is_empty():
			return {"error":error}
		if section.base_height_steps != construction_area.base_height_steps or section.height_feet != construction_area.height_feet or section.width_feet != construction_area.width_feet:
			return {"error":"Current section dimensions must match its construction"}
	var positions: Variant = effect.get("positions")
	if not positions is Array or positions.size() > MAX_MASK_SIDE * MAX_MASK_SIDE:
		return {"error":"Actual current disclosed cells required"}
	var blocked := {}
	for suppression: Variant in effect.get("suppressions", []):
		if not suppression is Dictionary or not suppression.get("positions") is Array:
			return {"error":"Malformed current suppression cells"}
		for position: Variant in suppression.positions:
			if not point(position, true):
				return {"error":"Suppression coordinates must be integral"}
			blocked[Vector2i(position[0], position[1])] = true
	var cells: Array[Vector2i] = []
	var seen := {}
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483647, -2147483647)
	for position: Variant in positions:
		if not point(position, true):
			return {"error":"Disclosed coordinates must be integral"}
		var cell := Vector2i(position[0], position[1])
		if seen.has(cell):
			return {"error":"Repeated disclosed cell"}
		seen[cell] = true
		if blocked.has(cell):
			continue
		cell -= Vector2i(anchor)
		cells.append(cell)
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
	var size := Vector2i.ONE if cells.is_empty() else maximum - minimum + Vector2i.ONE
	if size.x > MAX_MASK_SIDE or size.y > MAX_MASK_SIDE:
		return {"error":"Disclosed-cell span exceeds this explicit render capacity"}
	return {"error":"", "sections":sections.duplicate(true), "cells":cells, "minimum":Vector2i.ZERO if cells.is_empty() else minimum, "size":size}

static func section_for(module: Dictionary, sections: Array) -> Dictionary:
	for section: Dictionary in sections:
		if module.dome:
			if section.path.form == "dome" and Vector2(section.path.center[0], section.path.center[1]) == module.absolute_center and float(section.path.radius_feet) == module.radius_feet:
				return section
		elif section.path.form == "segment":
			var start := Vector2(section.path.start[0], section.path.start[1])
			var end := Vector2(section.path.end[0], section.path.end[1])
			var delta := end - start
			var first: Vector2 = module.first - start
			var last: Vector2 = module.last - start
			if is_zero_approx(delta.cross(first)) and is_zero_approx(delta.cross(last)) and first.dot(delta) >= 0.0 and first.dot(delta) <= delta.length_squared() and last.dot(delta) >= 0.0 and last.dot(delta) <= delta.length_squared():
				return section
	return {}

static func owner_state(value: Dictionary, owner: String) -> String:
	if value.get("owner_uuid") != owner:
		return "Owner state belongs to a different wall"
	for key in ["present", "observed", "suppressed"]:
		if typeof(value.get(key)) != TYPE_BOOL:
			return "Current owner presence/observation/suppression required"
	if not number(value.get("owner_age_seconds")) or float(value.owner_age_seconds) < 0.0:
		return "Actual finite nonnegative owner age required"
	return ""
