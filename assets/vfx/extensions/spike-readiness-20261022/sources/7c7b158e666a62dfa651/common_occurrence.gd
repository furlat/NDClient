extends "res://assets/vfx/extensions/spike-readiness-20261022/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
## Existing explicit operand transport; no caller may replace source banks/art.
const ZoneInput = preload("res://assets/vfx/extensions/cell-validation-20261021/sources/bbfe0c8c2a4fd1b29e8d/input.gd")


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
	if not values is Dictionary or not values.get("owner_uuid") is String or values.owner_uuid.is_empty():
		return null
	var clip: Dictionary = phase.to_clip()
	if clip.components.size() != 1 or clip.components[0].id != "effect":
		return null
	var needs_cells: bool = clip.components[0].input.has("cells")
	if values.size() != (2 if needs_cells else 1):
		return null
	if needs_cells:
		var actual := ZoneInput.cells(values.get("cells"))
		if not actual.error.is_empty() or actual.cells.is_empty():
			return null
		clip.components[0].input.cells = values.cells.duplicate(true)
	clip.components[0].input.owner_uuid = values.owner_uuid
	var node: Node3D = VfxPackageIO_7c7b158e66.resource("res://assets/vfx/extensions/spike-readiness-20261022/sources/7c7b158e666a62dfa651/common_occurrence.gd").new()
	node.parameters = input.duplicate(true)
	node.parameters.clip = clip
	return node


func set_zone_geometry(value: Dictionary) -> void:
	forward("set_zone_geometry", value)

const VfxPackageIO_7c7b158e66 = preload("res://assets/vfx/extensions/spike-readiness-20261022/scoped_resource_io.gd")
