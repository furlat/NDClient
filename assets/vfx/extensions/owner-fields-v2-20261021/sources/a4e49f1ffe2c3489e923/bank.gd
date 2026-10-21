extends Resource
## Original native display operands, prepared once outside occurrence creation.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var original_material: ShaderMaterial
@export var partition_material: ShaderMaterial
@export var style := ""
@export var capacity := 0
@export var surface_kind := ""
@export var source_input: Dictionary = {}
@export var provenance: Dictionary = {}
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Bindings.methods(VfxPackageIO_a4e49f1ffe.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/e337e0c543aa9b9a17b2/field.gd"))
	for material: ShaderMaterial in [original_material, partition_material]:
		material.shader.get_shader_uniform_list()
		Materials.declared_uniforms(material.shader)
		material.get_rid()
	interface_ready = true

const VfxPackageIO_a4e49f1ffe = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
