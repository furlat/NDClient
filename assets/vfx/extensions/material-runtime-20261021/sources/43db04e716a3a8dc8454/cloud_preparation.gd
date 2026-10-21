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
var _prepare_node := 0
var _prepare_property := 0
var _prepare_material := 0
var _prepare_material_step := 0
var _prepared_meshes := {}
var _prepared_shaders := {}
var _preparation_error := ""

func prepare_immutable_interface() -> void:
	# Synchronous authoring compatibility. Runtime readiness calls the unit hook
	# below instead; it must not hide the whole bank in one publication step.
	while not immutable_interface_prepared:
		var progress := prepare_immutable_interface_step()
		if not str(progress.get("error", "")).is_empty():
			push_error(progress.error)
			return


func prepare_immutable_interface_step() -> Dictionary:
	if not _preparation_error.is_empty():
		return {"complete": false, "error": _preparation_error}
	if immutable_interface_prepared:
		return {"complete": true, "operation": "already_prepared"}
	# One source node or native operation per call. No up-front full-bank scan,
	# owner construction, clock change, GPU readback or budget-based retry.
	if _prepare_node < node_specs.size():
		var definition: Dictionary = node_specs[_prepare_node]
		while _prepare_property < definition.properties.size():
			var operand: Dictionary = definition.properties[_prepare_property].operand
			_prepare_property += 1
			var value: Variant = operand.get("mesh") if operand.kind == "private_surface_mesh" else operand.get("value")
			if value is Mesh and not _prepared_meshes.has(value):
				_prepared_meshes[value] = true
				# Native PrimitiveMesh geometry is generated here, before publication.
				value.get_rid()
				return {"complete": false, "operation": "mesh_rid"}
		_prepare_node += 1
		_prepare_property = 0
		return {"complete": false, "operation": "inspect_node"}
	if _prepare_material < material_specs.size():
		var definition: Dictionary = material_specs[_prepare_material]
		var shader: Shader = definition.shader
		var operation := "next_material"
		if _prepare_material_step == 0:
			if not _prepared_shaders.has(shader):
				_prepared_shaders[shader] = true
				shader.get_shader_uniform_list()
				_prepare_material_step = 1
				return {"complete": false, "operation": "shader_uniform_interface"}
			_prepare_material_step = 3
		if _prepare_material_step == 1:
			SourceMaterials.declared_uniforms(shader)
			_prepare_material_step = 2
			return {"complete": false, "operation": "shader_text_interface"}
		if _prepare_material_step == 2:
			var reflection := ShaderMaterial.new()
			reflection.shader = shader
			reflection.get_property_list()
			_prepare_material_step = 3
			return {"complete": false, "operation": "shader_material_interface"}
		if definition.get("immutable_native_process", false):
			var material: ShaderMaterial = definition.immutable_material
			if material.get_meta("factory_immutable_native_process", "") != "local_coords_static_native_operands":
				_preparation_error = "Cloud preparation requires audited immutable native process operands"
				return {"complete": false, "error": _preparation_error}
			if _prepare_material_step == 3:
				material.get_property_list()
				_prepare_material_step = 4
				return {"complete": false, "operation": "native_process_interface"}
			material.get_rid()
			operation = "native_process_rid"
		_prepare_material += 1
		_prepare_material_step = 0
		return {"complete": false, "operation": operation}
	_prepared_meshes.clear()
	_prepared_shaders.clear()
	immutable_interface_prepared = true
	return {"complete": true, "operation": "publish_complete"}
