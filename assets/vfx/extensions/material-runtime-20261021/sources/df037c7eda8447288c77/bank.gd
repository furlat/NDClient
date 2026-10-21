extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/0250a3f89c551f4fc017/bank.gd"
## Existing recipient bank, plus exact curse node-array/birth handles.
@export var node_arrays: Dictionary = {}
@export var restart_paths: Array[NodePath] = []
@export var player_states: Array[Dictionary] = []
@export var detached_controllers: Array[Dictionary] = []
@export var fold_poses: Array[Dictionary] = []

@export var material_specs: Array[Dictionary] = []
@export var process_specs: Array[Dictionary] = []
@export var unit_snapshots: Array[Resource] = []

func private_material(index: int) -> ShaderMaterial:
	var specification: Dictionary = material_specs[index]
	var material := ShaderMaterial.new()
	material.shader = specification.shader
	material.render_priority = specification.render_priority
	for name: String in specification.parameters:
		material.set_shader_parameter(name,specification.parameters[name])
	for name: String in specification.metadata:
		material.set_meta(name,specification.metadata[name])
	return material

func private_process(index: int) -> ParticleProcessMaterial:
	if not unit_snapshots.is_empty():
		return unit_snapshots[index].make_material()
	var material := ParticleProcessMaterial.new()
	for property: Dictionary in process_specs[index].properties:
		material.set(property.name,property.value)
	return material


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	# These exact native programs use the established shared source clock.
	# Publish its immutable sampler before any source Shader RID/interface is
	# reflected; preparation still constructs no Node, owner or source age.
	for specification: Dictionary in material_specs:
		if specification.metadata.get("factory_clock_pool_required",false):
			preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd").ensure_pool()
			break
	super.prepare_immutable_interface()
