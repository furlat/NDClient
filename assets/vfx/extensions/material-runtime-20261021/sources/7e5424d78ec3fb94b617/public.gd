extends "res://assets/vfx/extensions/material-runtime-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
## Actual current wall operands, no fixture identity or private event defaults.
static func clip_for(phase: Resource,input: Dictionary) -> Dictionary:
	var rows: Variant=input.get("operands")
	if not rows is Array or rows.size()!=1 or not rows[0] is Dictionary:
		return {}
	var row: Dictionary=rows[0]
	if row.get("component_path")!=["assembly"] or row.get("input_field","")!="" or not row.get("values") is Dictionary:
		return {}
	var values: Dictionary=row.values
	if values.size()!=3 or not values.has("wall_uuid") or not values.has("anchor_position") or not values.has("wall_geometry"):
		return {}
	var clip: Dictionary=phase.to_clip()
	if clip.components.size()!=1 or clip.components[0].id!="assembly":
		return {}
	clip.components[0].input.merge(values.duplicate(true),true)
	return clip

static func make_for_phase(phase: Resource,input: Dictionary) -> Node3D:
	var clip:=clip_for(phase,input)
	if clip.is_empty():
		return null
	var node: Node3D=VfxPackageIO_7e5424d78e.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/7e5424d78ec3fb94b617/public.gd").new()
	node.parameters=input.duplicate(true)
	node.parameters.clip=clip
	return node

const VfxPackageIO_7e5424d78e = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
