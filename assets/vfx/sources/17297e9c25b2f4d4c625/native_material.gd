extends RefCounted
## New authored spatial bands. Selected LeLu noise is a material ingredient,
## never a copied complete spell, demo light, geometry or global clock.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const SupportMaterial = preload("res://assets/vfx/sources/fab3b2fc2c95a74d1a47/source_material.gd")
const HOLY_SOURCE = "res://assets/vfx/sources/388327134640b78113bd/7fbb09109872ebd1046994ac5eac8a2775bbeafbabff54c98041d8b9bcbf9ed7.gdshader"

static func make(specification: Dictionary) -> ShaderMaterial:
	if specification.get("native_family", "") == "holy_plume":
		return holy_plume(specification)
	if specification.get("native_family", "") == "heal":
		return SupportMaterial.make(specification.native_material)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_noise:repeat_enable;
uniform vec4 pigment:source_color;
uniform float support_clock=0.0;
uniform float support_envelope=0.0;
uniform float support_visibility=1.0;
uniform float grain_strength=0.22;
uniform sampler2D leaf_mask;
uniform bool use_leaf_mask=false;
void fragment(){
 float edge=pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),0.7);
 float grain=texture(source_noise,UV*vec2(1.2,3.1)+vec2(0.0,-support_clock*0.13)).r;
 float ink=(1.0-grain_strength)+grain_strength*grain;
 ALBEDO=pigment.rgb*COLOR.rgb;
 EMISSION=vec3(0.0);
 vec4 leaf=texture(leaf_mask,UV);
 float silhouette=use_leaf_mask?leaf.r*leaf.a*edge:edge;
 ALPHA=pigment.a*COLOR.a*silhouette*ink*support_envelope*support_visibility;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("source_noise", VfxPackageIO_17297e9c25.resource(str(specification.texture)))
	material.set_shader_parameter("pigment", Color.html(str(specification.colour)))
	material.set_shader_parameter("grain_strength", float(specification.get("grain_strength", .22)))
	material.set_shader_parameter("use_leaf_mask", specification.has("leaf_texture"))
	material.set_shader_parameter("leaf_mask", VfxPackageIO_17297e9c25.resource(str(specification.get("leaf_texture", specification.texture))))
	return material

static func holy_plume(specification: Dictionary) -> ShaderMaterial:
	# The original authored holy-contact plume fragment is retained. Only its
	# billboard vertex is replaced because the new folded geometry is world-space.
	var code: String = VfxPackageIO_17297e9c25.text(HOLY_SOURCE)
	var begin: int = code.find("void vertex()")
	var end: int = code.find("void fragment()")
	code = code.substr(0, begin) + "void vertex(){v_uv=UV;v_w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}\n" + code.substr(end)
	code = code.replace("spell_clock", "support_clock")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float support_envelope=0.0;\nuniform float support_visibility=1.0;")
	code = SourceMaterials.finish_fragment(code, "\nALPHA*=support_envelope*support_visibility;\n")
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	var noise := NoiseTexture2D.new()
	noise.width = 128
	noise.height = 128
	noise.seamless = true
	noise.normalize = true
	var generator := FastNoiseLite.new()
	generator.seed = 916
	generator.frequency = .045
	generator.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.noise = generator
	material.set_shader_parameter("noise_tex", noise)
	var pigment := Color.html(str(specification.colour))
	material.set_shader_parameter("core_color", pigment.lightened(.28))
	material.set_shader_parameter("edge_color", pigment)
	material.set_shader_parameter("intensity", .65)
	material.set_shader_parameter("alpha_mult", .88)
	return material

const VfxPackageIO_17297e9c25 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
