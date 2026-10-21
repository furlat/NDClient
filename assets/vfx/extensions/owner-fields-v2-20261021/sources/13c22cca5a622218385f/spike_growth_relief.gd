extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/75c46e5e5be336467d9c/terrain_growth.gd"
## Lift the existing rooted donor vine/hooks into readable shin-height relief.
## Seeded footprint, bark texture, tip flex, growth and retirement remain native.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/13c22cca5a622218385f/spike_growth_relief.gd", input)


func build_thorns() -> void:
	super.build_thorns()
	for index in roots.size():
		roots[index].scale.y *= float(parameters.height_gain)
		base_scales[index] = roots[index].scale


func wood() -> ShaderMaterial:
	var result: ShaderMaterial = super.wood()
	var shader := Shader.new()
	# Bark still controls the detail. Lift only the overly dark upper value.
	shader.code = result.shader.code.replace("vec3(.27,.17,.07)", "vec3(.38,.245,.105)")
	SourceMaterials.replace_shader(result, shader)
	return result
