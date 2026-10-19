extends RefCounted
## Private created-blade derivative of the selected native torch source. The
## donor noise, subtraction mask, axial fill, scroll and cone mesh stay native.
const NativeFire = preload("res://assets/vfx/sources/cb6c8716b8516ba846d5/native_fire.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")

static func make(axial_uv: bool) -> ShaderMaterial:
	var material: ShaderMaterial = NativeFire.flame(.48 if axial_uv else .38, axial_uv, true)
	var source_gradient: GradientTexture1D = material.get_shader_parameter("Gradient_Color_1D2")
	var gradient_texture: GradientTexture1D = source_gradient.duplicate(true)
	var gradient: Gradient = source_gradient.gradient.duplicate(true)
	# The selected donor's original six-stop ramp is rose/pink. This private
	# authored warm ramp preserves its offsets, interpolation and fire field,
	# while exposing ember -> orange -> gold instead of tinting the whole mesh.
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 1), Color(.14, .025, .001, 1), Color(.48, .115, .004, 1), Color(.95, .40, .025, 1), Color(1, .78, .22, 1)])
	gradient_texture.gradient = gradient
	material.set_shader_parameter("Gradient_Color_1D2", gradient_texture)
	material.set_shader_parameter("enable_vertex_movement", true)
	material.set_shader_parameter("wobble_strength", .12 if axial_uv else .35)
	# Opaque black gradient stops otherwise reveal the carrier between tongues.
	# Keep the source field as coverage and retain the original source fill.
	var shader := Shader.new()
	shader.code = material.shader.code.replace("smoothstep(0.04,0.28,n_out57p0)", "smoothstep(0.25,0.55,n_out57p0)")
	SourceMaterials.replace_shader(material, shader)
	return material
