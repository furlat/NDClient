extends RefCounted
## Exact selected prepared material; only real surface ownership is supplied.
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/fa99b9d3dd611519f073/poison-phase.tres"
const Public = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/4b351519388bc9f08987/partitioned_surface_occurrence.gd")

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_73a1ccc511.resource(PHASE)
	return Public.make_component(actual)

const VfxPackageIO_73a1ccc511 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
