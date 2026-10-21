extends RefCounted
## Exact source-address references resolved once before occurrence publication.


static func contains_resource(value: Variant) -> bool:
	if value is Resource:
		return true
	if value is Array:
		for child: Variant in value:
			if contains_resource(child):
				return true
	if value is Dictionary:
		for child: Variant in value.values():
			if contains_resource(child):
				return true
	return false


static func resolve(source: Resource, reference: Dictionary) -> Variant:
	if reference.kind == "scene":
		var value: Variant = source.scene.get_state().get_node_property_value(int(reference.node), int(reference.property))
		match str(reference.get("member", "")):
			"":
				return value
			"shader":
				return value.shader
			"parameter":
				return value.get_shader_parameter(reference.name)
			"metadata":
				return value.get_meta(reference.name)
	else:
		assert(reference.kind == "material")
		match str(reference.member):
			"self":
				return source.material_templates[int(reference.material)]
			"shader":
				return source.material_templates[int(reference.material)].shader
			"parameter":
				return source.material_settings[int(reference.material)].parameters[reference.name]
			"metadata":
				return source.material_settings[int(reference.material)].metadata[reference.name]
	assert(false, "Unknown exact original immutable operand address")
	return null


static func restore(source: Resource, references: Array, operands: Array) -> void:
	for reference: Dictionary in references:
		var actual: Variant = resolve(source, reference)
		assert(contains_resource(actual), "Original resource-bearing source operand must still exist")
		operands[int(reference.index)] = actual
