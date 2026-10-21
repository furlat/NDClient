extends RefCounted
## Actual disclosed spatial owners and cells. No footprint or gameplay inference.


static func cell(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for axis: Variant in value:
		if typeof(axis) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(axis)) or float(axis) != floor(float(axis)):
			return false
	return true


static func cells(value: Variant) -> Dictionary:
	if not value is Array:
		return {"error": "Actual disclosed cell array required"}
	var result: Array[Vector2i] = []
	var seen := {}
	for entry: Variant in value:
		if not cell(entry):
			return {"error": "Actual finite integral cells required"}
		var position := Vector2i(entry[0], entry[1])
		if seen.has(position):
			return {"error": "Repeated actual cell"}
		seen[position] = true
		result.append(position)
	return {"error": "", "cells": result}


static func geometry(value: Dictionary, owner: String, content: String) -> Dictionary:
	if owner.is_empty() or str(value.get("spatial_effect_uuid", "")) != owner:
		return {"error": "Actual spatial owner mismatch"}
	var effect: Variant = value.get("effect")
	if not effect is Dictionary or effect.get("content_ref", {}).get("content_id") != content:
		return {"error": "Actual spatial content mismatch"}
	if not cell(effect.get("anchor_position")):
		return {"error": "Actual disclosed anchor required"}
	var actual := cells(effect.get("positions"))
	if not actual.error.is_empty():
		return actual
	var suppressed := {}
	for row: Variant in effect.get("suppressions", []):
		if not row is Dictionary:
			return {"error": "Invalid actual suppression"}
		var excluded := cells(row.get("positions"))
		if not excluded.error.is_empty():
			return excluded
		for position: Vector2i in excluded.cells:
			suppressed[position] = true
	var anchor := Vector2i(effect.anchor_position[0], effect.anchor_position[1])
	var local: Array[Vector2i] = []
	for position: Vector2i in actual.cells:
		if not suppressed.has(position):
			local.append(position - anchor)
	return {"error": "", "anchor": anchor, "cells": local}


static func owner_state(value: Dictionary, owner: String) -> String:
	if owner.is_empty() or str(value.get("owner_uuid", "")) != owner:
		return "Actual owner-state UUID mismatch"
	for key: String in ["present", "observed", "suppressed"]:
		if typeof(value.get(key)) != TYPE_BOOL:
			return "Actual current owner presence/observation/suppression required"
	var age: Variant = value.get("owner_age_seconds")
	if typeof(age) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(age)) or float(age) < 0.0:
		return "Actual nonnegative owner age required"
	return ""


static func admitted(value: Dictionary) -> bool:
	return not value.is_empty() and value.present and value.observed and not value.suppressed


static func point(value: Array) -> Variant:
	if value.is_empty() or not value[0] is Dictionary or not value[0].get("point") is Vector3 or not value[0].point.is_finite():
		return null
	return value[0].point
