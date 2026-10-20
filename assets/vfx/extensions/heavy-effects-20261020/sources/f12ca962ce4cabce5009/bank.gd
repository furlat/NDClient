extends Resource
## One exact zero-system native recording. No actor or presentation owner.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const SceneMaterialAdmission = preload("res://assets/vfx/extensions/followup-20261020/sources/2462f4064b61dbf9201d/scene_material_admission.gd")
@export var scene: PackedScene
@export var materials: Array[Material] = []
@export var private_materials := PackedInt32Array()
@export var material_sites: Array[Dictionary] = []
@export var material_roots: Array[Dictionary] = []
@export var runtime_paths: Array[NodePath] = []
@export var geometry_indices := PackedInt32Array()
@export var light_indices := PackedInt32Array()
@export var decal_indices := PackedInt32Array()
@export var node_tracks: Array[Dictionary] = []
@export var material_tracks: Array[Dictionary] = []
@export var initial_node_values: Array = []
@export var initial_material_values: Array = []
@export var frame_node_indices: Array = []
@export var frame_material_indices: Array = []
@export var all_node_indices := PackedInt32Array()
@export var all_material_indices := PackedInt32Array()
@export var rate := 60.0
@export var frames := 1
@export var seconds := 0.0
@export var opacity_uniform := ""
@export var provenance: Dictionary = {}
@export var adapter_script := "res://assets/vfx/extensions/heavy-effects-20261020/sources/2cd710be3201c544db8f/field.gd"
var interface_ready := false
var scene_material_admission: Dictionary = {}
var recorded_interface_preparation_us := 0

func prepare_immutable_interface_step() -> Dictionary:
	if interface_ready and not scene_material_admission.is_empty() and scene_material_admission.complete:
		var complete := SceneMaterialAdmission.progress(scene_material_admission)
		complete.recorded_interface_preparation_us = recorded_interface_preparation_us
		return complete
	if scene_material_admission.is_empty():
		# Preserve the original most-derived interface hook (including the VAT
		# process templates). No owner is published until all actual scene
		# Material RIDs have also been admitted.
		var started := Time.get_ticks_usec()
		prepare_immutable_interface()
		recorded_interface_preparation_us = Time.get_ticks_usec()-started
		interface_ready = false
		scene_material_admission = SceneMaterialAdmission.begin(scene)
	var result := SceneMaterialAdmission.step(scene_material_admission)
	interface_ready = bool(result.complete)
	result.recorded_interface_preparation_us = recorded_interface_preparation_us
	return result

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	Bindings.methods(VfxPackageIO_f12ca962ce.resource(adapter_script))
	for material in materials:
		material.get_property_list()
		if material is ShaderMaterial:
			material.shader.get_shader_uniform_list()
			SourceMaterials.declared_uniforms(material.shader)
	# Immutable mesh RIDs are admitted before the first actual draw is bound.
	var state := scene.get_state()
	for index in state.get_node_count():
		for property_index in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index,property_index)
			if value is Mesh:
				value.get_rid()
	interface_ready = true

const VfxPackageIO_f12ca962ce = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
