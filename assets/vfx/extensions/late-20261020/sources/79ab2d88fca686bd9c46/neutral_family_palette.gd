extends RefCounted
## Original indexed neutral-level replacement; distinct from an energy ramp.
## Per-instance native equivalent of a documented grayscale capture finishing step.

const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Stage = preload("res://assets/vfx/sources/7ffdb77f06cb06b0c42e/contract_stage.gd")

static func apply(material: ShaderMaterial, specification: Dictionary) -> void:
	var colors: Array = specification.colors
	var levels: Array = specification.neutral_levels
	assert(colors.size()==levels.size() and colors.size()>1 and colors.size()<=64)
	if material.has_meta("neutral_family_palette"):
		return
	var code := SourceMaterials.expand_shader(material.shader.code,material.shader.resource_path.get_base_dir())
	var begin := code.find("void fragment()")
	var opening := code.find("{",begin)
	assert(begin>=0 and opening>=0)
	var depth := 1
	var closing := opening+1
	while closing<code.length() and depth>0:
		if code[closing]=="{":
			depth+=1
		elif code[closing]=="}":
			depth-=1
		closing+=1
	var finish := """
	float neutral_encoded = (cie_encoded_channel(ALBEDO.r) + cie_encoded_channel(ALBEDO.g) + cie_encoded_channel(ALBEDO.b)) / 3.0;
	if (neutral_albedo_is_encoded) neutral_encoded = (ALBEDO.r+ALBEDO.g+ALBEDO.b)/3.0;
	neutral_encoded = min(neutral_encoded * neutral_gain, neutral_levels[neutral_count-1]);
	int neutral_choice = 0;
	float neutral_distance = 1000.0;
	for (int index=0; index<64; index++) {
		if (index>=neutral_count) break;
		float candidate_distance = abs(neutral_encoded-neutral_levels[index]);
		if (candidate_distance<neutral_distance) {
			neutral_choice=index;
			neutral_distance=candidate_distance;
		}
	}
	vec3 family_encoded = texture(neutral_family,vec2((float(neutral_choice)+0.5)/float(neutral_count),0.5)).rgb;
	ALBEDO=vec3(cie_linear_channel(family_encoded.r),cie_linear_channel(family_encoded.g),cie_linear_channel(family_encoded.b));
	"""
	code=code.insert(closing-1,finish)
	code=code.replace("shader_type spatial;","shader_type spatial;\n#include \"res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc\"\nuniform sampler2D neutral_family:filter_nearest,repeat_disable;\nuniform float neutral_levels[64];\nuniform int neutral_count=8;\nuniform float neutral_gain=1.45;\nuniform bool neutral_albedo_is_encoded=false;")
	var shader := Shader.new()
	shader.code=code
	SourceMaterials.replace_shader(material,shader)
	var normalized := PackedFloat32Array()
	normalized.resize(64)
	for index in range(levels.size()):
		normalized[index]=float(levels[index])/255.0
	material.set_shader_parameter("neutral_family",Stage.palette_texture(colors))
	material.set_shader_parameter("neutral_levels",normalized)
	material.set_shader_parameter("neutral_count",colors.size())
	material.set_shader_parameter("neutral_gain",float(specification.gain))
	material.set_shader_parameter("neutral_albedo_is_encoded",specification.get("albedo_is_encoded_srgb",false))
	material.set_meta("neutral_family_palette",true)
