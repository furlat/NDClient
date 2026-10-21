extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func material(operands: Array, profile_details: bool = false) -> ShaderMaterial:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("vfx_package_clock_slot", operands[1])
	material_0.set_shader_parameter("vfx_package_offset_clock", operands[2])
	material_0.set_shader_parameter("dark_tone", operands[3])
	material_0.set_shader_parameter("mid_tone", operands[4])
	material_0.set_shader_parameter("light_tone", operands[5])
	material_0.set_shader_parameter("clock", operands[6])
	material_0.set_shader_parameter("strength", operands[7])
	material_0.set_meta("factory_native_program_defaults", operands[8])
	material_0.set_meta("factory_prepared_shader", operands[9])
	material_0.set_meta("factory_opacity_prepared_shader", operands[10])
	material_0.set_meta("factory_clock_names", operands[11])
	material_0.set_meta("factory_clock_pool_required", operands[12])
	material_0.set_meta("factory_world_space_uniform", operands[13])
	if profile_details: Profile.end("cloud_program_materials")
	return material_0
