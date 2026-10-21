extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
## Same explicit constructor transport, with actual immutable wall construction.
const WallInput = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/7a3794083f3e06b956ad/input.gd")


static func make_component(input: Dictionary) -> Node3D:
	var phase: Variant = input.get("phase")
	if not phase is Resource or phase.resource_path.is_empty() or not phase.has_method("validate"):
		return null
	var operands: Variant = input.get("operands")
	if not operands is Array or operands.size() != 1 or not operands[0] is Dictionary:
		return null
	var operand: Dictionary = operands[0]
	if operand.get("component_path") != ["effect"] or operand.get("input_field", "") != "":
		return null
	var values: Variant = operand.get("values")
	if not values is Dictionary or values.size() != 3:
		return null
	for key: String in ["wall_uuid", "anchor_position", "wall_geometry"]:
		if not values.has(key):
			return null
	var clip: Dictionary = phase.to_clip()
	if clip.components.size() != 1 or clip.components[0].id != "effect":
		return null
	for key: String in values:
		clip.components[0].input[key] = values[key]
	var node: Node3D = VfxPackageIO_b9f0c56911.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/b9f0c56911c9ba3b6812/force_occurrence.gd").new()
	node.parameters = input.duplicate(true)
	node.parameters.clip = clip
	return node


func set_zone_geometry(value: Dictionary) -> void:
	forward("set_zone_geometry", value)

const VfxPackageIO_b9f0c56911 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
