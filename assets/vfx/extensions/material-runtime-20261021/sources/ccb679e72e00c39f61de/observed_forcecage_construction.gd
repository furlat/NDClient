extends RefCounted
const CageInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/85d97d458c33910ca580/input.gd")

static func clip_for(phase: Resource, input: Dictionary) -> Dictionary:
	var operands: Variant = input.get("operands")
	if not operands is Array or operands.size() != 1 or not operands[0] is Dictionary:
		return {}
	var operand: Dictionary = operands[0]
	if operand.get("component_path") != ["field"] or operand.get("input_field", "") != "":
		return {}
	var values: Variant = operand.get("values")
	if not values is Dictionary or values.size() != 3:
		return {}
	var clip: Dictionary = phase.to_clip()
	if clip.components.size() != 1 or clip.components[0].id != "field":
		return {}
	var bank: Resource = VfxPackageIO_ccb679e72e.resource(str(clip.components[0].input.observed_cage_bank))
	if not CageInput.construction(values, bank.form).error.is_empty():
		return {}
	for key in ["wall_uuid", "anchor_position", "wall_geometry"]:
		clip.components[0].input[key] = values[key].duplicate(true) if values[key] is Dictionary or values[key] is Array else values[key]
	return clip

const VfxPackageIO_ccb679e72e = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
