extends RefCounted
## The existing production operands shape, restricted to the two known sources.
## Callers supply observations before the original source's first zero sample.


static func clip_for(phase: Resource, input: Dictionary, kind: String) -> Dictionary:
	var operands: Variant = input.get("operands")
	if not operands is Array or operands.size() != 1 or not operands[0] is Dictionary:
		return {}
	var operand: Dictionary = operands[0]
	if operand.get("component_path") != ["effect"] or operand.get("input_field", "") != "" or not operand.get("values") is Dictionary:
		return {}
	var values: Dictionary = operand.values
	var fields: Array = []
	var optional: Array = ["kind"]
	if values.get("kind", "freezing") != "freezing":
		return {}
	if kind == "blast":
		fields = ["source_owner_uuid", "original_caster_uuid", "immediate_launch", "admitted_cells", "event"]
		optional.append_array(["item_uuid", "lifetime_uuid"])
		if not values.get("source_owner_uuid") is String or values.source_owner_uuid.is_empty() or not values.get("original_caster_uuid") is String or values.original_caster_uuid.is_empty():
			return {}
		if not values.get("immediate_launch") is bool or not values.get("admitted_cells") is Array or not values.get("event") is Dictionary:
			return {}
		for field: String in ["item_uuid", "lifetime_uuid"]:
			if values.has(field) and (not values[field] is String or values.immediate_launch and not values[field].is_empty()):
				return {}
	elif kind == "delivery":
		fields = ["caster_uuid", "acting_holder_uuid", "cast_or_throw_accepted", "release_mode"]
		if not values.get("caster_uuid") is String or values.caster_uuid.is_empty() or not values.get("acting_holder_uuid") is String or values.acting_holder_uuid.is_empty():
			return {}
		if not values.get("cast_or_throw_accepted") is bool or not values.get("release_mode") is String or values.release_mode not in ["current_holder_hand", "supplied_cast_snapshot"]:
			return {}
	else:
		return {}
	for field: String in values:
		if field not in fields and field not in optional:
			return {}
	for field: String in fields:
		if not values.has(field):
			return {}
	var clip: Dictionary = phase.to_clip()
	if clip.components.size() != 1 or clip.components[0].id != "effect":
		return {}
	var source: Dictionary = clip.components[0].input
	if source.get("kind") != "freezing":
		return {}
	# Erase every historical fixture observation before binding this caller's
	# exact data. Retain original source admission/replay/suppression checks.
	for field: String in fields + optional:
		if field != "kind":
			source.erase(field)
	source.merge(values.duplicate(true), true)
	return clip
