extends Resource
## Immutable native donor and station meshes. No endpoint or occurrence state.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var source_parameters: Dictionary = {}
@export var materials: Array[ShaderMaterial] = []
@export var draws: Array[Dictionary] = []
@export var groups: Dictionary = {}
@export var material_roles: Dictionary = {}
@export var atlas_definitions: Array[Dictionary] = []
@export var provenance: Dictionary = {}
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Bindings.methods(VfxPackageIO_08de1e902d.resource("res://assets/vfx/extensions/late-20261020/sources/d7935024e5867aba3106/delivery.gd"))
	for material in materials:
		material.get_property_list()
		material.shader.get_shader_uniform_list()
		SourceMaterials.declared_uniforms(material.shader)
	# Primitive donor/drop meshes may defer their actual native surface/RID
	# creation until first use. This immutable work belongs before publication.
	var visited := {}
	for record in draws:
		if not visited.has(record.mesh):
			record.mesh.get_rid()
			visited[record.mesh] = true
	interface_ready = true

const VfxPackageIO_08de1e902d = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
