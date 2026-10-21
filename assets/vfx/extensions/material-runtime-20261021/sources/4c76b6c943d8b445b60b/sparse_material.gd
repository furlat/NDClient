extends RefCounted
## Exact selected native shader/metadata operands, lowered offline. Every return
## is private; only immutable programs and source sampler resources are shared.


static func make(specification: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = specification.shader
	if specification.render_priority != 0:
		material.render_priority = specification.render_priority
	for name: String in specification.parameters:
		material.set_shader_parameter(name, specification.parameters[name])
	for name: StringName in specification.metadata:
		material.set_meta(name, specification.metadata[name])
	return material
