extends "res://assets/vfx/extensions/wall-child-v3-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
const PHASE="res://assets/vfx/extensions/wall-child-v3-20261021/sources/2503267e57482def9940/phase.tres"
const Construction=preload("res://assets/vfx/extensions/wall-child-v3-20261021/sources/3260d6d49f491d21e909/frigid_air_child_construction.gd")
static func make_component(input: Dictionary) -> Node3D:
	var phase: Resource=VfxPackageIO_77685eed96.resource(PHASE)
	if phase==null: return null
	var value:=Construction.clip_for(phase,input)
	if value.is_empty(): return null
	var node: Node3D=VfxPackageIO_77685eed96.resource("res://assets/vfx/extensions/wall-child-v3-20261021/sources/77685eed96e701f52da0/frigid_air_child_v3_occurrence.gd").new()
	node.parameters=input.duplicate(true)
	node.parameters.clip=value
	return node
func set_zone_geometry(value: Dictionary) -> void: forward("set_zone_geometry",value)
func set_owner_state(value: Dictionary) -> void: forward("set_owner_state",value)

const VfxPackageIO_77685eed96 = preload("res://assets/vfx/extensions/wall-child-v3-20261021/scoped_resource_io.gd")
