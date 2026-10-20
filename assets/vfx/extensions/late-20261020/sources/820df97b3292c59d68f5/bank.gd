extends Resource
## Exact immutable native payload construction operands. No event, caster,
## owner, endpoint, resolved footprint or active source age is retained here.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const Interfaces = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Clock = preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
@export var scene: PackedScene
@export var adapter_script: Script
@export var source_script := ""
@export var material_paths: Array[NodePath] = []
@export var material_templates: Array[ShaderMaterial] = []
@export var material_settings: Array[Dictionary] = []
@export var particle_paths: Array[NodePath] = []
@export var particle_initial_emitting: Array[bool] = []
@export var process_receipts: Array[Dictionary] = []
@export var splash_path: NodePath
@export var liquid_paths: Array[NodePath] = []
@export var player_path: NodePath
@export var verified_stable_paths := false
@export var provenance: Dictionary = {}
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
	for material in material_templates:
		if material.get_meta("factory_clock_pool_required", false): Clock.ensure_pool()
		material.get_rid()
		material.get_property_list()
		Interfaces.declared_uniforms(material.shader)
	var state := scene.get_state()
	for index in state.get_node_count():
		for property in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index, property)
			if value is Material or value is Mesh:
				value.get_rid()
			if value is ShaderMaterial:
				value.get_property_list()
				Interfaces.declared_uniforms(value.shader)
	interface_ready = true
