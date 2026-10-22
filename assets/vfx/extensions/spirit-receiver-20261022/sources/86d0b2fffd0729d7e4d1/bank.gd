extends Resource
## Exact captured Spirit meshes/transforms; no occurrence or prototype in readiness.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
@export var source_bank: Resource
@export var material_program: Script
@export var skeleton_names := PackedStringArray()
@export var skeleton_parents := PackedInt32Array()
@export var skeleton_transforms: Array[Transform3D] = []
@export var wing_indices := PackedInt32Array()
@export var draw_paths := PackedStringArray()
@export var draw_parents := PackedInt32Array()
@export var draw_transforms: Array[Transform3D] = []
@export var mesh_operand_indices := PackedInt32Array()
@export var geometry_states: Array[Dictionary] = []
@export var subject_scene_file_path := ""
@export var geometry_paths: Array[NodePath] = []
@export var restart_paths: Array[NodePath] = []
var interface_ready := false
var stable_paths_prepared := true
var meshes: Array[Mesh] = []


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	source_bank.prepare_immutable_interface()
	for index: int in mesh_operand_indices:
		meshes.append(source_bank.construction_operands[index])
	for mesh: Mesh in meshes:
		mesh.get_rid()
		mesh.get_aabb()
	interface_ready = source_bank.interface_ready


func _controller_path() -> String:
	return "res://assets/vfx/extensions/spirit-receiver-20261022/sources/e3eff9f66a399b9d47ad/piece.gd"


func restore_controller(script_path: String, input: Dictionary) -> Node3D:
	if not interface_ready or script_path != _controller_path():
		return null
	var node: Node3D = VfxPackageIO_86d0b2fffd.resource(script_path).new()
	node.parameters = input.duplicate(true)
	node.parameters.lifecycle_sampling = "analytical"
	node.settings = input.settings.duplicate(true)
	node.side = input.side
	node.native_bank = self
	Profile.begin("spirit_rid_skeleton")
	var skeleton: Array[Node3D] = []
	for index: int in skeleton_names.size():
		var part := Node3D.new()
		part.name = skeleton_names[index]
		part.transform = skeleton_transforms[index]
		if skeleton_parents[index] >= 0:
			skeleton[skeleton_parents[index]].add_child(part)
			part.owner = skeleton[0]
		skeleton.append(part)
	node.subject = skeleton[0]
	node.subject.scene_file_path = subject_scene_file_path
	node.add_child(node.subject)
	for index: int in wing_indices:
		node.wings.append(skeleton[index])
	Profile.end("spirit_rid_skeleton")
	Profile.begin("spirit_rid_material")
	var material: ShaderMaterial = material_program.material(source_bank.construction_operands)
	Profile.end("spirit_rid_material")
	node.mats.append(material)
	node.native_skeleton = skeleton
	node.native_material = material
	node.seeds = source_bank.seeds.duplicate(true)
	node.prepared = true
	node.set_meta("prepared_timed_bank", self)
	node.set_meta("prepared_timed_subject", node.subject)
	node.set_meta("prepared_timed_materials", [material])
	node.set_meta("prepared_timed_geometry", [])
	node.set_meta("prepared_source_players", [])
	node.set_meta("prepared_source_lights", [])
	Profile.begin("spirit_rid_draw_construction")
	var created: bool = node.create_native_draws()
	Profile.end("spirit_rid_draw_construction")
	if not created:
		node.free()
		return null
	return node

const VfxPackageIO_86d0b2fffd = preload("res://assets/vfx/extensions/spirit-receiver-20261022/scoped_resource_io.gd")
