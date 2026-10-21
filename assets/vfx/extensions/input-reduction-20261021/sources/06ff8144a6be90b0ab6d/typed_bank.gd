extends "res://assets/vfx/extensions/input-reduction-20261021/sources/97f40208e8238e7a30cb/bank.gd"
## Direct native construction, followed by the unchanged private controllers.
@export var construction_program: Script
@export var construction_operands: Array = []
@export var construction_source: Resource
@export var source_operand_references: Array[Dictionary] = []
var prepared_geometry_paths := PackedStringArray()


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/718478933d60b6c71150/scene_operand_references.gd").restore(construction_source, source_operand_references, construction_operands)
	material_templates = construction_source.material_templates
	material_settings = construction_source.material_settings
	for path: NodePath in geometry_paths:
		assert(not path.is_absolute() and path.get_subname_count() == 0)
		prepared_geometry_paths.append(str(path).trim_prefix("./"))
	for operand: Variant in construction_operands:
		if operand is ShaderMaterial:
			operand.get_property_list()
			operand.get_rid()
			Interfaces.declared_uniforms(operand.shader)
		if operand is Mesh or operand is Shape3D or operand is Texture or operand is Shader:
			operand.get_rid()
		if operand is Shader:
			Interfaces.declared_uniforms(operand)
	Bindings.methods(construction_program)
	super.prepare_immutable_interface()


func create_owner() -> Dictionary:
	return construction_program.instantiate(construction_operands, Profile.current != null)
