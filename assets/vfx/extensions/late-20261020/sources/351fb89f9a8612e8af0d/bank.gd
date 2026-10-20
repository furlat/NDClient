extends Resource
## Original mesh/material programs and all 864 source frames, not an encounter.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var source_phase := ""
@export var source_hash := ""
@export var source_script := ""
@export var settings: Dictionary = {}
@export var frames: Resource
var source_fps: float:
	get: return frames.fps
var source_frames: int:
	get: return frames.count
var particles: PackedVector3Array:
	get: return frames.particles
@export var program: Script
@export var operands: Array = []
@export var node_specs: Array[Dictionary] = []
@export var material_specs: Array[Dictionary] = []
@export var layout: Dictionary = {}
@export var templates: Array[ShaderMaterial] = []
@export var stable_paths_verified := false
@export var receipt: Dictionary = {}
var interface_prepared := false

func prepare_immutable_interface() -> void:
	if interface_prepared: return
	var shaders := {}
	for spec in material_specs:
		var shader: Shader = spec.shader
		if shaders.has(shader): continue
		shaders[shader] = true
		shader.get_shader_uniform_list()
		Materials.declared_uniforms(shader)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.get_property_list()
	for node in node_specs:
		for entry in node.properties:
			var operand: Dictionary = entry.operand
			var resource: Variant = operand.get("mesh", operand.get("value"))
			if resource is Mesh: resource.get_rid()
	for template in templates: template.get_property_list()
	for operand in operands:
		if operand is Mesh: operand.get_rid()
		elif operand is MultiMesh and operand.mesh != null: operand.mesh.get_rid()
	interface_prepared = true
