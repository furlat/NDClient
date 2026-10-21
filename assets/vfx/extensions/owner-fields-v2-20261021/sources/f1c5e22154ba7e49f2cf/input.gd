extends RefCounted
## Exact public Line geometry. A target distance or current idle hand is not it.
const ZoneInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/bbfe0c8c2a4fd1b29e8d/input.gd")
const CONTENT := "spatial_effect.spell.gust_of_wind"


static func geometry(value: Dictionary, owner: String) -> Dictionary:
	var actual := ZoneInput.geometry(value, owner, CONTENT)
	if not actual.error.is_empty():
		return actual
	var line: Variant = value.effect.get("area_geometry")
	if not line is Dictionary or line.get("shape") != "line":
		return {"error": "Actual disclosed line geometry required"}
	if not ZoneInput.cell(line.get("origin")) or Vector2i(line.origin[0], line.origin[1]) != actual.anchor:
		return {"error": "Actual line origin must match the disclosed spatial anchor"}
	if not ZoneInput.cell(line.get("direction")):
		return {"error": "Actual integral line direction required"}
	var direction := Vector2i(line.direction[0], line.direction[1])
	if direction == Vector2i.ZERO:
		return {"error": "Actual line direction cannot be zero"}
	for key: String in ["length_feet", "width_feet"]:
		var number: Variant = line.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) <= 0.0 or float(number) != floor(float(number)):
			return {"error": "Actual positive integral line dimensions required"}
	# This is the original source's width, not an inferred target radius.
	if float(line.width_feet) != 10.0:
		return {"error": "This unchanged source is authored for the disclosed ten-foot width"}
	actual.direction = direction
	actual.length_cells = float(line.length_feet) / 5.0
	actual.width_feet = float(line.width_feet)
	return actual
