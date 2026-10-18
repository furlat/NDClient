extends "res://assets/vfx/sources/4d694813ce66e646e55c/reactive_web.gd"
## Original silk deployment, alpha footprint and local burning remain exact.
## The strands receive scene light and subtle material grain rather than a
## constant unshaded ivory stencil.
const SilkMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	var instance := VfxPackageIO_3c38ae43b1.resource("res://assets/vfx/sources/3c38ae43b109802734cd/reactive_web_lit.gd").new() as Node3D
	instance.settings = input.duplicate(true)
	instance._build()
	return instance


func _build() -> void:
	super._build()
	var shader := Shader.new()
	var code: String = material.shader.code.replace("render_mode unshaded,cull_disabled,depth_draw_never;", "render_mode cull_disabled,depth_draw_never;")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform sampler2D silk_grain:repeat_enable,filter_linear;\n")
	code = SilkMaterials.finish_fragment(code, """
float silk_variation=texture(silk_grain,surface_local_point*.55).r;
ALBEDO*=mix(.68,1.0,silk_variation);
ROUGHNESS=.62;
SPECULAR=.35;
""")
	shader.code = code
	SilkMaterials.replace_shader(material, shader)
	material.set_shader_parameter("silk_grain",VfxPackageIO_3c38ae43b1.resource("res://assets/vfx/sources/33484fce1b5dd1a6902a/texture.res"))

const VfxPackageIO_3c38ae43b1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
