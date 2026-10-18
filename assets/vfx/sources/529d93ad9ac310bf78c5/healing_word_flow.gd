extends "res://assets/vfx/sources/e05313730c1f6867fb65/healing_word_wisps.gd"
## Bend the two source W1 streaks into short rising wisps. Preserve their source
## texture, gradients, emitter timing and selected-recipient ownership.
const SourceMaterial = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const EnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/529d93ad9ac310bf78c5/healing_word_flow.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for path in ["verticalflash", "SecondaryAuthoredHealingWisp"]:
		var wisp := node.get_node(path) as GPUParticles3D
		var quad := PlaneMesh.new()
		quad.orientation = PlaneMesh.FACE_Z
		quad.size = wisp.draw_pass_1.size
		quad.subdivide_depth = 16
		quad.subdivide_width = 2
		wisp.draw_pass_1 = quad
		wisp.amount = 2
		wisp.local_coords = true
		var process := wisp.process_material as ParticleProcessMaterial
		process.spread = 9.0
		process.initial_velocity_min = 0.18
		process.initial_velocity_max = 0.55
		process.gravity = Vector3(0, 0.35, 0)


func adapt_shader(material: ShaderMaterial) -> void:
	super.adapt_shader(material)
	if not material.shader.code.contains("uniform sampler2D BaseTexture"):
		return
	var code := SourceMaterial.finish_function(material.shader.code, "vertex", """
	float wisp_curve = sin(3.14159265 * UV.y);
	float wisp_age = support_clock * 3.0 + INSTANCE_CUSTOM.y * 6.2831853;
	VERTEX.x *= 0.45 + 0.55 * wisp_curve;
	VERTEX.x += wisp_curve * (0.55 + 0.10 * sin(wisp_age));
	VERTEX.z += wisp_curve * 0.12 * cos(wisp_age * 0.7);
	""")
	code = SourceMaterial.finish_fragment(code, """
	ALPHA *= smoothstep(0.01, 0.14, UV.y) * (1.0 - smoothstep(0.78, 1.0, UV.y));
	""")
	var shader := Shader.new()
	shader.code = code
	SourceMaterial.replace_shader(material, shader)
	EnergyPalette.apply(material, settings.palette, {"quantize": false, "energy_exposure": 0.85})
