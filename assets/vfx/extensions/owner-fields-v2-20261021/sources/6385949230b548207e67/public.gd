extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
## Actual owner is supplied before Source.make. No saved admission packet.
static func clip_for(phase: Resource, input: Dictionary) -> Dictionary:
	var operands: Variant=input.get("operands")
	if not operands is Array or operands.size()!=1 or not operands[0] is Dictionary:
		return {}
	var row: Dictionary=operands[0]
	if row.get("component_path")!=["assembly"] or row.get("input_field","")!="" or not row.get("values") is Dictionary:
		return {}
	var values: Dictionary=row.values
	if not values.get("owner_uuid") is String or values.owner_uuid.is_empty():
		return {}
	for name in values:
		if name not in ["owner_uuid","state","review_states"]:
			return {}
	if not values.get("state",{}) is Dictionary or not values.get("review_states",[]) is Array:
		return {}
	if not values.get("state",{}).is_empty() or not values.get("review_states",[]).is_empty():
		return {}
	var clip: Dictionary=phase.to_clip()
	if clip.components.size()!=1 or clip.components[0].id!="assembly":
		return {}
	clip.components[0].input.merge(values.duplicate(true),true)
	return clip

static func make_for_phase(phase: Resource, input: Dictionary) -> Node3D:
	var value:=clip_for(phase,input)
	if value.is_empty():
		return null
	var node: Node3D=VfxPackageIO_6385949230.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/6385949230b548207e67/public.gd").new()
	node.parameters=input.duplicate(true)
	node.parameters.clip=value
	return node

const VfxPackageIO_6385949230 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
