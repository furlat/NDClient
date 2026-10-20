extends "res://assets/vfx/extensions/followup-20261020/sources/f12ca962ce4cabce5009/bank.gd"
## Immutable fixed-VAT extension of the same indexed scene/track bank.
## Source particle histories are the original recorded bytes, never a new
## encounter, actor layout, source simulation or runtime geometry recording.
@export var system_node_indices := PackedInt32Array()
@export var system_templates: Array[ShaderMaterial] = []
@export var system_records: Array[Dictionary] = []
@export var process_program: Shader
@export var process_provenance: Dictionary = {}
@export var immutable_native_material_indices := PackedInt32Array()
@export var native_material_admission: Array[Dictionary] = []
@export var native_standard_indices := PackedInt32Array()
@export var native_standard_specs: Array[Resource] = []
@export var native_standard_sites: Array[Dictionary] = []

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	for material in system_templates:
		material.get_rid()
		material.get_property_list()
		SourceMaterials.declared_uniforms(material.shader)
		var texture: Texture2D = material.get_shader_parameter("vat")
		assert(texture != null)
		texture.get_rid()
	super.prepare_immutable_interface()
