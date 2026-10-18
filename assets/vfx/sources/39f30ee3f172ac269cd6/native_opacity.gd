extends RefCounted
## Neutral occurrence-level opacity, independent of a donor's own alpha clock.
const SourceBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const UNIFORM = "factory_occurrence_alpha"


static func apply(node: Node, visited: Dictionary = {}) -> void:
	for property in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			var value: Variant = node.get(property.name)
			if value is Resource:
				adapt_resource(value, visited)
	for child in node.get_children():
		apply(child, visited)


static func adapt_resource(resource: Resource, visited: Dictionary) -> void:
	if visited.has(resource):
		return
	visited[resource] = true
	if resource is ShaderMaterial and resource.shader != null and not resource.has_meta(UNIFORM):
		var code: String = SourceBindings.expand_shader(resource.shader.code, resource.shader.resource_path.get_base_dir())
		var fragment: int = code.find("void fragment()")
		var start: int = code.find("{", fragment)
		if fragment >= 0 and start >= 0:
			var end: int = start + 1
			var depth: int = 1
			while end < code.length() and depth > 0:
				if code[end] == "{":
					depth += 1
				elif code[end] == "}":
					depth -= 1
				end += 1
			code = code.insert(end - 1, "\nALPHA *= factory_occurrence_alpha;\n")
			code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float factory_occurrence_alpha=1.0;\n")
			var shader: Shader = Shader.new()
			shader.code = code
			SourceBindings.replace_shader(resource, shader)
			resource.set_shader_parameter(UNIFORM, 1.0)
			resource.set_meta(UNIFORM, true)
	for property in resource.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			var value: Variant = resource.get(property.name)
			if value is Resource and not value is Shader:
				adapt_resource(value, visited)
	if resource is Mesh:
		for surface in resource.get_surface_count():
			var material: Material = resource.surface_get_material(surface)
			if material != null:
				adapt_resource(material, visited)
