extends Resource
## Immutable source programs/geometry, never targets, events or actual poses.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var source_phase := ""
@export var source_sha256 := ""
@export var settings: Dictionary = {}
@export var program: Script
@export var operands: Array = []
@export var shapes: Array[Resource] = []
@export var templates: Array[ShaderMaterial] = []
@export var node_specs: Array[Dictionary] = []
@export var material_specs: Array[Dictionary] = []
@export var stable_paths_verified := false
@export var receipt: Dictionary = {}
var interface_prepared := false

func prepare_immutable_interface() -> void:
	if interface_prepared: return
	var shaders := {}
	for template in templates:
		if not shaders.has(template.shader):
			shaders[template.shader] = true
			template.shader.get_shader_uniform_list()
			Materials.declared_uniforms(template.shader)
		template.get_property_list()
	for value in operands:
		if value is Mesh: value.get_rid()
	interface_prepared = true
