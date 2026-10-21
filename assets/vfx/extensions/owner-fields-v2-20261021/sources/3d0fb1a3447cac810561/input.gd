extends RefCounted
## Projection of Fire's actual `wall` DTO. Its prepared modules use5ft=1unit.
const FEET_PER_SOURCE_UNIT := 5.0

static func point(value: Variant) -> bool:
	return value is Array and value.size()==2 and value.all(func(axis: Variant) -> bool:
		return typeof(axis) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(axis)))

static func positive(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0.0

static func construction(input: Dictionary, bank: Resource) -> Dictionary:
	if not input.get("wall_uuid") is String or input.wall_uuid.is_empty() or not point(input.get("anchor_position")):
		return {"error":"Actual wall UUID and logical anchor required"}
	var geometry: Variant=input.get("wall_geometry")
	if not geometry is Dictionary or geometry.get("shape")!="wall":
		return {"error":"Actual Fire WallPresentationGeometry shape=wall required"}
	if not positive(geometry.get("height_feet")) or not positive(geometry.get("width_feet")):
		return {"error":"Actual positive height and width required"}
	var base: Variant=geometry.get("base_height_steps")
	if typeof(base) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(base)) or float(base)!=floor(float(base)):
		return {"error":"Actual integral base elevation required"}
	var path: Variant=geometry.get("path")
	if not path is Dictionary or path.get("form") not in ["segment","ring"]:
		return {"error":"Actual ordered segment or ring required"}
	var form: String=path.form
	var source_form: String=str(input.get("source_form",""))
	if form!=source_form:
		return {"error":"Prepared source form and actual geometry disagree"}
	var anchor:=Vector2(input.anchor_position[0],input.anchor_position[1])
	var result:={"error":"","owner":input.wall_uuid,"anchor":anchor,"geometry":geometry.duplicate(true),
		"form":form,"height_ratio":float(geometry.height_feet)/20.0,"width_ratio":float(geometry.width_feet)/1.0}
	if form=="segment":
		if not point(path.get("start")) or not point(path.get("end")):
			return {"error":"Actual finite ordered endpoints required"}
		result.start=Vector2(path.start[0],path.start[1])-anchor
		result.end=Vector2(path.end[0],path.end[1])-anchor
		result.length=result.start.distance_to(result.end)
		if result.length<=0.0:
			return {"error":"Actual wall cannot have a zero-length segment"}
		if geometry.get("hot_side") not in ["left","right"]:
			return {"error":"Actual segment hot_side must retain left/right"}
	else:
		if not point(path.get("center")) or not positive(path.get("radius_feet")):
			return {"error":"Actual ring center and positive radius required"}
		result.center=Vector2(path.center[0],path.center[1])-anchor
		result.radius=float(path.radius_feet)/FEET_PER_SOURCE_UNIT
		if geometry.get("hot_side") not in ["inside","outside"]:
			return {"error":"Actual ring hot_side must retain inside/outside"}
	return result

static func cells(value: Array) -> Dictionary:
	var output:={}
	for cell: Variant in value:
		if not point(cell) or float(cell[0])!=floor(float(cell[0])) or float(cell[1])!=floor(float(cell[1])):
			return {"error":"Actual local admitted cells must be integral pairs"}
		output[Vector2i(cell[0],cell[1])]=true
	return {"error":"","values":output}

static func owner(value: Dictionary, identity: String) -> String:
	if not value.get("owner_uuid") is String or value.owner_uuid!=identity:
		return "Current state belongs to another actual spatial owner"
	for name in ["present","observed","suppressed"]:
		if typeof(value.get(name))!=TYPE_BOOL:
			return "Actual presence/visibility/suppression booleans required"
	var age: Variant=value.get("owner_age_seconds")
	if typeof(age) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(age)) or float(age)<0.0:
		return "Actual finite nonnegative owner age required"
	return ""
