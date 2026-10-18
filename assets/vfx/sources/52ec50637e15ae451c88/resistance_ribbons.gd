extends "res://assets/vfx/sources/ec9cb8f39586b3f03214/support.gd"
## The original neutral Binbun field, kept translucent and source-noisy instead
## of overexposing its middle band into a rigid white torso strap.
const EnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/52ec50637e15ae451c88/resistance_ribbons.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	node.set_script(null)
	for light in node.find_children("*", "Light3D", true, false):
		light.visible = false


func adapt_shader(material: ShaderMaterial) -> void:
	# Fractional powers of the negative pole mask are undefined. Clamp the
	# source domain without changing its noise or inventing another geometry.
	var code := material.shader.code.replace(
		"pow((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.2)",
		"pow(max((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.0), 0.2)")
	# Front/back noisy lobes overlap on this small field. Additive accumulation
	# washed them to white; ordinary translucency retains their blue-grey colour.
	code = code.replace("blend_add", "blend_mix")
	code = code.replace("smoothstep(0.5, 0.8, value)", "smoothstep(0.38, 0.78, value)")
	var shader := Shader.new()
	shader.code = code
	NativeShaderBindings.replace_shader(material, shader)
	material.set_shader_parameter("emission", 0.8)
	material.set_shader_parameter("hue_variation", 0.0)
	material.set_shader_parameter("proximity_fade", false)
	material.set_shader_parameter("noise_scale", Vector2(2.0, 1.5))
	material.set_shader_parameter("noise_scroll", Vector2(0.12, 0.35))
	super.adapt_shader(material)
	EnergyPalette.apply(material, settings.palette, {"quantize": false, "energy_exposure": 0.8})
