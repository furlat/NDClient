extends RefCounted
const PHASE="res://assets/vfx/extensions/owner-fields-v2-20261021/sources/d8ecd83764d1b85daf91/segment-phase.tres"
const Public=preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/7e5424d78ec3fb94b617/public.gd")
static func make_component(input: Dictionary) -> Node3D:
	var phase: Resource=VfxPackageIO_ccdcfe2f05.resource(PHASE)
	return Public.make_for_phase(phase,input) if phase!=null else null

const VfxPackageIO_ccdcfe2f05 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
