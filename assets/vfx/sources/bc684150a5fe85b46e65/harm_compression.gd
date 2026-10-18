extends "res://assets/vfx/sources/02e8eda447821da38634/necrotic.gd"
## Preserve the original compression geometry/noise and dark/scarlet contact;
## open its broad faces and keep the pale native streaks subordinate.
const HarmMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/bc684150a5fe85b46e65/harm_compression.gd", input)


func apply_scene_edits(node: Node) -> void:
	assert(settings.kind == "harm")
	super.apply_scene_edits(node)
	var streaks: ShaderMaterial = donor.get_node("Aura").material_override
	var code: String = HarmMaterials.finish_fragment(streaks.shader.code,
		"\nALPHA *= 0.55 * (1.0-smoothstep(0.35,0.85,support_clock));\n")
	var shader := Shader.new()
	shader.code = code
	HarmMaterials.replace_shader(streaks, shader)


func custom_material(style: int) -> ShaderMaterial:
	var material: ShaderMaterial = super.custom_material(style)
	if style == 0:
		var code: String = material.shader.code
		assert(code.contains("float face=smoothstep(.25,.38,n)"))
		code = code.replace("float face=smoothstep(.25,.38,n)", "float face=smoothstep(.46,.68,n)")
		code = code.replace("ALPHA=face*fade*(.7+.3*edge);", "ALPHA=face*fade*(.20+.65*edge);")
		var shader := Shader.new()
		shader.code = code
		HarmMaterials.replace_shader(material, shader)
	return material


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.native_folds_retained = blades.size()
	result.inward_contraction_retained = true
	result.pale_streak_finish_seconds = 0.85
	result.whole_layers_removed = 0
	result.optical_lights_added = 0
	return result
