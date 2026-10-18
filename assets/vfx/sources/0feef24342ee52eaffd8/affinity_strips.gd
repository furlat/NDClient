extends "res://assets/vfx/sources/7a4debf7a4e98e145e6c/affinity_open_arcs.gd"
const Motion = preload("res://assets/vfx/sources/584a1116b96d865072e3/strip_motion.gd")


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_0feef24342.resource("res://assets/vfx/sources/0feef24342ee52eaffd8/affinity_strips.gd").new()
	node.settings = input.duplicate(true)
	node.kind = input.kind
	node._build()
	return node


func _piece(family: String, index: int) -> MeshInstance3D:
	var piece := super._piece(family, index)
	Motion.prepare(piece.material_override, "affinity_open", index)
	return piece


func _strip(_index: int, _seconds: float) -> ArrayMesh:
	return Motion.mesh(48)

const VfxPackageIO_0feef24342 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
