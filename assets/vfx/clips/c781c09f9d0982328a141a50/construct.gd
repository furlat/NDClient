extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/92882958bc5101892ef0/cloudkill.tres"
const Public = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/6385949230b548207e67/public.gd")

static func make_component(input: Dictionary) -> Node3D:
	return Public.make_for_phase(load(PHASE), input)
