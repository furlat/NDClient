extends Resource
## Exact source parameter atlases and complete native four-partition assembly.
const MaterialInterfaces = preload("res://assets/vfx/sources/69c9459897d0b5c3849f/cone_material_interfaces.gd")
@export var scene: PackedScene
@export var material_paths: Array[NodePath] = []
@export var process_paths: Array[NodePath] = []
@export var geometry_paths: Array[NodePath] = []
@export var flares: Array[Dictionary] = []
@export var shader_interfaces: Array[Dictionary] = []
@export var simulation_hz: float = 144.0
@export var provenance: Dictionary = {}
var immutable_interface_prepared := false

func prepare_immutable_interface() -> void:
	if immutable_interface_prepared:
		return
	MaterialInterfaces.publish(shader_interfaces)
	var state := scene.get_state()
	var seen := {}
	for node_index in state.get_node_count():
		for property_index in state.get_node_property_count(node_index):
			var value: Variant = state.get_node_property_value(node_index, property_index)
			if value is ShaderMaterial and not seen.has(value):
				seen[value] = true
				value.shader.get_shader_uniform_list()
				value.get_property_list()
	immutable_interface_prepared = true

