extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/f12ca962ce4cabce5009/bank.gd"
## Optional typed constructor for an exact existing fixed recording bank.
## Tracks/rate/private aliases remain the original immutable source data.
const ConstructionBindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
@export var construction_source: Resource
@export var construction_program: Script
@export var construction_operands: Array = []
@export var construction_resource_operands: Array[Dictionary] = []
@export var source_material_local_flags := PackedByteArray()
@export var sample_table: Resource

func prepare_immutable_interface() -> void:
	if interface_ready: return
	assert(construction_source != null and construction_program != null)
	ConstructionBindings.methods(construction_program)
	if sample_table!=null: sample_table.prepare(construction_source)
	for reference: Dictionary in construction_resource_operands:
		var value: Resource
		match str(reference.kind):
			"parameter": value = construction_source.materials[int(reference.material)].get_shader_parameter(reference.key)
			"metadata": value = construction_source.materials[int(reference.material)].get_meta(reference.key)
			"scene_property": value = construction_source.scene.get_state().get_node_property_value(int(reference.node),int(reference.property))
			_: assert(false,"Unknown original recorded resource operand")
		assert(value != null,"Missing immutable original recorded operand")
		construction_operands[int(reference.index)] = value
	super.prepare_immutable_interface()

func construct_subject() -> Dictionary:
	assert(interface_ready and get_meta("factory_typed_recorded_construction",false))
	var result: Dictionary = construction_program.instantiate(construction_operands)
	# This flag describes future scene localization, not a new copy. Retain
	# the original actual runtime material property as well as all operands.
	for index in result.materials.size():
		result.materials[index].resource_local_to_scene = bool(source_material_local_flags[index])
	return result
