extends RefCounted
## Current public Forcecage wall_assembly values, never fixture section UUIDs.
const Solid = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/04632730a28d130e2df3/input.gd")
const CONTENT := "spatial_effect.spell.forcecage"

static func construction(value: Dictionary, form: String) -> Dictionary:
	var actual := Solid.construction(value, "force")
	if not actual.error.is_empty():
		return actual
	var area: Dictionary = actual.area
	var path: Dictionary = area.path
	var side := 4.0 if form == "cage" else 2.0
	if form not in ["cage", "box"] or path.form != "polyline" or path.points.size() != 5 or path.points[0] != path.points[4]:
		return {"error":"Actual closed four-side Forcecage construction required"}
	if float(area.height_feet) != side * 5.0 or not is_equal_approx(float(area.width_feet), 1.0 / 48.0):
		return {"error":"Selected cage/box must match actual backend height and width"}
	for index in 4:
		var delta := Vector2(path.points[index + 1][0] - path.points[index][0], path.points[index + 1][1] - path.points[index][1])
		if delta.length() != side:
			return {"error":"Actual backend20ft cage or10ft box side required"}
	var first := Vector2(path.points[0][0], path.points[0][1])
	var opposite := Vector2(path.points[2][0], path.points[2][1])
	if (opposite - first).abs() != Vector2.ONE * side:
		return {"error":"A folded review path is not the actual square Forcecage"}
	return actual

static func observation(value: Dictionary, actual: Dictionary) -> Dictionary:
	if value.get("spatial_effect_uuid") != actual.owner or not value.get("effect") is Dictionary:
		return {"error":"Actual disclosure for this Forcecage owner required"}
	var effect: Dictionary = value.effect
	if effect.get("content_ref", {}).get("content_id") != CONTENT or not Solid.point(effect.get("anchor_position"), true):
		return {"error":"Actual Forcecage content and anchor required"}
	if effect.get("area_geometry") != actual.area or Vector2(effect.anchor_position[0], effect.anchor_position[1]) != actual.anchor:
		return {"error":"Changed actual construction needs a new binding"}
	if effect.has("anchor_elevation_steps") and effect.anchor_elevation_steps != actual.area.base_height_steps:
		return {"error":"Actual anchor/area elevation disagree"}
	var sections: Variant = effect.get("construction_sections")
	if not sections is Array or sections.size() > actual.modules.size():
		return {"error":"Current public side section geometries required"}
	for section: Variant in sections:
		var error := Solid.geometry(section, "force")
		if not error.is_empty() or section.path.form != "segment" or section.height_feet != actual.area.height_feet or section.base_height_steps != actual.area.base_height_steps or section.width_feet != actual.area.width_feet:
			return {"error":"Current side geometry does not match its actual construction"}
		var match_count := 0
		for module: Dictionary in actual.modules:
			if not Solid.section_for(module, [section]).is_empty():
				match_count += 1
		if match_count != 1:
			return {"error":"Only actual unsplit10ft side sections are admitted"}
	var positions: Variant = effect.get("positions")
	if not positions is Array or positions.size() > 64:
		return {"error":"Current disclosed Forcecage cells required"}
	var blocked := {}
	for suppression: Variant in effect.get("suppressions", []):
		if not suppression is Dictionary or not suppression.get("positions") is Array:
			return {"error":"Actual suppression cells required"}
		for point: Variant in suppression.positions:
			if not Solid.point(point, true):
				return {"error":"Invalid suppressed cell"}
			blocked[Vector2i(point[0], point[1])] = true
	var cells: Array[Vector2i] = []
	var seen := {}
	var low := Vector2i(2147483647, 2147483647)
	var high := Vector2i(-2147483647, -2147483647)
	for position: Variant in positions:
		if not Solid.point(position, true):
			return {"error":"Finite integral disclosed cells required"}
		var absolute := Vector2i(position[0], position[1])
		if seen.has(absolute):
			return {"error":"Repeated disclosed cell"}
		seen[absolute] = true
		if blocked.has(absolute):
			continue
		var local := absolute - Vector2i(actual.anchor)
		cells.append(local)
		low = low.min(local)
		high = high.max(local)
	var size := Vector2i.ONE if cells.is_empty() else high - low + Vector2i.ONE
	if size.x > 16 or size.y > 16:
		return {"error":"Disclosed cells exceed the actual cage render span"}
	return {"error":"", "sections":sections.duplicate(true), "cells":cells, "minimum":Vector2i.ZERO if cells.is_empty() else low, "size":size}
