extends RefCounted
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var programs: Dictionary = {}
## Remove only legacy camera-half cuts; retain ground, dissolve and shape masks.

static func whole_shader(code: String) -> String:
	var expression := RegEx.new()
	expression.compile("if\\s*\\(")
	var cursor := 0
	var result := ""
	while cursor < code.length():
		var found := expression.search(code, cursor)
		if found == null:
			return result + code.substr(cursor)
		var begin := found.get_start()
		var end := found.get_end()
		var depth := 1
		while end < code.length() and depth > 0:
			if code[end] == "(":
				depth += 1
			elif code[end] == ")":
				depth -= 1
			end += 1
		var condition := code.substr(found.get_end(), end - found.get_end() - 1)
		var suffix := code.substr(end).strip_edges(true, false)
		var discarded := suffix.begins_with("discard;")
		var braced := suffix.begins_with("{discard;}") or suffix.begins_with("{ discard; }")
		var camera_cut := condition.contains("0.70710678") or condition.contains(".70710678")
		camera_cut = camera_cut or condition.contains("0.6123724") or condition.contains(".6123724")
		camera_cut = camera_cut or ((condition.contains("front") or condition.contains("foreground")) and (
			condition.contains("camera_sign") or condition.contains("nearest") or condition.contains("depth") or condition.contains("camera_ground")))
		if camera_cut and (discarded or braced):
			var discard_end := code.find(";", end) + 1
			if braced:
				discard_end = code.find("}", discard_end) + 1
			result += code.substr(cursor, begin - cursor)
			# The force-dome source combines its floor cut with the camera cut.
			if condition.contains("||") and condition.get_slice("||", 0).contains(".y<"):
				result += "if(" + condition.get_slice("||", 0) + ")discard;"
			cursor = discard_end
		else:
			result += code.substr(cursor, end - cursor)
			cursor = end
	return result

static func source_shader(code: String) -> String:
	# The historical recorder placed the source at world zero. Source-space
	# reveal heights, radial masks and reaction crops must move with an occurrence.
	# Keep world normals and billboard matrices in actual scene space.
	var query := RegEx.new()
	query.compile("\\(\\s*(MODEL_MATRIX|INV_VIEW_MATRIX(?:\\s*\\*\\s*MODELVIEW_MATRIX)?)\\s*\\*\\s*vec4\\s*\\(\\s*VERTEX\\s*,\\s*1(?:\\.0?)?\\s*\\)\\s*\\)\\.xyz")
	if query.search(code) == null:
		return code
	var result := query.sub(code, "(factory_world_to_source * $1 * vec4(VERTEX,1.0)).xyz", true)
	if result.contains("uniform mat4 factory_world_to_source"):
		return result
	return result.replace("shader_type spatial;", "shader_type spatial;\nuniform mat4 factory_world_to_source=mat4(1.0);")

static func adapt(node: Node, seen: Dictionary = {}, materials: Array = []) -> Array:
	for property in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			var value: Variant = node.get(property.name)
			if value is Resource:
				_resource(value, seen, materials)
	for child in node.get_children():
		adapt(child, seen, materials)
	return materials

static func _resource(resource: Resource, seen: Dictionary, materials: Array) -> void:
	if seen.has(resource):
		return
	seen[resource] = true
	_adapt_material(resource, materials)
	for property in resource.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			var value: Variant = resource.get(property.name)
			if value is Resource and not value is Shader:
				_resource(value, seen, materials)
	if resource is Mesh:
		for index in resource.get_surface_count():
			var material: Material = resource.surface_get_material(index)
			if material != null:
				_resource(material, seen, materials)


static func adapt_materials(materials: Array) -> Array:
	var bindings: Array = []
	for material in materials:
		_adapt_material(material, bindings)
	return bindings


static func _adapt_material(resource: Resource, materials: Array) -> void:
	if resource is ShaderMaterial and resource.shader != null:
		if resource.has_meta("factory_prepared_shader") and resource.get_meta("factory_prepared_shader") == resource.shader:
			if resource.get_meta("factory_world_space_uniform", false):
				materials.append(resource)
			return
		var original: String = resource.shader.code
		# A generated Shader has no file base. Resolve relative donor includes
		# before either this adapter or the native clock owner replaces it.
		var key: String = resource.shader.resource_path.get_base_dir() + "\n" + original
		if not programs.has(key):
			var expanded := SourceMaterials.expand_shader(original, resource.shader.resource_path.get_base_dir())
			var adapted_code := source_shader(whole_shader(expanded))
			var shader: Shader = resource.shader
			if adapted_code != original:
				shader = Shader.new()
				shader.code = adapted_code
			programs[key] = shader
		var prepared: Shader = programs[key]
		if prepared != resource.shader:
			SourceMaterials.replace_shader(resource, prepared)
		var complete: String = prepared.code
		if complete.contains("uniform mat4 factory_world_to_source"):
			materials.append(resource)
