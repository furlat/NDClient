extends RefCounted
const PHASE="res://assets/vfx/extensions/owner-fields-v2-20261021/sources/f5fc7634962a11007e65/stinking_cloud-phase.tres"
const Public=preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/6385949230b548207e67/public.gd")
static func make_component(input: Dictionary) -> Node3D:
	var phase: Resource=VfxPackageIO_8613c1d49e.resource(PHASE)
	return Public.make_for_phase(phase,input) if phase!=null else null

const VfxPackageIO_8613c1d49e = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
