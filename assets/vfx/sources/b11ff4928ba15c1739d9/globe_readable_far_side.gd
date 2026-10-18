extends "res://assets/vfx/sources/c0fc8f9a283c64e75067/gold_globe.gd"
## Keep the original gold source shell, hexes, source clock and occurrence fade.
## Distant inward-facing triangles contribute less duplicate linework.
const Bindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/b11ff4928ba15c1739d9/globe_readable_far_side.gd",input)


func adapt(material: ShaderMaterial, ground: bool = false, dual: bool = false) -> void:
	super.adapt(material,ground,dual)
	if settings.kind != "globe":
		return
	var shader := Shader.new()
	shader.code = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nuniform float globe_far_side_gain=.25;\n")
	shader.code = Bindings.finish_fragment(shader.code,"\nif(!FRONT_FACING) ALPHA*=globe_far_side_gain;\n")
	Bindings.replace_shader(material,shader)
	material.set_shader_parameter("globe_far_side_gain",float(settings.far_side_gain))
