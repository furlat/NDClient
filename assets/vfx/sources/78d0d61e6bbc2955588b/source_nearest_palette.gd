extends RefCounted
## Native albedo adapter for an explicit existing nearest-palette finish.
## Uses the shared D65/CIE76 contract; geometry, opacity and timing are untouched.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Stage = preload("res://assets/vfx/sources/7ffdb77f06cb06b0c42e/contract_stage.gd")

static func apply(material: ShaderMaterial, specification: Dictionary) -> void:
	assert(specification.id == "nearest_palette")
	assert(specification.colors.size() > 1 and specification.colors.size() <= 64)
	assert(not material.has_meta("factory_source_nearest_palette"))
	var code := Sources.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	var begin := code.find("void fragment()")
	var opening := code.find("{", begin)
	assert(begin >= 0 and opening >= 0)
	var depth := 1
	var closing := opening + 1
	while depth > 0 and closing < code.length():
		if code[closing] == "{":
			depth += 1
		elif code[closing] == "}":
			depth -= 1
		closing += 1
	var finish := """
vec3 finish_encoded=vec3(cie_encoded_channel(ALBEDO.r),cie_encoded_channel(ALBEDO.g),cie_encoded_channel(ALBEDO.b));
vec3 finish_choice=cie_nearest(clamp(finish_encoded,vec3(0.0),vec3(1.0)),factory_source_palette,factory_source_palette_count,0.0,0.0);
ALBEDO=vec3(cie_linear_channel(finish_choice.r),cie_linear_channel(finish_choice.g),cie_linear_channel(finish_choice.b));
"""
	code = code.insert(closing - 1, finish)
	code = code.replace("shader_type spatial;", "shader_type spatial;\n#include \"res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc\"\nuniform sampler2D factory_source_palette:filter_nearest,repeat_disable;\nuniform int factory_source_palette_count=5;\n")
	var shader := Shader.new()
	shader.code = code
	Sources.replace_shader(material, shader)
	material.set_shader_parameter("factory_source_palette", Stage.palette_texture(specification.colors))
	material.set_shader_parameter("factory_source_palette_count", specification.colors.size())
	material.set_meta("factory_source_nearest_palette", true)
