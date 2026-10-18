extends "res://assets/vfx/sources/d092a75e3b0074bcf468/control_status.gd"
## Exact native heart particle construction with the selected Charmed finish.
## The original export-half discard is omitted for full native world geometry.

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/062930224d4035e4235f/charmed_source.gd", input)

func adapt_shader(material: ShaderMaterial) -> void:
	var code: String = expand_includes(material.shader.code, material.shader.resource_path.get_base_dir())
	code = code.replace("TIME", "support_clock")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float support_clock=0.0;\nuniform float support_envelope=1.0;\n")
	var shader := Shader.new()
	shader.code = SourceMaterials.finish_fragment(code, "\nALPHA*=support_envelope;\n")
	SourceMaterials.replace_shader(material, shader)
	NativePalette.apply(material, parameters.palette, {"emission_gain": 0.0, "quantize": true, "energy_exposure": 1.0})
	materials.append(material)

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for emitter in node.find_children("*", "GPUParticles3D", true, false):
		# A recipient-owned condition follows its moving receiving body. Its
		# original heart shape, count, seed, gravity and lifetime are unchanged.
		emitter.local_coords = true
	for light in node.find_children("*", "Light3D", true, false):
		light.visible = false
