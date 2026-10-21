extends RefCounted
const PHASE="res://assets/vfx/extensions/material-runtime-20261021/sources/f094d2311ca09245c364/segment-phase.tres"
const Public=preload("res://assets/vfx/extensions/material-runtime-20261021/sources/7e5424d78ec3fb94b617/public.gd")
static func make_component(input: Dictionary) -> Node3D:
	var phase: Resource=VfxPackageIO_bf22f7e2aa.resource(PHASE)
	return Public.make_for_phase(phase,input) if phase!=null else null

const VfxPackageIO_bf22f7e2aa = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
