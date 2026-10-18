extends "res://assets/vfx/sources/861a64dfc7b97476a8d9/accepted_ground_source_v191.gd"
const Motion = preload("res://assets/vfx/sources/584a1116b96d865072e3/strip_motion.gd")


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_0bbbce20d9.resource("res://assets/vfx/sources/0bbbce20d9e5bebc4ff3/ground_strips.gd").new()
	node.settings = input.duplicate(true)
	assert(node.set_owner_projection(input.owner_projection))
	assert(node.set_activation_projection(input.activation_projection))
	node._build()
	for index in node.pieces.size():
		Motion.prepare(node.pieces[index].material_override, "accepted_ground", index)
	node.sample(0.0)
	return node


func build_strip(_index: int, _seconds: float) -> ArrayMesh:
	return Motion.mesh(32)

const VfxPackageIO_0bbbce20d9 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
