extends RefCounted
## False Life's own Binbun material on open, measured receiving curves. Reuse
## the support-fitting tool, not another spell's complete artwork or body film.
const ReceivingStrands = preload("res://assets/vfx/sources/4373fef56294eece4e7a/receiving_strands.gd")
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")
const EnergyPalette = preload("res://assets/vfx/sources/386bc581a35eb3b9ee50/spatial_energy_palette.gd")


static func make_component(input: Dictionary) -> Node3D:
	var result: Node3D = ReceivingStrands.make_component(input)
	var shader := Shader.new()
	# Its old spherical pole mask is inappropriate for a tapered open strand:
	# geometry supplies the ends. Retain source noise/scroll as flowing detail.
	shader.code = result.material.shader.code.replace(
		"pow((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.2)", "1.0")
	shader.code = shader.code.replace("value = smoothstep(0.5, 0.8, value);", "value = smoothstep(0.10, 0.65, value);")
	shader.code = shader.code.replace("ALPHA = value;", "ALPHA = 0.2 + 0.8 * value;")
	shader.code = shader.code.replace("blend_add", "blend_mix")
	SourceMaterials.replace_shader(result.material, shader)
	EnergyPalette.apply(result.material, input.palette, {"quantize": false, "energy_exposure": 1.0})
	# Keep the occurrence fade independent of the source's zero-at-birth clock.
	NativeOpacity.apply(result)
	if input.get("gpu_paths",false):
		result=preload("res://assets/vfx/sources/b4406eb67f97fda9fcd6/receiving_flow.gd").from_native(result,input)
	return result
