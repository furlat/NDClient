extends RefCounted
## Private native adaptation of CounterspellHandCapture's six-stop energy finish.
## This maps original material inputs before lighting, not a historical pixel bank.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Stage = preload("res://assets/vfx/sources/7ffdb77f06cb06b0c42e/contract_stage.gd")


static func apply(material: ShaderMaterial, specification: Dictionary) -> void:
	assert(specification.id == "source_pow_energy_nearest")
	assert(specification.colors.size() == 6 and is_equal_approx(float(specification.exponent), 1.15))
	assert(not material.has_meta("finger_source_finish_v193"))
	var code: String = Sources.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	var finish := """
// Original grayscale ALBEDO/EMISSION, noise, view seam and age are retained above.
// Original capture quantized max RGB after lighting/2x2 alpha pooling. Native
// surfaces expose these scalar inputs before lighting; that difference is explicit.
float finger_source_energy=clamp(max(max(ALBEDO.r+EMISSION.r,ALBEDO.g+EMISSION.g),ALBEDO.b+EMISSION.b),0.0,1.0);
float finger_source_index=floor(pow(finger_source_energy,finger_source_exponent)*float(finger_source_count-1)+0.5);
vec3 finger_source_encoded=texture(finger_source_palette,vec2((finger_source_index+0.5)/float(finger_source_count),0.5)).rgb;
ALBEDO=vec3(cie_linear_channel(finger_source_encoded.r),cie_linear_channel(finger_source_encoded.g),cie_linear_channel(finger_source_encoded.b));
EMISSION=vec3(0.0);
"""
	code = Sources.finish_fragment(code, finish)
	code = code.replace("shader_type spatial;", "shader_type spatial;\n#include \"res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc\"\nuniform sampler2D finger_source_palette:filter_nearest,repeat_disable;\nuniform int finger_source_count=6;\nuniform float finger_source_exponent=1.15;\n")
	var shader := Shader.new()
	shader.code = code
	Sources.replace_shader(material, shader)
	material.set_shader_parameter("finger_source_palette", Stage.palette_texture(specification.colors))
	material.set_shader_parameter("finger_source_count", specification.colors.size())
	material.set_shader_parameter("finger_source_exponent", specification.exponent)
	material.set_meta("finger_source_finish_v193", true)
