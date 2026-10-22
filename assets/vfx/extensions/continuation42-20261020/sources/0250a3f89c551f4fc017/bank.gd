extends Resource
const NativeResourceProperty = preload("res://assets/vfx/extensions/spike-readiness-20261022/sources/1793309ffeebd0420d31/native_resource_property.gd")
var _native_child_properties: Dictionary = {}
## The prepared subject of one explicit original recipient-source recipe.
## Scene-local materials/process resources remain private. No actor, owner,
## event, sampled history or encounter transform is stored here.
@export var scene: PackedScene
@export var source_script := ""
@export var adapter_script: Script
@export var stable_paths_prepared := false
@export var generated_name_bindings: Array[Dictionary] = []
@export var emission_start_edges: Array[NodePath] = []
@export var input_sha256 := ""
@export var material_bindings: Array[Dictionary] = []
@export var world_material_bindings: Array[Dictionary] = []
@export var node_members: Dictionary = {}
@export var player_paths: Array[String] = []
@export var light_paths: Array[String] = []
@export var immutable_material_bindings: Array[Dictionary] = []
@export var seeds: Array = []
@export var provenance: Dictionary = {}
@export var declared_registration_complete := false
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	preload("res://assets/vfx/extensions/continuation42-20261020/sources/e39a2969814c1bbdbded/animation_key_times.gd").prepare_scene(scene)
	if adapter_script != null:
		preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd").methods(adapter_script)
	var state := scene.get_state()
	var prepared_resources := {}
	for index in state.get_node_count():
		for property in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index, property)
			if value is Resource:
				_prepare_resource(value, prepared_resources)
	interface_ready = true

func _prepare_resource(value: Resource, seen: Dictionary) -> void:
	if seen.has(value) or value is Script or value is Texture2D or value is Shader:
		return
	seen[value] = true
	if value is Animation:
		# Exact source retiming is restored once while only immutable Resource
		# data exists. No player, occurrence or elapsed source age is created.
		preload("res://assets/vfx/extensions/continuation42-20261020/sources/e39a2969814c1bbdbded/animation_key_times.gd").restore_before_publication(value)
	# Read immutable native setter metadata/RIDs before publication. No Node,
	# occurrence, actor, material clone or source clock is constructed here.
	var properties: Array[Dictionary] = value.get_property_list()
	if value is Material or value is Mesh:
		value.get_rid()
	if value is ShaderMaterial and value.shader != null:
		preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd").declared_uniforms(value.shader)
	for property in properties:
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			if NativeResourceProperty.can_elide_native_getter(value, property, _native_child_properties):
				continue
			var child: Variant = value.get(property.name)
			if child is Resource:
				_prepare_resource(child, seen)
	if value is Mesh:
		for surface in value.get_surface_count():
			var material: Material = value.surface_get_material(surface)
			if material != null:
				_prepare_resource(material, seen)
