extends "res://assets/vfx/extensions/material-runtime-20261021/sources/91c52532c764b1f93015/bank.gd"
## Native processes remain private; only audited read-only display data is shared.
@export var display_materials: Array[ShaderMaterial] = []
@export var display_lowering: Array[Dictionary] = []


func shared_display(index: int) -> ShaderMaterial:
	assert(interface_ready and display_materials.size() == material_specs.size())
	return display_materials[index]


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	assert(display_materials.size() == material_specs.size())
	for material: ShaderMaterial in display_materials:
		assert(material.get_script() == null and material.next_pass == null)
		material.get_rid()
		material.shader.get_rid()
		material.shader.get_shader_uniform_list()
	super.prepare_immutable_interface()
