extends Resource
## Immutable existing mist/quads/programs; no wall, donor, encounter or owner.
const Bindings=preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Materials=preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var volume_mesh: Mesh
@export var flake_meshes: Array[Mesh]=[]
@export var materials: Array[ShaderMaterial]=[]
@export var source_volume_material: ShaderMaterial
@export var source_flake_material: ShaderMaterial
@export var source_volume_transform := Transform3D.IDENTITY
@export var provenance: Dictionary={}
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready: return
	Bindings.methods(VfxPackageIO_0697d1c746.resource("res://assets/vfx/extensions/wall-child-v3-20261021/sources/39a8f882a0878cd303e3/field.gd"))
	volume_mesh.get_rid()
	for mesh: Mesh in flake_meshes: mesh.get_rid()
	for material: ShaderMaterial in materials:
		material.shader.get_shader_uniform_list()
		Materials.declared_uniforms(material.shader)
		material.get_rid()
	interface_ready=true

const VfxPackageIO_0697d1c746 = preload("res://assets/vfx/extensions/wall-child-v3-20261021/scoped_resource_io.gd")
