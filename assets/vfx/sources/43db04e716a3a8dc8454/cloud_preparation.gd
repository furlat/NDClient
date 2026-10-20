extends Resource
## Complete source hierarchy and immutable programs, compiled before an encounter.
## ShaderMaterials local to the scene own occurrence clocks and opacity.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var scene: PackedScene
@export var parameters: Dictionary = {}
@export var geometry_paths: Array[NodePath] = []
@export var material_bindings: Array[Dictionary] = []
@export var cohort_paths: Array = []
@export var kind: int = 0
@export var radius: float = 4.0
@export var source_phase: String = ""
@export var source_script: String = ""
@export var native_process_preparation: Array[Dictionary] = []

@export var node_specs: Array[Dictionary] = []
@export var material_specs: Array[Dictionary] = []
@export var shared_native_processes: bool = false
@export var source_art_variant: String = "original_native_order"
@export var cohort_successor_sorting_offset_delta: float = 0.0
@export var construction_program: Script
@export var construction_operands: Array = []
@export var construction_program_receipt: Dictionary = {}
var immutable_interface_prepared := false

func prepare_immutable_interface() -> void:
	if immutable_interface_prepared:
		return
	var meshes := {}
	for definition: Dictionary in node_specs:
		for property: Dictionary in definition.properties:
			var operand: Dictionary = property.operand
			var value: Variant = operand.get("mesh") if operand.kind == "private_surface_mesh" else operand.get("value")
			if value is Mesh and not meshes.has(value):
				meshes[value] = true
				# PrimitiveMesh builds native vertex/index buffers lazily at RID
				# access. Its immutable geometry belongs before publication, not
				# to the first owner's draw_pass setter. No material is mutated.
				value.get_rid()
	var shaders := {}
	for definition: Dictionary in material_specs:
		var shader: Shader = definition.shader
		if not shaders.has(shader):
			shaders[shader] = true
			# ShaderMaterial's initial parameter reflection is shared program
			# work. Resolve it before publication, using a transient Resource
			# only: no Node, source sample, owner inputs or occurrence clock.
			shader.get_shader_uniform_list()
			# The source opacity adapter consumes this exact expanded textual
			# interface. Prepare its immutable cache too, rather than parsing
			# the long source program during the first owner's registration.
			SourceMaterials.declared_uniforms(shader)
			var reflection := ShaderMaterial.new()
			reflection.shader = shader
			reflection.get_property_list()
		if definition.get("immutable_native_process", false):
			var material: ShaderMaterial = definition.immutable_material
			assert(material.get_meta("factory_immutable_native_process", "") == "local_coords_static_native_operands")
			material.get_property_list()
			material.get_rid()
	immutable_interface_prepared = true
