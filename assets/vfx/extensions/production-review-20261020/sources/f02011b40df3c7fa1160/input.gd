extends RefCounted
## Rendering projection of the existing wall_assembly geometry, not game rules.
const CELL := 2.121320344
const FEET_TO_SOURCE := CELL / 5.0


static func point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value.all(func(axis: Variant) -> bool:
		return typeof(axis) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(axis)))


static func positive(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) > 0.0


static func construction(input: Dictionary, family: String) -> Dictionary:
	if str(input.get("wall_uuid", "")).is_empty() or not point(input.get("anchor_position")):
		return {"error": "Actual wall UUID and source anchor are required"}
	var value: Variant = input.get("wall_geometry")
	if not value is Dictionary or value.get("shape", "wall_assembly") != "wall_assembly":
		return {"error": "Existing wall_assembly geometry is required"}
	if not positive(value.get("width_feet")) or not positive(value.get("height_feet")):
		return {"error": "Actual positive wall width and height are required"}
	if not value.get("removed_sections", []).is_empty():
		return {"error": "This non-solid source has no removed-section treatment"}
	var path: Variant = value.get("path")
	if not path is Dictionary:
		return {"error": "Actual wall path is required"}
	var anchor := Vector2(input.anchor_position[0], input.anchor_position[1])
	var result := {"error": "", "owner": str(input.wall_uuid), "geometry": value.duplicate(true),
		"anchor": input.anchor_position.duplicate(), "width": float(value.width_feet) * FEET_TO_SOURCE,
		"height": float(value.height_feet) * FEET_TO_SOURCE, "points": [], "circular": false}
	if path.get("form") == "ring" and family == "thorns":
		if not point(path.get("center")) or not positive(path.get("radius_feet")):
			return {"error": "Actual circular centerline and radius are required"}
		var center := Vector2(path.center[0], path.center[1]) - anchor
		result.center = center * CELL
		result.radius = float(path.radius_feet) * FEET_TO_SOURCE
		result.circular = true
		result.modules = 16
		result.heading = 0.0
		result.length = 16.0 * CELL
		return result
	var points: Variant
	if path.get("form") == "segment":
		points = [path.get("start"), path.get("end")]
	elif path.get("form") == "polyline" and family == "wind":
		points = path.get("points")
	else:
		return {"error": "Thorns needs segment/ring; Wind needs segment/polyline geometry"}
	if not points is Array or points.size() < 2 or points.size() > 65:
		return {"error": "Native wall source supports 2–65 path points"}
	var length := 0.0
	var modules := 0
	for raw: Variant in points:
		if not point(raw):
			return {"error": "Every actual centerline point must be finite"}
		var selected := Vector2(raw[0], raw[1]) - anchor
		if not result.points.is_empty():
			var delta: Vector2 = selected - result.points[-1]
			if delta.length() <= .000001:
				return {"error": "Repeated zero-length path segments are unsupported"}
			length += delta.length() * CELL
			modules += ceili(delta.length())
		result.points.append(selected)
	result.length = length
	result.modules = modules
	if result.modules > 64:
		return {"error": "Actual path exceeds this source's 64-module rendering capacity"}
	if family == "thorns":
		if result.modules > 16:
			return {"error": "Actual thorns path exceeds the native sixteen-module capacity"}
		var direction: Vector2 = result.points[-1] - result.points[0]
		result.center = (result.points[0] + result.points[-1]) * .5 * CELL
		result.heading = -atan2(direction.y, direction.x)
	return result


static func visual(value: Dictionary, owner: String) -> String:
	if str(value.get("wall_uuid", "")) != owner:
		return "Wall state belongs to a different spatial owner"
	for field in ["present", "observed"]:
		if typeof(value.get(field)) != TYPE_BOOL:
			return "Actual optical presence/observation must be explicit booleans"
	var removal: Variant = value.get("removal_at_seconds")
	if removal != null and (typeof(removal) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(removal)) or float(removal) < 0.0):
		return "Removal must be an actual nonnegative owner age or null"
	var occupants: Variant = value.get("occupants", [])
	if not occupants is Array or occupants.size() > 16:
		return "Thorns supports at most sixteen simultaneous optical occupants"
	for entry: Variant in occupants:
		if not entry is Dictionary or str(entry.get("actor_uuid", "")).is_empty() or not entry.get("ground") is Vector3 or not entry.ground.is_finite():
			return "An occupant needs its actual actor and world ground point"
	var contacts: Variant = value.get("contacts", [])
	if not contacts is Array or contacts.size() > 64:
		return "Bounded actual contact prefix is required"
	var identities := {}
	for entry: Variant in contacts:
		if not entry is Dictionary or str(entry.get("event_uuid", "")).is_empty() or identities.has(entry.event_uuid):
			return "Every contact needs one distinct actual event identity"
		identities[entry.event_uuid] = true
		if typeof(entry.get("at_seconds")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(entry.at_seconds)) or float(entry.at_seconds) < 0.0:
			return "Contact owner age must be an actual nonnegative time"
		if not entry.get("ground") is Vector3 or not entry.ground.is_finite() or entry.get("kind") not in ["damage", "crossing", "projectile_block"]:
			return "Actual contact location and kind are required"
		if entry.kind in ["damage", "crossing"] and str(entry.get("actor_uuid", "")).is_empty():
			return "Creature contact must identify its actual recipient"
	return ""


static func retirement(value: Dictionary, age: float, seconds: float) -> float:
	var removal: Variant = value.get("removal_at_seconds")
	return 0.0 if removal == null else smoothstep(float(removal), float(removal) + seconds, age)


static func visible(value: Dictionary, age: float, fade_seconds: float) -> bool:
	if value.is_empty() or not value.observed:
		return false
	return bool(value.present) or (value.get("removal_at_seconds") != null and age >= float(value.removal_at_seconds) and age < float(value.removal_at_seconds) + fade_seconds)


static func pulse(event: Dictionary, age: float) -> float:
	var elapsed := age - float(event.at_seconds)
	return exp(-pow(elapsed / .22, 2.0)) if elapsed >= 0.0 and elapsed <= .8 else 0.0
