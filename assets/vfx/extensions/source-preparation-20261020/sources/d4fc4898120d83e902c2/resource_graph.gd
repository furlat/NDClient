extends RefCounted

## Opt-in native migration scope. Historical capture behaviour stays unchanged.
## Old adapters replace VisualShader objects with text shaders; bind their
## default samplers first so that replacement retains the actual donor masks.
static var native_sampler_scopes: int = 0


## Clone mutable resources once per source identity, preserving cross-node aliases.
## Animation tracks and geometry must continue to address the same material copy.
static func clone_value(value: Variant, cache: Dictionary) -> Variant:
	if value is Resource:
		if value is Script or value is CompressedTexture2D or value is ImageTexture:
			return value
		var identity: int = value.get_instance_id()
		if cache.has(identity):
			return cache[identity]
		# VisualShader graph properties are append-only; replaying them onto a
		# shallow duplicate tries to add existing node IDs a second time.
		if value is Shader and not value is VisualShader:
			# Authored text shaders are immutable; their source path resolves includes.
			# Material adapters create a new shader when changing its code.
			return value
		if value is VisualShader:
			var shader_copy: Resource = value.duplicate(true)
			cache[identity] = shader_copy
			return shader_copy
		var copied: Resource = value.duplicate(false)
		cache[identity] = copied
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				var field: Variant = value.get(property.name)
				if field is Resource or field is Array or field is Dictionary:
					copied.set(property.name, clone_value(field, cache))
		if native_sampler_scopes > 0 and value is ShaderMaterial and value.shader != null:
			# A freshly loaded shader may not have a compiled uniform list yet.
			# Default textures are available immediately; use declared sampler names.
			var samplers := RegEx.new()
			samplers.compile("uniform\\s+(?:(?:lowp|mediump|highp)\\s+)?sampler2D\\s+(\\w+)")
			for sampler in samplers.search_all(value.shader.code):
				var name: String = sampler.get_string(1)
				if value.get_shader_parameter(name) != null:
					continue
				var texture: Texture2D = value.shader.get_default_texture_parameter(name)
				if texture != null:
					copied.set_shader_parameter(name, clone_value(texture, cache))
		return copied
	if value is Array:
		var copied: Array = value.duplicate()
		for index in copied.size():
			copied[index] = clone_value(value[index], cache)
		return copied
	if value is Dictionary:
		var copied: Dictionary = value.duplicate()
		for key in copied:
			copied[key] = clone_value(value[key], cache)
		return copied
	return value


static func isolate_node(node: Node, cache: Dictionary) -> void:
	for property in node.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = node.get(property.name)
		if value is Material or value is Mesh:
			node.set(property.name, clone_value(value, cache))
	if node is AnimationPlayer:
		for library_name in node.get_animation_library_list():
			var animations: AnimationLibrary = clone_value(
				node.get_animation_library(library_name), cache
			)
			node.remove_animation_library(library_name)
			node.add_animation_library(library_name, animations)
	for child in node.get_children():
		isolate_node(child, cache)
