extends "res://assets/vfx/sources/fc300d1a9a63c4201a1b/recovery_continuous_flow.gd"
const Motion = preload("res://assets/vfx/sources/584a1116b96d865072e3/strip_motion.gd")


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_3236cda460.resource("res://assets/vfx/sources/3236cda460f27e781de6/recovery_strips.gd").new()
	node.settings = input.duplicate(true)
	assert(node.set_owner_projection(input.owner_projection))
	node._build()
	for index in node.pieces.size():
		Motion.prepare(node.pieces[index].material_override, "recovery", index)
	node.sample(0.0)
	return node


func build_strip(_index: int, _seconds: float) -> ArrayMesh:
	return Motion.mesh(32)

const VfxPackageIO_3236cda460 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
