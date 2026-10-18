extends RefCounted
## Build an independent material from explicit shader/uniform data.
## No spell names, capture settings, scene state or global material mutation.


static func build(definition: Dictionary) -> ShaderMaterial:
	var shader_path: String = str(definition.get("shader", ""))
	if shader_path.is_empty():
		push_error("Shader material requires a shader resource path.")
		return null
	var source: Resource = VfxPackageIO_4cf3ab0497.resource(shader_path)
	if not source is Shader:
		push_error("Expected Shader: " + shader_path)
		return null
	var material := ShaderMaterial.new()
	material.shader = source
	for name in definition.get("parameters", {}):
		var specification: Variant = definition.parameters[name]
		var value: Variant = uniform_value(specification)
		if value == null and specification != null:
			return null
		material.set_shader_parameter(name, value)
	return material


static func uniform_value(specification: Variant) -> Variant:
	if not specification is Dictionary or not specification.has("type"):
		return specification
	match specification.type:
		"Resource":
			return VfxPackageIO_4cf3ab0497.resource(str(specification.get("path", specification.get("value", ""))))
		"Color":
			return Color.html(str(specification.value))
		"Vector2":
			return Vector2(specification.value[0], specification.value[1])
		"Vector3":
			return Vector3(specification.value[0], specification.value[1], specification.value[2])
		"GradientTexture1D":
			var color_values: Array = specification.get("colors", [])
			var offset_values: Array = specification.get("offsets", [])
			if color_values.size() < 2 or color_values.size() != offset_values.size():
				push_error("Gradient requires matching color/offset arrays with at least two points.")
				return null
			var colors := PackedColorArray()
			for color in color_values:
				colors.append(Color.html(str(color)))
			var gradient := Gradient.new()
			gradient.colors = colors
			gradient.offsets = PackedFloat32Array(offset_values)
			var texture := GradientTexture1D.new()
			texture.gradient = gradient
			return texture
	push_error("Unsupported shader uniform type: " + str(specification.type))
	return null

const VfxPackageIO_4cf3ab0497 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
