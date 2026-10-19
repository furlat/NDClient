extends RefCounted
## One actual application, independent of the three-recipient review. All
## artwork is retained in the neutral phase; only actual application operands
## are supplied here. No application, surface or UUID is invented by Factory.
const Phase = preload("res://assets/vfx/sources/ba7416cc304593ce8f2d/circle_receiving.tres")
const Occurrence = preload("res://assets/vfx/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd")


static func missing(application: Dictionary) -> PackedStringArray:
	var issues := PackedStringArray()
	for key in ["application_id", "target_actor"]:
		if not application.get(key) is String or str(application[key]).is_empty():
			issues.append(key + " must be the actual nonempty native identity")
	for key in ["damage_applied", "save_succeeded"]:
		if not application.get(key) is bool:
			issues.append(key + " requires an observed boolean result")
	if application.get("damage_type") != "necrotic":
		issues.append("damage_type must be necrotic")
	if application.has("target_entity_uuid") and application.target_entity_uuid != application.get("target_actor"):
		issues.append("target_entity_uuid must equal the actual target actor UUID")
	return issues


static func to_clip(application: Dictionary) -> Dictionary:
	assert(missing(application).is_empty(), "Missing actual Circle application evidence")
	var clip: Dictionary = Phase.to_clip()
	var packet := application.duplicate(true)
	packet.target_entity_uuid = packet.target_actor
	clip.components[0].input.components[0].input.application = packet
	return clip


static func make_component(input: Dictionary) -> Node3D:
	var application: Dictionary = input.get("application", {})
	if not missing(application).is_empty():
		# Explicit unavailable evidence: no fixture construction and no delayed
		# assertion while the authoritative world continues.
		return null
	return Occurrence.make_component({"clip": to_clip(application), "layer_mask": input.get("layer_mask", 2)})
