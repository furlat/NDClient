extends RefCounted
## Selected immutable source; actual owner/construction facts remain caller-owned.
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/25d570c7aba326c3e0ab/stone_corner.tres"
const Public = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/0c3545ea87a73aa63c5e/occurrence.gd")

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_90d3c21331.resource(PHASE)
	return Public.make_component(actual)

const VfxPackageIO_90d3c21331 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
