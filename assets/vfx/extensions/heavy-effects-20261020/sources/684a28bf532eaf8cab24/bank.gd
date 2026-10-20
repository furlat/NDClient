extends Resource
## Exact offline lowering of one existing authored Fire Wall assembly.
## No encounter, actor, mutable clock or sampled particle history is saved.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var source_phase := ""
@export var source_sha256 := ""
@export var source_parameters: Dictionary = {}
@export var program: Script
@export var operands: Array = []
@export var material_specs: Array[Dictionary] = []
@export var node_specs: Array[Dictionary] = []
@export var entries: Array[Dictionary] = []
@export var world_process_units: Array[Dictionary] = []
@export var preparation_receipt: Dictionary = {}
@export var stable_paths_verified := false
var interface_prepared := false

func prepare_immutable_interface() -> void:
	if interface_prepared:
		return
	var meshes := {}
	for definition in node_specs:
		for property in definition.properties:
			var operand: Dictionary = property.operand
			var value: Variant = operand.get("mesh") if operand.kind == "private_surface_mesh" else operand.get("value")
			if value is Mesh and not meshes.has(value):
				meshes[value] = true
				value.get_rid()
	var programs := {}
	for specification in material_specs:
		var shader: Shader = specification.shader
		if programs.has(shader):
			continue
		programs[shader] = true
		shader.get_shader_uniform_list()
		SourceMaterials.declared_uniforms(shader)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.get_property_list()
	interface_prepared = true
