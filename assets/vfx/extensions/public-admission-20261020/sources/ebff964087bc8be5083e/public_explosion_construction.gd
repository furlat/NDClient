extends RefCounted
## Existing private-clip operands seam; only the actual finite source identity.


static func clip_for(phase: Resource, input: Dictionary) -> Dictionary:
	var operands: Variant = input.get("operands")
	if not operands is Array or operands.size() != 1 or not operands[0] is Dictionary:
		return {}
	var operand: Dictionary = operands[0]
	if operand.get("component_path") != ["effect"] or operand.get("input_field", "") != "" or not operand.get("values") is Dictionary:
		return {}
	var values: Dictionary = operand.values
	for field: String in ["source_owner_uuid", "original_caster_uuid"]:
		if not values.get(field) is String or values[field].is_empty(): return {}
	for field: String in values:
		if field not in ["kind", "source_owner_uuid", "original_caster_uuid", "observed_explosion"]: return {}
	if values.get("kind", "freezing") != "freezing": return {}
	if values.has("observed_explosion") and not values.observed_explosion is Dictionary: return {}
	var clip: Dictionary = phase.to_clip()
	if clip.components.size() != 1 or clip.components[0].id != "effect" or clip.components[0].input.get("kind") != "freezing": return {}
	clip.components[0].input.merge(values.duplicate(true), true)
	return clip
