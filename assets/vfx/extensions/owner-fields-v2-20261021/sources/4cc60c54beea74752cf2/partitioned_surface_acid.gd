extends RefCounted
## Exact selected prepared material; only real surface ownership is supplied.
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/c4f61f828bfb0cf8a518/acid-phase.tres"
const Public = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/4b351519388bc9f08987/partitioned_surface_occurrence.gd")

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_4cc60c54be.resource(PHASE)
	return Public.make_component(actual)

const VfxPackageIO_4cc60c54be = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
