extends "res://assets/vfx/sources/2bc32a498b43894b5603/conditions.gd"
## Original eight-sector angular release; erosion follows the original noise
## as each piece separates, rather than leaving broad translucent scraps.
const PeelBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/eec63d6a43751cfc0c61/cleansing_peel.gd", input)


func adapt_shader(material: ShaderMaterial) -> void:
	super.adapt_shader(material)
	if not material.has_meta("curse_sector"):
		return
	var addition := """
	float peel_age=smoothstep(0.18,0.95,support_clock);
	vec2 peel_uv=vec2(UV.x-UV.y*noise_twist,UV.y)*noise_scale+support_clock*noise_scroll;
	float peel_noise=texture(noise_texture,peel_uv*vec2(1.7,2.3)).r;
	float peel_cut=mix(0.08,0.88,peel_age);
	ALPHA*=smoothstep(peel_cut,peel_cut+0.14,peel_noise);
	ALPHA*=1.0-smoothstep(0.65,1.25,support_clock);
	"""
	var shader := Shader.new()
	shader.code = PeelBindings.finish_fragment(material.shader.code, addition)
	PeelBindings.replace_shader(material, shader)
