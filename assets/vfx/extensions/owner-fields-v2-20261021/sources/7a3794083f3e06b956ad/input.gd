extends RefCounted
## Disclosed passive wall sections. No section UUIDs or contact inference.
const ZoneInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/bbfe0c8c2a4fd1b29e8d/input.gd")
const CONTENT := "spatial_effect.spell.wall_of_force"
const MAX_MODULES := 10
const MAX_CUTS := 64


static func number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1])


static func geometry(value: Variant, dome: bool) -> String:
	if not value is Dictionary or value.get("shape") != "wall_assembly":
		return "Actual wall_assembly required"
	if not number(value.get("base_height_steps")) or float(value.base_height_steps) != floor(float(value.base_height_steps)):
		return "Actual integral wall base height required"
	for key: String in ["width_feet", "height_feet"]:
		if not number(value.get(key)) or float(value[key]) <= 0.0:
			return "Actual positive wall dimensions required"
	var path: Variant = value.get("path")
	if not path is Dictionary:
		return "Actual wall path required"
	if dome:
		if path.get("form") != "dome" or not point(path.get("center")) or not number(path.get("radius_feet")) or float(path.radius_feet) not in [5.0, 10.0]:
			return "Actual backend-supported five/ten-foot dome required"
		if float(value.height_feet) != float(path.radius_feet):
			return "Actual dome height must match its disclosed hemisphere radius"
	else:
		if path.get("form") not in ["segment", "polyline"]:
			return "Actual segment/polyline panels required"
		var vertices: Variant = path.get("points") if path.form == "polyline" else [path.get("start"), path.get("end")]
		if not vertices is Array or vertices.size() < 2 or vertices.size() > MAX_MODULES + 1:
			return "Actual bounded connected panel vertices required"
		var modules := 0
		for index: int in vertices.size() - 1:
			if not point(vertices[index]) or not point(vertices[index + 1]):
				return "Every actual panel vertex must be finite"
			var delta := Vector2(float(vertices[index + 1][0]) - float(vertices[index][0]), float(vertices[index + 1][1]) - float(vertices[index][1]))
			var length := delta.length()
			var count := roundi(length / 2.0)
			if count < 1 or absf(length - float(count) * 2.0) > 0.000001:
				return "The actual backend uses complete ten-foot panel sections"
			modules += count
		if modules > MAX_MODULES:
			return "Actual backend panel capacity exceeded"
	var cuts: Variant = value.get("removed_sections", [])
	if not cuts is Array or cuts.size() > MAX_CUTS:
		return "Actual removed-volume capacity exceeded"
	for cut: Variant in cuts:
		if not cut is Dictionary or not ZoneInput.cell(cut.get("minimum_position")) or not number(cut.get("base_height_steps")) or float(cut.base_height_steps) != floor(float(cut.base_height_steps)):
			return "Actual ObjectSectionVolume coordinates required"
	return ""


static func modules(area: Dictionary, anchor: Vector2) -> Array[Dictionary]:
	if area.path.form == "dome":
		return [{"dome": true, "center": Vector2(area.path.center[0], area.path.center[1]) - anchor,
			"radius_feet": float(area.path.radius_feet)}]
	var result: Array[Dictionary] = []
	var path: Dictionary = area.path
	var vertices: Array = path.points if path.form == "polyline" else [path.start, path.end]
	for index: int in vertices.size() - 1:
		var first := Vector2(vertices[index][0], vertices[index][1])
		var last := Vector2(vertices[index + 1][0], vertices[index + 1][1])
		var count := roundi(first.distance_to(last) / 2.0)
		for part: int in count:
			var start := first.lerp(last, float(part) / float(count))
			var end := first.lerp(last, float(part + 1) / float(count))
			result.append({"dome": false, "start": start, "end": end, "center": (start + end) * .5 - anchor})
	return result


static func construction(value: Dictionary, dome: bool) -> Dictionary:
	if not value.get("wall_uuid") is String or value.wall_uuid.is_empty() or not ZoneInput.cell(value.get("anchor_position")):
		return {"error": "Actual wall UUID and integral anchor required"}
	var error := geometry(value.get("wall_geometry"), dome)
	if not error.is_empty():
		return {"error": error}
	var anchor := Vector2(value.anchor_position[0], value.anchor_position[1])
	return {"error": "", "owner": value.wall_uuid, "anchor": anchor,
		"area": value.wall_geometry.duplicate(true), "modules": modules(value.wall_geometry, anchor)}


static func matches(module: Dictionary, section: Dictionary, anchor: Vector2) -> bool:
	var path: Dictionary = section.path
	if module.dome:
		return path.form == "dome" and Vector2(path.center[0], path.center[1]) - anchor == module.center and float(path.radius_feet) == float(module.radius_feet)
	return path.form == "segment" and Vector2(path.start[0], path.start[1]) == module.start and Vector2(path.end[0], path.end[1]) == module.end


static func observation(value: Dictionary, construction_value: Dictionary, dome: bool) -> Dictionary:
	var actual := ZoneInput.geometry(value, construction_value.owner, CONTENT)
	if not actual.error.is_empty():
		return actual
	var effect: Dictionary = value.effect
	if Vector2(actual.anchor) != construction_value.anchor or effect.get("area_geometry") != construction_value.area:
		return {"error": "Changed owner construction requires a new actual binding"}
	if effect.has("anchor_elevation_steps") and effect.anchor_elevation_steps != construction_value.area.base_height_steps:
		return {"error": "Actual anchor and construction elevation disagree"}
	var sections: Variant = effect.get("construction_sections")
	if not sections is Array or sections.size() > MAX_MODULES:
		return {"error": "Actual current construction_sections required"}
	var assigned := {}
	for section: Variant in sections:
		var error := geometry(section, dome)
		if not error.is_empty():
			return {"error": error}
		for key: String in ["base_height_steps", "width_feet", "height_feet"]:
			if section[key] != construction_value.area[key]:
				return {"error": "Current actual section dimensions disagree with construction"}
		var matched := -1
		for index: int in construction_value.modules.size():
			if matches(construction_value.modules[index], section, construction_value.anchor):
				matched = index
				break
		if matched < 0 or assigned.has(matched):
			return {"error": "Unknown or duplicate actual section geometry"}
		assigned[matched] = section.duplicate(true)
	actual.sections = assigned
	return actual
