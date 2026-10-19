extends RefCounted
## Review candidate only: the selected source's own material on two compact
## open recipient curves. No source shell, cast aura, ground disc or lamp.
const Strands = preload("res://assets/vfx/sources/4373fef56294eece4e7a/receiving_strands.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Palette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")

static func make_component(input: Dictionary) -> Node3D:
	var result: Node3D = Strands.make_component(input)
	var shader := Shader.new()
	var code: String = result.material.shader.code
	# Source spherical pole attenuation does not describe an open ribbon;
	# the retained path's tapered ends supply geometric attenuation instead.
	code = code.replace("blend_add", "blend_mix")
	code = code.replace("pow((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.2)", "1.0")
	assert(code.contains("smoothstep(0.5, 0.8, value)"), "Candidate requires its original source noise coverage")
	# A sphere's rare noise peaks covered less than one pixel on these leaves.
	# Retain the actual source noise, but author its coverage for this carrier.
	code = code.replace("smoothstep(0.5, 0.8, value)", "smoothstep(recipient_noise_edges.x, recipient_noise_edges.y, value)")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform vec2 recipient_noise_edges=vec2(.24,.66);\n")
	# This source does not read vertex COLOR. In particular the old petal's
	# source_dissolve alpha is not an opacity input. Soften the actual UV edges.
	code = Materials.finish_fragment(code, "\nALPHA *= smoothstep(0.0,.18,UV.x)*(1.0-smoothstep(.82,1.0,UV.x));\n")
	shader.code = code
	Materials.replace_shader(result.material, shader)
	var edges: Array = input.noise_edges
	result.material.set_shader_parameter("recipient_noise_edges", Vector2(edges[0], edges[1]))
	Palette.apply(result.material, input.palette, input.palette_finish)
	return result
