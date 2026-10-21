extends Resource
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var form := ""
@export var material: ShaderMaterial
@export var original_material: ShaderMaterial
@export var mesh: Mesh
@export var transforms: Array[Transform3D] = []
@export var apply_seconds := 0.55
@export var opacity := 0.55
@export var phase_offset_seconds := 0.0
@export var provenance: Dictionary = {}
var multimesh: MultiMesh
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Bindings.methods(VfxPackageIO_074930982d.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/4e25b68ea00e63a2559b/field.gd"))
	mesh.get_rid()
	if form == "cage":
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for index in transforms.size():
			multimesh.set_instance_transform(index, transforms[index])
	for item: ShaderMaterial in [material, original_material]:
		item.shader.get_shader_uniform_list()
		Materials.declared_uniforms(item.shader)
		item.get_rid()
	interface_ready = true

const VfxPackageIO_074930982d = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
