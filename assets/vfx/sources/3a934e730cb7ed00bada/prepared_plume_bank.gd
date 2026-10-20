extends Resource
## Exact two-emitter source scene. Native programs/meshes are immutable;
## local-to-scene material/process resources are private in every occurrence.
@export var scene: PackedScene
@export var paths: Array[NodePath] = []
@export var provenance: Dictionary = {}
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	var state := scene.get_state()
	for index in state.get_node_count():
		for property in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index, property)
			if value is ShaderMaterial:
				value.get_property_list()
				value.shader.get_shader_uniform_list()
			elif value is ParticleProcessMaterial:
				value.get_rid()
			elif value is Mesh:
				value.get_rid()
	interface_ready = true
