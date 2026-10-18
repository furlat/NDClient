extends "res://assets/vfx/sources/5944248dd6bb52ef8394/class_action.gd"
const Motion = preload("res://assets/vfx/sources/584a1116b96d865072e3/strip_motion.gd")


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_5ab0d0eb20.resource("res://assets/vfx/sources/5ab0d0eb20f55fac8240/class_strips.gd").new()
	node.settings = input.duplicate(true)
	node.kind = input.kind
	node._build()
	return node


func _piece(family: String, index: int) -> MeshInstance3D:
	var piece := super._piece(family, index)
	if kind not in ["roar", "presence"]:
		Motion.prepare(piece.material_override, kind, index)
	return piece


func _strip(_index: int, _seconds: float) -> ArrayMesh:
	return Motion.mesh(48)

const VfxPackageIO_5ab0d0eb20 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
