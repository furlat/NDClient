extends "res://assets/vfx/extensions/material-runtime-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
## Two actual native material layers, one current surface owner and clock.
const FIELD := "res://assets/vfx/extensions/material-runtime-20261021/sources/e337e0c543aa9b9a17b2/field.gd"


static func make_component(input: Dictionary) -> Node3D:
	var phase: Variant = input.get("phase")
	if not phase is Resource or phase.components.size() != 2:
		return null
	for index in 2:
		var part: Resource = phase.components[index]
		if part.constructor_script != FIELD or part.component_id != ["ground", "film"][index]:
			return null
	var operands: Variant = input.get("operands")
	if not operands is Array or operands.size() != 1 or not operands[0] is Dictionary:
		return null
	var operand: Dictionary = operands[0]
	var values: Variant = operand.get("values")
	if operand.get("component_path") != ["surface"] or operand.get("input_field", "") != "" or not values is Dictionary or values.size() != 1 or not values.get("surface_uuid") is String or values.surface_uuid.is_empty():
		return null
	var clip: Dictionary = phase.to_clip()
	for part: Dictionary in clip.components:
		part.input.surface_uuid = values.surface_uuid
	var node: Node3D = VfxPackageIO_15fc5c01e0.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/15fc5c01e0fc2f3f813d/liquid_occurrence.gd").new()
	node.parameters = input.duplicate(true)
	node.parameters.clip = clip
	return node


func _ready() -> void:
	super._ready()
	if construction_error.is_empty():
		# The original two puddle scenes explicitly set this on Ground while
		# Glow keeps its native zero. It is a draw-order operand, not opacity.
		handle.components.ground.plane.sorting_offset = -0.5
		handle.components.film.plane.sorting_offset = 0.0


func set_surface_partition(value: Dictionary) -> void:
	forward("set_surface_partition", value)

const VfxPackageIO_15fc5c01e0 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
