extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/86d0b2fffd0729d7e4d1/bank.gd"
## Same captured source; immutable native RID handles are lowered once in readiness.
var mesh_rids: Array[RID] = []
@export var transform_publisher: Script


func _controller_path() -> String:
	return "res://assets/vfx/extensions/spirit-receiver-20261022/sources/76db23b5acd9f6737e38/piece_v2.gd"


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	super.prepare_immutable_interface()
	for mesh: Mesh in meshes:
		mesh_rids.append(mesh.get_rid())
