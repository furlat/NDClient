extends "res://assets/vfx/extensions/material-runtime-20261021/sources/ca03c49f75ca747c46f8/bank.gd"
## Publish actual immutable display Materials from the retained source operands.
## Native owner state remains private in the existing instance-display adapter.
const MUTABLE_PARAMETERS := [
	"vfx_package_clock_slot", "vfx_package_offset_support_clock", "support_clock",
	"support_envelope", "factory_world_to_source", "releasing", "puff_life",
]


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	assert(display_lowering.size() == material_specs.size())
	assert(display_materials.is_empty(), "Only raw source operands are serialized in this derivative")
	for index: int in material_specs.size():
		var specification: Dictionary = material_specs[index]
		var lowering: Dictionary = display_lowering[index]
		assert(specification.shader == lowering.original_shader)
		assert(specification.binding == lowering.binding)
		var material := ShaderMaterial.new()
		material.shader = lowering.shader
		material.render_priority = specification.render_priority
		material.resource_local_to_scene = false
		for name: String in specification.parameters:
			if name not in MUTABLE_PARAMETERS:
				# Preserve the original setter's Variant type. Serializing a native
				# ShaderMaterial can turn an authored Vector3 into a Color getter.
				material.set_shader_parameter(name, specification.parameters[name])
		for name: String in specification.metadata:
			material.set_meta(name, specification.metadata[name])
		material.set_meta("factory_prepared_shader", material.shader)
		material.set_meta("factory_opacity_prepared_shader", material.shader)
		material.set_meta("factory_clock_names", [])
		material.set_meta("factory_clock_pool_required", false)
		material.set_meta("factory_world_space_uniform", false)
		material.set_meta("curse_immutable_display", material.shader)
		display_materials.append(material)
	super.prepare_immutable_interface()
