extends RefCounted
## Selected immutable source; actual owner/construction facts remain caller-owned.
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/fff2b41147e30064ec0a/ice_dome.tres"
const Public = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/0c3545ea87a73aa63c5e/occurrence.gd")

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_88866e09bd.resource(PHASE)
	return Public.make_component(actual)

const VfxPackageIO_88866e09bd = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
