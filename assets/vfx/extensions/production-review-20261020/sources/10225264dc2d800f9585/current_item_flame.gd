extends Node3D
## Actual immutable item/effect with a mutable disclosed current holder.
## The original private source, materials, particles and clock remain retained.
const PreparedItem = preload("res://assets/vfx/extensions/production-review-20261020/sources/ab37f9b1112af923a6d3/item.gd")
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
var source: Node3D
var item_identity: Dictionary = {}
var current_holder_uuid := ""
var packet: Dictionary = {}
var source_seconds := 0.0
var rejection := "unbound_actual_item"


static func preparation_resources(input: Dictionary) -> Array:
	return [String(input.prepared_native_composition_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = Readiness.resources.get(str(input.get("prepared_native_composition_bank", "")))
	if bank == null or not bank.get("interface_ready"):
		return null
	var result: Node3D = VfxPackageIO_10225264dc.resource("res://assets/vfx/extensions/production-review-20261020/sources/10225264dc2d800f9585/current_item_flame.gd").new()
	var original_input: Dictionary = input.duplicate(true)
	# Empty construction identities are unbound; they are never an admitted
	# review item. The first complete actual item snapshot binds them once.
	for field in ["item_uuid", "effect_uuid", "holder_uuid"]:
		original_input[field] = ""
	result.source = PreparedItem.make_component(original_input)
	result.source.name = "RetainedOriginalItemFlame"
	result.add_child(result.source)
	return result


func set_item_snapshot(value: Dictionary) -> bool:
	for field in ["item_uuid", "effect_uuid", "behavior_id", "actor_id"]:
		if str(value.get(field, "")).is_empty():
			return false
		if field != "actor_id" and not item_identity.is_empty() and str(value[field]) != str(item_identity[field]):
			return false
	if str(value.behavior_id) != str(source.settings.behavior_id):
		return false
	var facts: Variant = value.get("facts")
	if not facts is Dictionary or str(facts.get("item_uuid", "")) != str(value.item_uuid) or str(facts.get("effect_uuid", "")) != str(value.effect_uuid):
		return false
	if item_identity.is_empty():
		for field in ["item_uuid", "effect_uuid", "behavior_id"]:
			item_identity[field] = value[field]
			source.settings[field] = value[field]
	current_holder_uuid = str(value.actor_id)
	# In the existing source this settings field is the current renderer
	# admission expectation, not an item/effect identity or a clock origin.
	source.settings.holder_uuid = current_holder_uuid
	packet = value.duplicate(true)
	source.set_item_snapshot(packet)
	rejection = source.rejection
	return true


func prepare_source_layer_mask(mask: int) -> void:
	source.prepare_source_layer_mask(mask)


func source_bindings() -> Dictionary:
	return source.source_bindings()


func sample(seconds: float) -> void:
	source_seconds = maxf(0.0, seconds)
	source.sample(source_seconds)
	rejection = source.rejection


func refresh_live_inputs(seconds: float) -> void:
	sample(seconds)


func capture_observation() -> Dictionary:
	var result: Dictionary = source.capture_observation()
	result.immutable_item_effect_owner = item_identity.duplicate(true)
	result.current_holder_uuid = current_holder_uuid
	result.source_seconds = source_seconds
	result.same_private_source_retained = true
	result.seekable = false
	result.seek_limitation = "Original forward native particle simulation; no bounded permanent seek qualification"
	return result

const VfxPackageIO_10225264dc = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
