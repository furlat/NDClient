extends RefCounted
## Immutable source-program interfaces prepared offline. No occurrence values.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

static func capture(shader: Shader) -> Dictionary:
	var base := shader.resource_path.get_base_dir()
	var expanded := SourceMaterials.expand_shader(shader.code, base)
	return {"shader": shader, "expansion_key": base + "\n" + shader.code,
		"expanded_source": expanded, "uniform_names": SourceMaterials.declared_uniforms(shader)}

static func publish(records: Array) -> void:
	for record in records:
		var shader: Shader = record.shader
		assert(record.expansion_key == shader.resource_path.get_base_dir() + "\n" + shader.code,
			"Prepared Cone shader interface no longer matches its immutable program")
		SourceMaterials.expanded_sources[record.expansion_key] = record.expanded_source
		SourceMaterials.uniform_names[record.expanded_source] = record.uniform_names
