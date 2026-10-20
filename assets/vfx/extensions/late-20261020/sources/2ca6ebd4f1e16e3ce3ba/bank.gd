extends Resource
## One exact source recording. These data are immutable; actors, clocks, root
## transforms and private material values never live in this resource.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var scene: PackedScene
@export var materials: Array[ShaderMaterial] = []
@export var material_sites: Array[Dictionary] = []
@export var material_roots: Array[Dictionary] = []
@export var geometry_paths: Array[NodePath] = []
@export var runtime_node_paths: Array[NodePath] = []
@export var geometry_indices: Array[int] = []
@export var node_tracks: Array[Dictionary] = []
@export var material_tracks: Array[Dictionary] = []
@export var initial_node_values: Array = []
@export var initial_material_values: Array = []
@export var frame_node_indices: Array = []
@export var frame_material_indices: Array = []
@export var all_node_indices := PackedInt32Array()
@export var all_material_indices := PackedInt32Array()
@export var source_matrices: Array = []
@export var rate := 60.0
@export var frames := 211
@export var seconds := 3.5
@export var provenance: Dictionary = {}
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Bindings.methods(VfxPackageIO_2ca6ebd4f1.resource("res://assets/vfx/extensions/late-20261020/sources/409ac0cf4680d6f5add0/field.gd"))
	for material in materials:
		material.get_property_list()
		SourceMaterials.declared_uniforms(material.shader)
	interface_ready = true

const VfxPackageIO_2ca6ebd4f1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
