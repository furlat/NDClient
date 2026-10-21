extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("vfx_package_clock_slot", operands[1])
	material_0.set_shader_parameter("vfx_package_offset_clock", operands[2])
	material_0.set_shader_parameter("flow_noise", operands[3])
	material_0.set_shader_parameter("deep", operands[4])
	material_0.set_shader_parameter("energy", operands[5])
	material_0.set_shader_parameter("clock", operands[6])
	material_0.set_shader_parameter("envelope", operands[7])
	material_0.set_shader_parameter("emission_strength", operands[8])
	material_0.set_shader_parameter("opacity_scale", operands[9])
	material_0.set_shader_parameter("ambient_shadow", operands[10])
	material_0.set_meta("factory_native_program_defaults", operands[11])
	material_0.set_meta("factory_prepared_shader", operands[12])
	material_0.set_meta("factory_opacity_prepared_shader", operands[13])
	material_0.set_meta("factory_clock_names", operands[14])
	material_0.set_meta("factory_clock_pool_required", operands[15])
	material_0.set_meta("factory_world_space_uniform", operands[16])
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "effect"
	var node_1 := MeshInstance3D.new()
	node_1.name = "FactoryGenerated_0000_MeshInstance3D"
	node_1.transform = operands[17]
	node_1.material_override = material_0
	node_1.cast_shadow = operands[18]
	node_1.mesh = operands[19]
	node_0.add_child(node_1)
	if profile_details: Profile.end("cloud_program_nodes")
	node_1.owner = node_0
	node_0.scene_file_path = operands[20]
	return {"material_sites_bound": true, "nodes": [node_0, node_1], "private_materials": [material_0], "root": node_0, "geometry": [node_1], "materials": [], "cohorts": []}
