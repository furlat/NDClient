extends RefCounted


## Native source loading semantics used by archived authoring code.
static func raw_texture(path: String, cache: Dictionary = {}) -> ImageTexture:
	if not cache.has(path):
		cache[path] = ImageTexture.create_from_image(
			VfxPackageIO_16a8d77d73_39ced3e79a.image(ProjectSettings.globalize_path(path))
		)
	return cache[path]


## Opt-in imported image access for runtime-owned masks. Unlike raw_texture,
## this also works when a native game package contains the imported Texture2D
## instead of the original PNG. Callers must verify the channels they consume.
static func imported_image(path: String) -> Image:
	var texture: Texture2D = VfxPackageIO_16a8d77d73_39ced3e79a.resource(path)
	assert(texture != null, "Missing imported source texture: " + path)
	var image: Image = texture.get_image()
	assert(image != null and not image.is_empty(), "Imported source has no CPU image: " + path)
	if image.is_compressed():
		assert(image.decompress() == OK, "Cannot decode imported source: " + path)
	image.clear_mipmaps()
	return image


static func expand_shader(code: String, base: String) -> String:
	var result = ""
	for line in code.split("\n"):
		if line.strip_edges().begins_with("#include"):
			var path = line.get_slice('"', 1)
			if not path.begins_with("res://"):
				path = base.path_join(path)
			result += expand_shader(VfxPackageIO_16a8d77d73_39ced3e79a.text(path), path.get_base_dir()) + "\n"
		else:
			result += line + "\n"
	return result

## Equivalent finite proximity fade with increasing smoothstep edges. Generated
## VisualShader sources invert smoothstep by swapping its edges, which is undefined
## for equal/reversed edges and invalid reconstructed background depth.
static func stable_proximity(code: String) -> String:
	var expression := RegEx.new()
	expression.compile("clamp\\(1\\.0 - smoothstep\\(__depth_world_pos\\.z \\+ (\\w+), __depth_world_pos\\.z, VERTEX\\.z\\), 0\\.0, 1\\.0\\)")
	return expression.sub(code, "((isnan(VERTEX.z-__depth_world_pos.z) || isinf(VERTEX.z-__depth_world_pos.z)) ? 1.0 : smoothstep(0.0, max($1, 0.0001), VERTEX.z-__depth_world_pos.z))", true)

## This source's explicit camera-facing matrix drops inherited mesh scale.
## Retain the original camera axes while restoring each current model axis size.
## Opt in only for a material whose billboard construction has been inspected.
static func scaled_billboard(code: String) -> String:
	for axis in 3:
		var original := "MAIN_CAM_INV_VIEW_MATRIX[" + str(axis) + "]"
		var replacement := original + " * vec4(vec3(length(MODEL_MATRIX[" + str(axis) + "].xyz)), 1.0)"
		code = code.replace(original, replacement)
	return code

## Add an occurrence-local finishing operation to the original fragment output.
static func finish_fragment(code: String, addition: String) -> String:
	return finish_function(code, "fragment", addition)


static func finish_function(code: String, function_name: String, addition: String) -> String:
	var function: int = code.find("void " + function_name + "()")
	var begin: int = code.find("{", function) if function >= 0 else -1
	assert(begin >= 0, "Selected source has no " + function_name + " output")
	var cursor: int = begin + 1
	var depth: int = 1
	while cursor < code.length() and depth > 0:
		if code[cursor] == "{": depth += 1
		elif code[cursor] == "}": depth -= 1
		cursor += 1
	assert(depth == 0, "Selected source has an unclosed " + function_name + " output")
	return code.insert(cursor - 1, addition)

## Preserve live frame/mask/normal bindings and default textures explicitly
## when assigning an occurrence-local derivative. Renderer family selection
## remains a separate responsibility; a new Shader has no source file path.
## Declared names also work before the renderer has compiled the uniform list.
static func replace_shader(material: ShaderMaterial, shader: Shader) -> void:
	var parameters := {}
	var declarations := RegEx.new()
	declarations.compile("uniform\\s+(?:(?:lowp|mediump|highp)\\s+)?\\w+\\s+(\\w+)")
	var original: Shader = material.shader
	for found in declarations.search_all(expand_shader(original.code,original.resource_path.get_base_dir())):
		var name: String = found.get_string(1)
		var value: Variant = material.get_shader_parameter(name)
		if value!=null:
			parameters[name]=value
		elif original.code.contains("sampler"):
			var texture: Texture2D = original.get_default_texture_parameter(name)
			if texture!=null: parameters[name]=texture
	material.shader=shader
	for name in parameters:
		material.set_shader_parameter(name,parameters[name])

const VfxPackageIO_16a8d77d73_39ced3e79a = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/249140d21848f6d0bd2b/resource_io.gd")
