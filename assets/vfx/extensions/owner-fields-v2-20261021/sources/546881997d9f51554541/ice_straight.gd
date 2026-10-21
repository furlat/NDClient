extends RefCounted
## Selected immutable source; actual owner/construction facts remain caller-owned.
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/d3b02cdefe76a9e1ab14/ice_straight.tres"
const Public = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/0c3545ea87a73aa63c5e/occurrence.gd")

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_546881997d.resource(PHASE)
	return Public.make_component(actual)

const VfxPackageIO_546881997d = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
