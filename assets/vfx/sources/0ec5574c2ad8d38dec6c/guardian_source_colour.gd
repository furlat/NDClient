extends "res://assets/vfx/sources/3c48de3e8d75b3df352b/guardian_sentinel.gd"
## Original guardian geometry/rig/material roles with explicit source encoding.
## Occurrence opacity includes the source's separate StandardMaterial visor.
const SourceEncoding = preload("res://assets/vfx/sources/22b61e8aa01ff74d1ee3/guardian_source_encoding.gd")
var source_shader_hashes: Array[String] = []
var visor_material: StandardMaterial3D
var visor_opacity: float = 1.0:
	set(value):
		visor_opacity = clampf(value, 0.0, 1.0)
		if visor_material != null:
			var colour: Color = visor_material.albedo_color
			colour.a = visor_opacity
			visor_material.albedo_color = colour


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = construct("res://assets/vfx/sources/0ec5574c2ad8d38dec6c/guardian_source_colour.gd", input)
	instance.name = "effect"
	return instance


func build() -> void:
	super.build()
	assert(settings.has("source_material") and settings.source_material is Dictionary)
	for material in materials:
		source_shader_hashes.append(material.shader.code.sha256_text())
		SourceEncoding.apply(material, settings.source_material)
	var visor := model.find_child("Dark_Visor", true, false) as MeshInstance3D
	assert(visor != null and visor.material_override is StandardMaterial3D)
	visor_material = visor.material_override
	visor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visor_opacity = visor_opacity


func capture_observation() -> Dictionary:
	var observation: Dictionary = super.capture_observation()
	observation["visor_occurrence_alpha"] = visor_opacity
	observation["visor_material_alpha"] = visor_material.albedo_color.a if visor_material != null else -1.0
	observation["visor_transparency_alpha"] = visor_material != null and visor_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
	observation["spectral_occurrence_alpha"] = materials.map(func(material: ShaderMaterial) -> Variant: return material.get_shader_parameter("factory_occurrence_alpha"))
	observation["source_capture_encoding"] = settings.source_material.capture_encoding
	observation["source_encoding_enabled"] = materials.map(func(material: ShaderMaterial) -> Variant: return material.get_shader_parameter("guardian_source_encoded_albedo"))
	observation["original_source_shader_hashes"] = source_shader_hashes
	observation["source_ghost"] = materials.map(func(material: ShaderMaterial) -> Variant: return material.get_shader_parameter("ghost"))
	return observation
