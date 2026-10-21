extends RefCounted
## Selected immutable source; actual owner/construction facts remain caller-owned.
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/6a55e15534f0bfc573bf/box.tres"
const Public = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/99f1d493f68d090d7e35/observed_forcecage_occurrence.gd")

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_e91096bd61.resource(PHASE)
	return Public.make_component(actual)

const VfxPackageIO_e91096bd61 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
