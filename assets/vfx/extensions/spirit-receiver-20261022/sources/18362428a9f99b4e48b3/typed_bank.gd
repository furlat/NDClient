extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/ccb200aea670c05002ec/bank.gd"
## Same actual recipient lifecycle with exact native nodes/material setters.
@export var construction_program: Script
@export var construction_operands: Array = []
@export var native_material_templates: Array[ShaderMaterial] = []
@export var construction_source: Resource
@export var source_operand_references: Array[Dictionary] = []


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/718478933d60b6c71150/scene_operand_references.gd").restore(construction_source, source_operand_references, construction_operands)
	for operand: Variant in construction_operands:
		if operand is ShaderMaterial:
			operand.get_property_list()
			operand.get_rid()
			preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd").declared_uniforms(operand.shader)
		if operand is Mesh or operand is Shape3D or operand is Texture or operand is Shader:
			operand.get_rid()
		if operand is Shader:
			preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd").declared_uniforms(operand)
	for material: ShaderMaterial in native_material_templates:
		material.get_property_list()
	preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd").methods(construction_program)
	super.prepare_immutable_interface()


func instantiate_subject() -> Node3D:
	var created: Dictionary = construction_program.instantiate(construction_operands)
	if created.get("material_sites_bound", false):
		# These are this private owner's native refs, never shared bank state.
		created.root.set_meta("prepared_typed_geometry", created.geometry)
	return created.root
