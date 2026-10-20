extends Resource
## Immutable geometry/programs from the selected analytical summoning donor.
## No occurrence, caster, endpoint, source tick or native particle state.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
@export var scene: PackedScene
@export var adapter_script: Script
@export var material_nodes: Array[NodePath] = []
@export var material_templates: Array[ShaderMaterial] = []
@export var material_settings: Array[Dictionary] = []
@export var world_material_indices: Array[int] = []
@export var ribbon_paths: Array[NodePath] = []
@export var ground_path: NodePath
@export var mote_path: NodePath
@export var camera_ground: Vector2
@export var ribbon_bounds: Array[Array] = []
@export var mote_paths: Array[NodePath] = []
@export var material_canonical_indices: Array[int] = []
@export var provenance: Dictionary = {}
@export var verified_stable_paths := false
var interface_ready := false

func private_material(index: int) -> ShaderMaterial:
	var settings: Dictionary = material_settings[index]
	var material := ShaderMaterial.new()
	material.shader = material_templates[index].shader
	material.render_priority = settings.render_priority
	for name in settings.parameters:
		material.set_shader_parameter(name, settings.parameters[name])
	for name in settings.metadata:
		material.set_meta(name, settings.metadata[name])
	return material

func prepare_immutable_interface() -> void:
	if interface_ready: return
	Bindings.methods(adapter_script)
	# Published templates are immutable. Each actual owner shallow-clones just
	# its mutable material operands, retaining shared immutable Shader/textures.
	for material in material_templates:
		if material.get_meta("factory_clock_pool_required", false):
			preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd").ensure_pool()
		material.get_rid()
		material.get_property_list()
		preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd").declared_uniforms(material.shader)
	var state := scene.get_state()
	for index in state.get_node_count():
		for property in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index, property)
			if value is ShaderMaterial:
				value.get_rid()
				value.get_property_list()
				preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd").declared_uniforms(value.shader)
			elif value is Mesh or value is MultiMesh:
				value.get_rid()
	interface_ready = true
