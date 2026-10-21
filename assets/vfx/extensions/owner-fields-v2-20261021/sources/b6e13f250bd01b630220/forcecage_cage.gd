extends RefCounted
## Selected immutable source; actual owner/construction facts remain caller-owned.
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/c2436b5e61eb0d3f988a/cage.tres"
const Public = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/99f1d493f68d090d7e35/observed_forcecage_occurrence.gd")

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_b6e13f250b.resource(PHASE)
	return Public.make_component(actual)

const VfxPackageIO_b6e13f250b = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
