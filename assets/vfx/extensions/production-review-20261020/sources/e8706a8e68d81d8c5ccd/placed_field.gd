extends "res://assets/vfx/extensions/production-review-20261020/sources/1d0fb3f4a40d1c380fae/field.gd"
const Placement = preload("res://assets/vfx/extensions/production-review-20261020/sources/9c6c13300477124c2cf5/recorded_placement.gd")
var placement_bindings: Array = []
var placement_error := ""


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.recorded_geometry_bank)]


static func make_component(input: Dictionary) -> Node3D:
	var prepared: Resource = Readiness.resources.get(str(input.get("recorded_geometry_bank", "")))
	if prepared == null or not prepared.interface_ready or not prepared.provenance.get("fixed_static_no_history", false) \
			or prepared.system_node_indices.size() != 1 or prepared.process_program == null:
		return null
	var effect: Node3D = VfxPackageIO_e8706a8e68.resource("res://assets/vfx/extensions/production-review-20261020/sources/e8706a8e68d81d8c5ccd/placed_field.gd").new()
	SharedField.restore(effect, prepared)
	if not prepared.native_standard_indices.is_empty(): NativeStandard.restore(effect)
	effect.vat_state = VatState.new(effect)
	var admitted := Placement.prepare(effect.subject, prepared.material_placements, prepared.private_materials, effect.materials)
	if not admitted.error.is_empty():
		effect.free()
		return null
	effect.placement_bindings = admitted.bindings
	return effect


func sample(seconds: float) -> void:
	super.sample(seconds)
	_apply_placement()


func refresh_live_inputs(seconds: float) -> void:
	super.refresh_live_inputs(seconds)
	_apply_placement()


func _apply_placement() -> void:
	placement_error = Placement.apply(placement_bindings)
	if not placement_error.is_empty(): hide()

const VfxPackageIO_e8706a8e68 = preload("res://assets/vfx/extensions/production-review-20261020/scoped_resource_io.gd")
