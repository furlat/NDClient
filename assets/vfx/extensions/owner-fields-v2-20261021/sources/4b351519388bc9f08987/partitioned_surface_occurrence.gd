extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
## Existing selected PhaseResource, one actual surface UUID; no saved owner.

static func make_component(input: Dictionary) -> Node3D:
	var phase: Variant = input.get("phase")
	if not phase is Resource or phase.components.size() != 1:
		return null
	var part: Resource = phase.components[0]
	if part.component_id != "effect" or part.constructor_script != "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/e337e0c543aa9b9a17b2/field.gd":
		return null
	var operands: Variant = input.get("operands")
	if not operands is Array or operands.size() != 1 or not operands[0] is Dictionary:
		return null
	var operand: Dictionary = operands[0]
	var values: Variant = operand.get("values")
	if operand.get("component_path") != ["effect"] or operand.get("input_field", "") != "" or not values is Dictionary or values.size() != 1 or not values.get("surface_uuid") is String or values.surface_uuid.is_empty():
		return null
	var clip: Dictionary = phase.to_clip()
	clip.components[0].input.surface_uuid = values.surface_uuid
	var node: Node3D = VfxPackageIO_4b35151938.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/4b351519388bc9f08987/partitioned_surface_occurrence.gd").new()
	node.parameters = input.duplicate(true)
	node.parameters.clip = clip
	return node

func set_surface_partition(value: Dictionary) -> void:
	forward("set_surface_partition", value)

const VfxPackageIO_4b35151938 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
