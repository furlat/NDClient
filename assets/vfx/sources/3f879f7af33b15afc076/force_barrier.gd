extends "res://assets/vfx/sources/fe6a0d81ec5daed7ad4a/force_construction.gd"
## Selected native blue field derivative. Retains the donor overlay, alpha,
## growth, contact ripple and dissolution; emission follows the authored blue.

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/3f879f7af33b15afc076/force_barrier.gd", input)

func force_material_source() -> ShaderMaterial:
	var material := super.force_material_source()
	var original: ShaderMaterial = VfxPackageIO_3f879f7af3.resource("res://assets/vfx/sources/5b5a61351d0f2a4281e3/m_basic_blueshield1.tres")
	var samplers := RegEx.new()
	samplers.compile("uniform\\s+sampler2D\\s+(\\w+)")
	for sampler in samplers.search_all(original.shader.code):
		var name: String = sampler.get_string(1)
		if material.get_shader_parameter(name) == null:
			var texture: Texture2D = original.shader.get_default_texture_parameter(name)
			if texture != null:
				material.set_shader_parameter(name,texture)
	var shader := Shader.new()
	var code: String = material.shader.code
	var emission: float = float(settings.get("blue_emission", .38))
	shader.code = code.insert(code.rfind("}"), "\nEMISSION=ALBEDO*" + str(emission) + ";\n")
	SourceMaterials.replace_shader(material,shader)
	return material

const VfxPackageIO_3f879f7af3 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
