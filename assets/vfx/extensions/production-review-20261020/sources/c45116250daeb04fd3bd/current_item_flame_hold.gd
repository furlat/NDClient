extends "res://assets/vfx/extensions/production-review-20261020/sources/10225264dc2d800f9585/current_item_flame.gd"
## Same actual item/holder boundary; an explicitly separate recorded-hold style.
const HoldSource = preload("res://assets/vfx/extensions/production-review-20261020/sources/7fab332539134d10ac8b/flame_hold_source.gd")


static func preparation_resources(input: Dictionary) -> Array:
	return [String(input.flame_hold_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = Readiness.resources.get(str(input.get("flame_hold_bank", "")))
	if bank == null or not bank.get("interface_ready"):
		return null
	var result: Node3D = VfxPackageIO_c45116250d.resource("res://assets/vfx/extensions/production-review-20261020/sources/c45116250daeb04fd3bd/current_item_flame_hold.gd").new()
	var original_input: Dictionary = input.duplicate(true)
	for field in ["item_uuid", "effect_uuid", "holder_uuid"]:
		original_input[field] = ""
	result.source = HoldSource.new()
	result.source.build(bank, original_input)
	result.source.name = "RetainedSourceAuthoredHold"
	result.add_child(result.source)
	return result


func prepare_source_layer_mask(mask: int) -> void:
	for emitter: GPUParticles3D in source.systems:
		emitter.layers = mask


func capture_observation() -> Dictionary:
	var result: Dictionary = source.capture_observation()
	result.immutable_item_effect_owner = item_identity.duplicate(true)
	result.current_holder_uuid = current_holder_uuid
	result.same_private_source_retained = true
	result.bounded_clock_candidate = true
	# This describes the sampled-time mechanism. Exact bank/native/placement
	# qualification lives in the external receipt, never inferred at runtime.
	result.clock_mode = "bounded_source_hold_and_unwrapped_absolute_material_phase"
	result.seekable = true
	return result

const VfxPackageIO_c45116250d = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
