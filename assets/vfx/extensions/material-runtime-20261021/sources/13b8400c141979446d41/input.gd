extends RefCounted
## Exact known-module lookup; unknown coordinates retain original admission.
const Original = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/85d97d458c33910ca580/input.gd")
const Solid = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/04632730a28d130e2df3/input.gd")


static func module_index(actual: Dictionary) -> Dictionary:
	var result := {}
	for index in actual.modules.size():
		var module: Dictionary = actual.modules[index]
		var first: Vector2 = module.first
		var last: Vector2 = module.last
		result[Vector4(first.x, first.y, last.x, last.y)] = index
		result[Vector4(last.x, last.y, first.x, first.y)] = index
	return result


static func _original(value: Dictionary, actual: Dictionary) -> Dictionary:
	var observation := Original.observation(value, actual)
	var matching := []
	if observation.error.is_empty():
		for module: Dictionary in actual.modules:
			matching.append(Solid.section_for(module, observation.sections))
	return {"observation": observation, "matching": matching, "exact_module_path": false}


static func observation(value: Dictionary, actual: Dictionary, indices: Dictionary) -> Dictionary:
	if not value.get("effect") is Dictionary:
		return _original(value, actual)
	var sections: Variant = value.effect.get("construction_sections")
	if not sections is Array or sections.size() > actual.modules.size():
		return _original(value, actual)
	var positions := PackedInt32Array()
	positions.resize(actual.modules.size())
	positions.fill(-1)
	for index in sections.size():
		var section: Variant = sections[index]
		# Preserve every original geometry/dimension/cut rule. Only the
		# repeated all-module section_for search is replaced for exact endpoints.
		if not Solid.geometry(section, "force").is_empty() or section.path.form != "segment" or section.height_feet != actual.area.height_feet or section.base_height_steps != actual.area.base_height_steps or section.width_feet != actual.area.width_feet:
			return _original(value, actual)
		var first := Vector2(section.path.start[0], section.path.start[1])
		var last := Vector2(section.path.end[0], section.path.end[1])
		var key := Vector4(first.x, first.y, last.x, last.y)
		if not indices.has(key):
			# Approximate/fractional paths can still satisfy original cross/dot
			# tests. Do not tighten or guess that admission: run the original.
			return _original(value, actual)
		var module: int = indices[key]
		if positions[module] == -1:
			# Original section_for chooses the FIRST matching duplicate.
			positions[module] = index
	# Delegate owner/content/anchor/elevation/cell/suppression admission and
	# exact source reduction. Inputs are shallow private headers only; caller
	# dictionaries and arrays are never modified.
	var header := value.duplicate(false)
	header.effect = value.effect.duplicate(false)
	header.effect.construction_sections = []
	var current := Original.observation(header, actual)
	if not current.error.is_empty():
		return {"observation": current, "matching": [], "exact_module_path": true}
	current.sections = sections.duplicate(true)
	var matching := []
	for index in positions:
		matching.append({} if index == -1 else current.sections[index])
	return {"observation": current, "matching": matching, "exact_module_path": true}
