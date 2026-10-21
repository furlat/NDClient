extends RefCounted
const PHASE="res://assets/vfx/extensions/material-runtime-20261021/sources/a48155fd4471e4d25ce2/darkness-phase.tres"
const Public=preload("res://assets/vfx/extensions/material-runtime-20261021/sources/6385949230b548207e67/public.gd")
static func make_component(input: Dictionary) -> Node3D:
	var phase: Resource=VfxPackageIO_899d831709.resource(PHASE)
	return Public.make_for_phase(phase,input) if phase!=null else null

const VfxPackageIO_899d831709 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
