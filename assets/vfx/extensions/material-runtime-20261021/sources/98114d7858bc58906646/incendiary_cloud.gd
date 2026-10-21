extends RefCounted
const PHASE="res://assets/vfx/extensions/material-runtime-20261021/sources/84f1a38fb39b341e94a1/incendiary_cloud-phase.tres"
const Public=preload("res://assets/vfx/extensions/material-runtime-20261021/sources/6385949230b548207e67/public.gd")
static func make_component(input: Dictionary) -> Node3D:
	var phase: Resource=VfxPackageIO_98114d7858.resource(PHASE)
	return Public.make_for_phase(phase,input) if phase!=null else null

const VfxPackageIO_98114d7858 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
