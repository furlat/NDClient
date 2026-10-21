extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
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
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "Donor"
	node_0.transform = operands[14]
	var node_1 := MeshInstance3D.new()
	node_1.name = "FactoryGenerated_0000_MeshInstance3D"
	node_1.transform = operands[15]
	node_1.material_override = material_0
	node_1.mesh = operands[16]
	node_0.add_child(node_1)
	var node_2 := MeshInstance3D.new()
	node_2.name = "FactoryGenerated_0001_MeshInstance3D"
	node_2.transform = operands[17]
	node_2.material_override = material_0
	node_2.mesh = operands[18]
	node_0.add_child(node_2)
	var node_3 := MeshInstance3D.new()
	node_3.name = "FactoryGenerated_0002_MeshInstance3D"
	node_3.transform = operands[19]
	node_3.material_override = material_0
	node_3.mesh = operands[20]
	node_0.add_child(node_3)
	var node_4 := Node3D.new()
	node_4.name = "FactoryGenerated_0003_Node3D"
	node_4.transform = operands[21]
	node_0.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "FactoryGenerated_0000_MeshInstance3D"
	node_5.material_override = material_0
	node_5.mesh = operands[22]
	node_4.add_child(node_5)
	var node_6 := Node3D.new()
	node_6.name = "FactoryGenerated_0004_Node3D"
	node_6.transform = operands[23]
	node_0.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "FactoryGenerated_0000_MeshInstance3D"
	node_7.material_override = material_0
	node_7.mesh = operands[24]
	node_6.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "FactoryGenerated_0005_MeshInstance3D"
	node_8.transform = operands[25]
	node_8.material_override = material_0
	node_8.mesh = operands[26]
	node_0.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "FactoryGenerated_0006_MeshInstance3D"
	node_9.transform = operands[27]
	node_9.material_override = material_0
	node_9.mesh = operands[28]
	node_0.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "FactoryGenerated_0007_MeshInstance3D"
	node_10.transform = operands[29]
	node_10.material_override = material_0
	node_10.mesh = operands[30]
	node_0.add_child(node_10)
	if profile_details: Profile.end("cloud_program_nodes")
	node_1.owner = node_0
	node_2.owner = node_0
	node_3.owner = node_0
	node_4.owner = node_0
	node_5.owner = node_0
	node_6.owner = node_0
	node_7.owner = node_0
	node_8.owner = node_0
	node_9.owner = node_0
	node_10.owner = node_0
	node_0.scene_file_path = operands[31]
	return {"material_sites_bound": true, "nodes": [node_0, node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10], "private_materials": [material_0], "root": node_0, "geometry": [node_1, node_2, node_3, node_5, node_7, node_8, node_9, node_10], "materials": [], "cohorts": []}
