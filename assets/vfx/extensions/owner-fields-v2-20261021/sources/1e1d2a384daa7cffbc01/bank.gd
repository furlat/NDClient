extends Resource
## Existing native wall surfaces; no scene controller or review lifecycle.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var kind := ""
@export var dome := false
@export var templates: Array[Array] = []
@export var join_template: Array[Dictionary] = []
@export var materials: Array[ShaderMaterial] = []
@export var source_materials: Array[ShaderMaterial] = []
@export var provenance: Dictionary = {}
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Bindings.methods(VfxPackageIO_1e1d2a384d.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/44a07f767e19f1faf49c/wall.gd"))
	for draws: Array in templates:
		for draw: Dictionary in draws:
			draw.mesh.get_rid()
			draw.mesh.get_aabb()
	for draw: Dictionary in join_template:
		draw.mesh.get_rid()
	for material: ShaderMaterial in materials:
		material.shader.get_shader_uniform_list()
		SourceMaterials.declared_uniforms(material.shader)
		material.get_rid()
	interface_ready = true

const VfxPackageIO_1e1d2a384d = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
