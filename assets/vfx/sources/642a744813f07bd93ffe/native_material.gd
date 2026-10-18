extends RefCounted
## Extract only a selected Weapon Effects material. Demo geometry, particles,
## lights, masks painted for a different sword and global TIME are excluded.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const EnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")

static func make(input: Dictionary, motif: String, finish: String) -> ShaderMaterial:
	var source: Shader = VfxPackageIO_642a744813.resource(str(input.shader))
	assert(source != null and FileAccess.file_exists(str(input.texture)))
	var code := SourceMaterials.expand_shader(source.code, source.resource_path.get_base_dir())
	code = code.replace("TIME", "weapon_clock")
	code = code.replace("depth_draw_opaque", "depth_draw_never").replace("cull_back", "cull_disabled")
	code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float weapon_clock=0.0;\nuniform float weapon_envelope=0.0;\nuniform float weapon_application=0.0;\n" + motif)
	code = SourceMaterials.finish_fragment(code, finish)
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("Aura_Color", Color.html(str(input.colour)))
	material.set_shader_parameter("Aura_Texture", VfxPackageIO_642a744813.resource(str(input.texture)))
	# No demo-sword UV mask: the real measured item footprint owns coverage.
	material.set_shader_parameter("Has_mask", false)
	material.set_shader_parameter("Mask", VfxPackageIO_642a744813.resource(str(input.texture)))
	material.set_shader_parameter("Aura_Divide", Vector2(input.divide[0], input.divide[1]))
	material.set_shader_parameter("Speed", Vector2(input.speed[0], input.speed[1]))
	if input.has("power"):
		material.set_shader_parameter("Arua_Power", float(input.power))
	if input.has("fresnel"):
		material.set_shader_parameter("fresnel", float(input.fresnel))
	EnergyPalette.apply(material, input.palette, {"quantize":false, "emission_gain":0.0})
	material.render_priority = 1
	return material

const VfxPackageIO_642a744813 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
