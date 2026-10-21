extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("vfx_package_clock_slot", operands[1])
	material_0.set_shader_parameter("vfx_package_offset_clock", operands[2])
	material_0.set_shader_parameter("bark", operands[3])
	material_0.set_shader_parameter("clock", operands[4])
	material_0.set_shader_parameter("opacity", operands[5])
	material_0.set_meta("factory_prepared_shader", operands[7])
	material_0.set_meta("factory_opacity_prepared_shader", operands[8])
	material_0.set_meta("factory_clock_names", operands[9])
	material_0.set_meta("factory_clock_pool_required", operands[10])
	material_0.set_meta("factory_world_space_uniform", operands[11])
	var material_1: ShaderMaterial = material_0
	var material_2: ShaderMaterial = material_0
	var material_3: ShaderMaterial = material_0
	var material_4: ShaderMaterial = material_0
	var material_5: ShaderMaterial = material_0
	var material_6: ShaderMaterial = material_0
	var material_7: ShaderMaterial = material_0
	var material_8: ShaderMaterial = material_0
	var material_9: ShaderMaterial = material_0
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "Donor"
	var node_1 := Node3D.new()
	node_1.name = "FactoryGenerated_0000_Node3D"
	node_1.transform = operands[120]
	node_0.add_child(node_1)
	var node_2 := MeshInstance3D.new()
	node_2.name = "FactoryGenerated_0000_MeshInstance3D"
	node_2.transform = operands[121]
	node_2.material_override = material_0
	node_2.set_instance_shader_parameter("seed", operands[6])
	node_2.mesh = operands[122]
	node_1.add_child(node_2)
	var node_3 := MeshInstance3D.new()
	node_3.name = "FactoryGenerated_0001_MeshInstance3D"
	node_3.transform = operands[123]
	node_3.material_override = material_1
	node_3.set_instance_shader_parameter("seed", operands[18])
	node_3.mesh = operands[124]
	node_0.add_child(node_3)
	var node_4 := MeshInstance3D.new()
	node_4.name = "FactoryGenerated_0002_MeshInstance3D"
	node_4.transform = operands[125]
	node_4.material_override = material_2
	node_4.set_instance_shader_parameter("seed", operands[30])
	node_4.mesh = operands[126]
	node_0.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "FactoryGenerated_0003_MeshInstance3D"
	node_5.transform = operands[127]
	node_5.material_override = material_3
	node_5.set_instance_shader_parameter("seed", operands[42])
	node_5.mesh = operands[128]
	node_0.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "FactoryGenerated_0004_MeshInstance3D"
	node_6.transform = operands[129]
	node_6.material_override = material_4
	node_6.set_instance_shader_parameter("seed", operands[54])
	node_6.mesh = operands[130]
	node_0.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "FactoryGenerated_0005_MeshInstance3D"
	node_7.transform = operands[131]
	node_7.material_override = material_5
	node_7.set_instance_shader_parameter("seed", operands[66])
	node_7.mesh = operands[132]
	node_0.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "FactoryGenerated_0006_MeshInstance3D"
	node_8.transform = operands[133]
	node_8.material_override = material_6
	node_8.set_instance_shader_parameter("seed", operands[78])
	node_8.mesh = operands[134]
	node_0.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "FactoryGenerated_0007_MeshInstance3D"
	node_9.transform = operands[135]
	node_9.material_override = material_7
	node_9.set_instance_shader_parameter("seed", operands[90])
	node_9.mesh = operands[136]
	node_0.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "FactoryGenerated_0008_MeshInstance3D"
	node_10.transform = operands[137]
	node_10.material_override = material_8
	node_10.set_instance_shader_parameter("seed", operands[102])
	node_10.mesh = operands[138]
	node_0.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "FactoryGenerated_0009_MeshInstance3D"
	node_11.transform = operands[139]
	node_11.material_override = material_9
	node_11.set_instance_shader_parameter("seed", operands[114])
	node_11.mesh = operands[140]
	node_0.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "FactoryGenerated_0010_MeshInstance3D"
	node_12.material_override = operands[141]
	node_12.mesh = operands[142]
	node_0.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "FactoryGenerated_0011_MeshInstance3D"
	node_13.material_override = operands[143]
	node_13.mesh = operands[144]
	node_0.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "FactoryGenerated_0012_MeshInstance3D"
	node_14.material_override = operands[145]
	node_14.mesh = operands[146]
	node_0.add_child(node_14)
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
	node_11.owner = node_0
	node_12.owner = node_0
	node_13.owner = node_0
	node_14.owner = node_0
	node_0.scene_file_path = operands[147]
	return {"material_sites_bound": true, "nodes": [node_0, node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14], "private_materials": [material_0, material_1, material_2, material_3, material_4, material_5, material_6, material_7, material_8, material_9], "root": node_0, "geometry": [node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14], "materials": [], "cohorts": []}
