extends "res://assets/vfx/sources/0c9d39e3c630f718d4cb/rage_open_lifts.gd"
const Motion = preload("res://assets/vfx/sources/584a1116b96d865072e3/strip_motion.gd")


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_1f4157265e.resource("res://assets/vfx/sources/1f4157265ee040a8fe10/rage_strips.gd").new()
	node.settings = input.duplicate(true)
	node.kind = input.kind
	node.owner_projection = input.owner_projection.duplicate(true)
	node.feedback_events = input.get("feedback_events", []).duplicate(true)
	node._validate_projection(node.owner_projection)
	node._build()
	return node


func _piece(family: String, index: int) -> MeshInstance3D:
	var piece := super._piece(family, index)
	Motion.prepare(piece.material_override, "rage_open", index)
	return piece


func _strip(_index: int, _seconds: float) -> ArrayMesh:
	return Motion.mesh(32, true)

const VfxPackageIO_1f4157265e = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
