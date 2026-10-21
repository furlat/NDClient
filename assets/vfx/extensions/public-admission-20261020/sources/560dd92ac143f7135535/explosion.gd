extends "res://assets/vfx/extensions/late-20261020/sources/e75e11e80c30bcf100c8/freezing.gd"
## Finite observed explosion only. The old item/lifetime source is unchanged.
const Observation = preload("res://assets/vfx/extensions/public-admission-20261020/sources/1442bc1d59446adcfda1/observation.gd")
var observed := {}


static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_payload_bank] if input.get("prepared_payload_bank") is String else []


static func make_component(input: Dictionary) -> Node3D:
	if input.get("kind") != "freezing" or not Observation._identity(input.get("source_owner_uuid")) or not Observation._identity(input.get("original_caster_uuid")) or not input.get("prepared_payload_bank") is String:
		return null
	# This opt-in does not accept an immediate-launch or private retirement gate.
	for field: String in ["immediate_launch","item_uuid","lifetime_uuid","event"]:
		if input.has(field): return null
	var node := preload("res://assets/vfx/extensions/public-admission-20261020/sources/560dd92ac143f7135535/explosion.gd").new()
	node.specification = input.duplicate(true)
	if input.has("observed_explosion"):
		if not input.observed_explosion is Dictionary:
			node.free()
			return null
		node.set_observed_explosion(input.observed_explosion)
	return node


func set_blast_event(_value: Dictionary) -> bool:
	# Legacy callback cannot bypass the explicit native-occurrence gate.
	_clear("use_actual_observed_explosion")
	return false


func _clear(reason: String) -> void:
	for draw: MeshInstance3D in draws: draw.hide()
	event.clear()
	observed.clear()
	rejection = reason


func set_observed_explosion(value: Dictionary) -> bool:
	_clear("actual_observation_missing")
	var result := Observation.resolve(value,str(specification.source_owner_uuid),str(specification.original_caster_uuid))
	if not result.error.is_empty():
		rejection = result.error
		return false
	var identity: String = result.explosion_occurrence
	if consumed.has(identity):
		rejection = "missing_or_replayed_event"
		return false
	consumed[identity] = true
	observed = result
	# These are private rendering operands, not a fake legacy retirement packet.
	event = {"kind":"freezing","source_owner_uuid":identity,
		"original_caster_uuid":result.source_caster_uuid,"event_uuid":identity,
		"admitted_cells":result.admitted_cells}
	if not draws.is_empty(): apply_footprint_cells(materials,result.admitted_cells)
	rejection = ""
	return true


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.erase("all_item_retirement_external")
	result.actual_observed_explosion = observed.duplicate(true)
	result.retained_item_lifecycle_used = false
	result.requires_private_inventory_identity = false
	return result
