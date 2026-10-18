extends "res://assets/vfx/sources/1e83a91767b68e67396e/healing.gd"
## The original focused cone, leaves and ribbons, with grouped light shafts
## in its own scrolling source noise. No new cone, palette or particles.
const RayBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/60ba9fab763cbf7c2a3a/restoration_ray_groups.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	node.get_node("SmConeTypeBa").material_override.set_meta("restoration_ray_groups", true)


func adapt_shader(material: ShaderMaterial) -> void:
	super.adapt_shader(material)
	if not material.get_meta("restoration_ray_groups", false):
		return
	var original := "float noise_val = texture(noise_texture, noise_uv).r;"
	assert(material.shader.code.count(original) == 1, "Restoration source noise changed")
	var shader := Shader.new()
	shader.code = material.shader.code.replace(original,
		original + "\nnoise_val=smoothstep(0.32,0.76,noise_val);\n")
	RayBindings.replace_shader(material, shader)
