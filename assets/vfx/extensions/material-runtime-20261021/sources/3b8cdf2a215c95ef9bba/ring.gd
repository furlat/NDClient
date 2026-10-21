extends RefCounted
const PHASE="res://assets/vfx/extensions/material-runtime-20261021/sources/5e0a32e28e7fc4debd88/ring-phase.tres"
const Public=preload("res://assets/vfx/extensions/material-runtime-20261021/sources/7e5424d78ec3fb94b617/public.gd")
static func make_component(input: Dictionary) -> Node3D:
	var phase: Resource=VfxPackageIO_3b8cdf2a21.resource(PHASE)
	return Public.make_for_phase(phase,input) if phase!=null else null

const VfxPackageIO_3b8cdf2a21 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
