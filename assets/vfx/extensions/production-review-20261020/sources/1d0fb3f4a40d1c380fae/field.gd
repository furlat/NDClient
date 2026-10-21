extends "res://assets/vfx/extensions/production-review-20261020/sources/2cd710be3201c544db8f/field.gd"
## Exact shared recorded values plus private, continuously evaluated fixed VAT.
const SharedField = preload("res://assets/vfx/extensions/production-review-20261020/sources/2cd710be3201c544db8f/field.gd")
const VatState = preload("res://assets/vfx/extensions/followup-20261020/sources/4197ecf4c6636711c3a9/state.gd")
const NativeStandard = preload("res://assets/vfx/extensions/followup-20261020/sources/5a0319d9a7633b996a94/native_standard_restore.gd")
var vat_state: RefCounted

static func preparation_resources(input: Dictionary) -> Array:
	# Script.has_method does not reliably expose inherited static callbacks.
	# Declare this exact source resource boundary on the actual adapter.
	return [str(input.recorded_geometry_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.recorded_geometry_bank)
	assert(Readiness.resources.has(path),"Prepare exact static VAT Resources before admission")
	var prepared: Resource = Readiness.resources[path]
	assert(prepared.interface_ready and prepared.provenance.fixed_static_no_history
		and not prepared.provenance.zero_systems_no_history)
	assert(prepared.system_node_indices.size() == prepared.provenance.recorded_particle_systems
		and prepared.system_node_indices.size() > 0 and prepared.process_program != null,
		"Unknown/missing recorded particle ownership cannot fall back to an empty geometry source")
	var effect: Node3D = VfxPackageIO_1d0fb3f4a4.resource("res://assets/vfx/extensions/production-review-20261020/sources/1d0fb3f4a40d1c380fae/field.gd").new()
	SharedField.restore(effect,prepared)
	if not prepared.native_standard_indices.is_empty():
		NativeStandard.restore(effect)
	effect.vat_state = VatState.new(effect)
	return effect

func source_bindings() -> Dictionary:
	var result := super.source_bindings()
	result.materials = materials + vat_state.materials
	result.recorded_time_emitters = vat_state.emitters
	return result

func sample(seconds: float) -> void:
	var changed := not sampled or not is_equal_approx(last_age,seconds)
	super.sample(seconds)
	if changed:
		vat_state.sample(last_age)

func stop_emission(seconds: float) -> void:
	vat_state.stop_emission(seconds)

const VfxPackageIO_1d0fb3f4a4 = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
