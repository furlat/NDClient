extends Resource
## Verified immutable source interface; no Node, clock or actor preparation.
@export var scene: PackedScene
@export var bindings: Array = []
@export var receipt: Dictionary = {}
var prototypes: Dictionary = {}


func prepare_immutable_interface() -> void:
	if not prototypes.is_empty(): return
	var state:=scene.get_state()
	for binding in bindings:
		assert(str(state.get_node_path(binding.node_index))==binding.node_path,"Exact immutable source node binding")
		assert(str(state.get_node_property_name(binding.node_index,binding.property_index))==binding.property_name,"Exact immutable source property binding")
		var material: ShaderMaterial=state.get_node_property_value(binding.node_index,binding.property_index)
		assert(material.shader.resource_path==binding.shader_path,"Exact original embedded/external Shader source binding")
		material.get_property_list()
		material.shader.get_shader_uniform_list()
		prototypes[binding.node_path.trim_prefix("./")]=material.shader


func bind_private(material: ShaderMaterial,node_path: String) -> bool:
	# Embedded subresources must be resolved from the exact original SceneState.
	# Serializing a Shader into another bank would copy its resource identity.
	prepare_immutable_interface()
	if material.shader!=prototypes.get(node_path):
		return false
	# Only these exact offline-verified shader objects read the retained
	# condition sampler. The outer occurrence must not add its own clock.
	material.set_meta("factory_prepared_shader",material.shader)
	material.set_meta("factory_clock_names",[])
	material.set_meta("factory_clock_pool_required",false)
	return true
