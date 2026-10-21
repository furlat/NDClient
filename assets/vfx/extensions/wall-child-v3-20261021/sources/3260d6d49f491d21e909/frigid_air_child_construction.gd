extends RefCounted
## Same explicit per-occurrence operands shape as existing prepared sources.
static func clip_for(phase: Resource, input: Dictionary) -> Dictionary:
	var operands: Variant=input.get("operands")
	if not operands is Array or operands.size()!=1 or not operands[0] is Dictionary: return {}
	var operand: Dictionary=operands[0]
	if operand.get("component_path")!=["effect"] or operand.get("input_field","")!="": return {}
	var values: Variant=operand.get("values")
	if not values is Dictionary or values.size()!=1 or not values.get("owner_uuid") is String or values.owner_uuid.is_empty(): return {}
	var clip: Dictionary=phase.to_clip()
	if clip.components.size()!=1 or clip.components[0].id!="effect": return {}
	clip.components[0].input.owner_uuid=values.owner_uuid
	return clip
