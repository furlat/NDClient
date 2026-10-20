extends Resource
## Exact native stems/leaves and their immutable original per-clump transforms.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var source_settings: Dictionary = {}
@export var cells: Array = []
@export var delays: PackedFloat64Array = []
@export var draws: Array[Dictionary] = []
@export var stem_material: ShaderMaterial
@export var leaf_material: ShaderMaterial
@export var process_shader: Shader
@export var light_properties: Dictionary = {}
@export var provenance: Dictionary = {}
var interfaces_prepared := false

func prepare_immutable_interface() -> void:
	if interfaces_prepared:
		return
	for material: ShaderMaterial in [stem_material, leaf_material]:
		material.shader.get_shader_uniform_list()
		material.get_property_list()
		SourceMaterials.declared_uniforms(material.shader)
	process_shader.get_shader_uniform_list()
	var process_interface := ShaderMaterial.new()
	process_interface.shader = process_shader
	process_interface.get_property_list()
	for draw: Dictionary in draws:
		draw.mesh.get_rid()
	interfaces_prepared = true
