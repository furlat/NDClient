extends "res://assets/vfx/sources/7a0decad7bdb99be9d7b/death_circle.gd"
## The existing curved field, fissures and rooted smoke keep their own motion.
## Its upper layer uses the authored wine family instead of a grey-blue veil.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/996929182f3738dcfa8f/death_circle_chromatic.gd", input)


func adapt_shader(material: ShaderMaterial) -> void:
	var code: String = material.shader.code
	if code.contains("vec3(.20,.25,.28)"):
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform vec4 field_shadow:source_color;\nuniform vec4 field_highlight:source_color;\n")
		code = code.replace("vec3(.018,.03,.052)", "field_shadow.rgb")
		code = code.replace("vec3(.20,.25,.28)", "field_highlight.rgb")
		var shader := Shader.new()
		shader.code = code
		NativeShaderBindings.replace_shader(material, shader)
		material.set_shader_parameter("field_shadow", Color(parameters.field_shadow))
		material.set_shader_parameter("field_highlight", Color(parameters.field_highlight))
	super.adapt_shader(material)
