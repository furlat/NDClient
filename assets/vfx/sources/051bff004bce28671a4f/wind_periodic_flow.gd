extends "res://assets/vfx/sources/94d264858d8a892d13f7/wind_modules.gd"
## Macro-noise transport closes smoothly with the source two-second clock.
## Keep the three native flowing wind layers and arbitrary joined path.
## Large advected source-noise coverage varies the repeated dense white strands.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/051bff004bce28671a4f/wind_periodic_flow.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for index in wall.mats.size():
		var material: ShaderMaterial = wall.mats[index]
		var shader := Shader.new()
		shader.code = material.shader.code.replace("shader_type spatial;", """shader_type spatial;
uniform sampler2D wind_macro_noise:repeat_enable,filter_linear;
uniform float wind_macro_phase=0.0;
""")
		shader.code = Sources.finish_fragment(shader.code, """
float wind_macro=texture(wind_macro_noise,vec2(UV.x*.13+wind_macro_phase,UV.y*.7)+.12*vec2(cos(wind_clock*3.14159265359),sin(wind_clock*3.14159265359))).r;
ALPHA *= .16+.52*smoothstep(.22,.72,wind_macro);
""")
		Sources.replace_shader(material, shader)
		material.set_shader_parameter("wind_macro_noise", VfxPackageIO_051bff004b.resource(settings.coverage_noise))
		material.set_shader_parameter("wind_macro_phase",float(index % 3)*.27)

const VfxPackageIO_051bff004b = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
