extends RefCounted
## Share immutable shader programs, keep each occurrence's uniforms private.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
static var programs: Dictionary = {}


static func prepare(material: ShaderMaterial, source_key: String, camera_quad: bool = false) -> void:
	var original: Shader = material.shader
	var code: String = SourceMaterials.expand_shader(original.code, original.resource_path.get_base_dir())
	assert(not code.contains("TIME"), "Condition sources must export an explicit shader clock")
	var program_key := source_key + ("/camera_quad" if camera_quad else "")
	if not programs.has(program_key):
		# Keep exact held cutout coverage; opacity must not erode it into flecks.
		var scissor := RegEx.new()
		scissor.compile("ALPHA_SCISSOR_THRESHOLD\\s*=\\s*([^;]+);")
		code = scissor.sub(code, "ALPHA = step($1, ALPHA);", true)
		code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float condition_opacity = 1.0;\n")
		# Some donor shaders declare light() after fragment(). Append to the
		# actual fragment body, never the last function/comment in the file.
		code = SourceMaterials.finish_fragment(code, "\nALPHA *= condition_opacity;\n")
		if camera_quad:
			var facing := """
MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
	INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
	INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
	INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
"""
			if code.contains("void vertex()"):
				code = SourceMaterials.finish_function(code, "vertex", facing)
			else:
				code += "\nvoid vertex(){\n" + facing + "\n}\n"
		var shader := Shader.new()
		shader.code = code
		programs[program_key] = shader
	SourceMaterials.replace_shader(material, programs[program_key])
	material.resource_local_to_scene = true
