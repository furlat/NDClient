extends RefCounted
## Rendering of the current disclosed Frigid Air owner. No wall/gameplay query.
const CONTENT := "spatial_effect.spell.frigid_air"
const CELL := 2.121320344
const MAX_MASK_SIDE := 8
const MAX_CELLS := 64

static func point(value: Variant) -> bool:
	return value is Array and value.size()==2 and value.all(func(axis: Variant) -> bool:
		return typeof(axis) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(axis)) and float(axis)==floor(float(axis)))

static func geometry(value: Dictionary, owner: String) -> Dictionary:
	if owner.is_empty() or str(value.get("spatial_effect_uuid",""))!=owner:
		return {"error":"Actual spatial UUID does not match this child owner"}
	var effect: Variant=value.get("effect")
	if not effect is Dictionary or effect.get("content_ref",{}).get("content_id")!=CONTENT:
		return {"error":"Current disclosed Frigid Air effect required"}
	if not point(effect.get("anchor_position")):
		return {"error":"Actual disclosed anchor_position required"}
	var area: Variant=effect.get("area_geometry")
	if not area is Dictionary or area.get("shape")!="wall_assembly":
		return {"error":"Actual disclosed area_geometry required"}
	var height: Variant=area.get("height_feet")
	if typeof(height) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(height)) or float(height)<=0.:
		return {"error":"Actual positive height_feet required"}
	var base: Variant=area.get("base_height_steps")
	if typeof(base) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(base)) or float(base)!=floor(float(base)):
		return {"error":"Actual base_height_steps required"}
	if effect.has("anchor_elevation_steps") and effect.anchor_elevation_steps!=null and effect.anchor_elevation_steps!=area.base_height_steps:
		return {"error":"Disclosed anchor and area elevation disagree"}
	var positions: Variant=effect.get("positions")
	if not positions is Array or positions.is_empty() or positions.size()>MAX_CELLS:
		return {"error":"Disclosed positions outside explicit render capacity"}
	var blocked := {}
	for suppression: Variant in effect.get("suppressions",[]):
		if not suppression is Dictionary or not suppression.get("positions") is Array:
			return {"error":"Malformed disclosed suppressions"}
		for cell: Variant in suppression.positions:
			if not point(cell): return {"error":"Malformed suppression cell"}
			blocked[Vector2i(cell[0],cell[1])]=true
	var cells: Array[Vector2i]=[]
	var seen := {}
	var minimum := Vector2i(2147483647,2147483647)
	var maximum := Vector2i(-2147483647,-2147483647)
	var anchor := Vector2i(effect.anchor_position[0],effect.anchor_position[1])
	for cell: Variant in positions:
		if not point(cell): return {"error":"Every disclosed cell must be finite and integral"}
		var absolute := Vector2i(cell[0],cell[1])
		if seen.has(absolute): return {"error":"Repeated disclosed cell"}
		seen[absolute]=true
		if blocked.has(absolute): continue
		var relative := absolute-anchor
		cells.append(relative)
		minimum=minimum.min(relative)
		maximum=maximum.max(relative)
	var size := Vector2i.ONE if cells.is_empty() else maximum-minimum+Vector2i.ONE
	if size.x>MAX_MASK_SIDE or size.y>MAX_MASK_SIDE:
		return {"error":"Disclosed mask exceeds explicit render span"}
	return {"error":"","anchor":anchor,"elevation_steps":int(area.base_height_steps),
		"cells":cells,"minimum":Vector2i.ZERO if cells.is_empty() else minimum,"size":size,
		"height":float(height)*CELL/5.0}

static func owner_state(value: Dictionary, owner: String) -> String:
	if str(value.get("owner_uuid",""))!=owner: return "State belongs to another spatial owner"
	for field in ["present","observed","suppressed"]:
		if typeof(value.get(field))!=TYPE_BOOL: return "Current owner visibility must be explicit"
	var age: Variant=value.get("owner_age_seconds")
	if typeof(age) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(age)) or float(age)<0.:
		return "Current owner age must be finite and nonnegative"
	return ""
