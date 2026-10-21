extends RefCounted
## Explicit native equivalent of the selected energy-ramp/CIE76 colour finishing.
## Alpha, noise and geometry remain owned by the original material/component.
const SourceBindings = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/16a8d77d73d0f71878d8/source_materials.gd")
const Stage = preload("res://assets/vfx/extensions/source-preparation-20261020/sources/9eeed36c281030dc7731/contract_stage.gd")


static func apply(material: ShaderMaterial, colors: Array, options: Dictionary = {}) -> void:
	if colors.is_empty() or material.has_meta("native_energy_palette"):
		return
	var code: String = SourceBindings.expand_shader(material.shader.code, material.shader.resource_path.get_base_dir())
	var fragment: int = code.find("void fragment()")
	var start: int = code.find("{", fragment)
	if fragment < 0 or start < 0:
		push_error("Native palette requires the original fragment function")
		return
	var end: int = start + 1
	var depth: int = 1
	while end < code.length() and depth > 0:
		if code[end] == "{": depth += 1
		elif code[end] == "}": depth -= 1
		end += 1
	var finish: String = """
	float native_raw_energy = max(max(ALBEDO.r + EMISSION.r, ALBEDO.g + EMISSION.g), ALBEDO.b + EMISSION.b);
	native_raw_energy *= native_palette_exposure;
	float native_energy = native_raw_energy / (1.0 + native_raw_energy);
	float native_position = native_energy * float(native_palette_count - 1);
	int native_first = int(floor(native_position));
	int native_second = min(native_first + 1, native_palette_count - 1);
	vec3 native_a = texture(native_palette_texture, vec2((float(native_first) + 0.5) / float(native_palette_count), 0.5)).rgb;
	vec3 native_b = texture(native_palette_texture, vec2((float(native_second) + 0.5) / float(native_palette_count), 0.5)).rgb;
	vec3 native_choice = mix(native_a, native_b, fract(native_position));
	if (native_palette_quantize) native_choice = cie_nearest(native_choice, native_palette_texture, native_palette_count, 0.0, 0.0);
	ALBEDO = vec3(cie_linear_channel(native_choice.r), cie_linear_channel(native_choice.g), cie_linear_channel(native_choice.b));
	EMISSION = ALBEDO * min(native_raw_energy, 2.0) * native_emission_gain;
	"""
	code = code.insert(end - 1, finish)
	code = code.replace("shader_type spatial;", "shader_type spatial;\n#include \"res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc\"\nuniform sampler2D native_palette_texture:filter_nearest,repeat_disable;\nuniform int native_palette_count=1;\nuniform bool native_palette_quantize=true;\nuniform float native_emission_gain=0.0;\nuniform float native_palette_exposure=1.0;")
	var shader: Shader = Shader.new()
	shader.code = code
	SourceBindings.replace_shader(material, shader)
	material.set_shader_parameter("native_palette_texture", Stage.palette_texture(colors))
	material.set_shader_parameter("native_palette_count", colors.size())
	material.set_shader_parameter("native_palette_quantize", options.get("quantize",true))
	material.set_shader_parameter("native_emission_gain", options.get("emission_gain",0.0))
	material.set_shader_parameter("native_palette_exposure", maxf(0.0, float(options.get("energy_exposure",1.0))))
	material.set_meta("native_energy_palette", true)
