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
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "Donor"
	var node_1 := MeshInstance3D.new()
	node_1.name = "FactoryGenerated_0000_MeshInstance3D"
	node_1.transform = operands[96]
	node_1.material_override = material_0
	node_1.set_instance_shader_parameter("seed", operands[6])
	node_1.mesh = operands[97]
	node_0.add_child(node_1)
	var node_2 := MeshInstance3D.new()
	node_2.name = "FactoryGenerated_0001_MeshInstance3D"
	node_2.transform = operands[98]
	node_2.material_override = material_1
	node_2.set_instance_shader_parameter("seed", operands[18])
	node_2.mesh = operands[99]
	node_0.add_child(node_2)
	var node_3 := MeshInstance3D.new()
	node_3.name = "FactoryGenerated_0002_MeshInstance3D"
	node_3.transform = operands[100]
	node_3.material_override = material_2
	node_3.set_instance_shader_parameter("seed", operands[30])
	node_3.mesh = operands[101]
	node_0.add_child(node_3)
	var node_4 := MeshInstance3D.new()
	node_4.name = "FactoryGenerated_0003_MeshInstance3D"
	node_4.transform = operands[102]
	node_4.material_override = material_3
	node_4.set_instance_shader_parameter("seed", operands[42])
	node_4.mesh = operands[103]
	node_0.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "FactoryGenerated_0004_MeshInstance3D"
	node_5.transform = operands[104]
	node_5.material_override = material_4
	node_5.set_instance_shader_parameter("seed", operands[54])
	node_5.mesh = operands[105]
	node_0.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "FactoryGenerated_0005_MeshInstance3D"
	node_6.transform = operands[106]
	node_6.material_override = material_5
	node_6.set_instance_shader_parameter("seed", operands[66])
	node_6.mesh = operands[107]
	node_0.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "FactoryGenerated_0006_MeshInstance3D"
	node_7.transform = operands[108]
	node_7.material_override = material_6
	node_7.set_instance_shader_parameter("seed", operands[78])
	node_7.mesh = operands[109]
	node_0.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "FactoryGenerated_0007_MeshInstance3D"
	node_8.transform = operands[110]
	node_8.material_override = material_7
	node_8.set_instance_shader_parameter("seed", operands[90])
	node_8.mesh = operands[111]
	node_0.add_child(node_8)
	if profile_details: Profile.end("cloud_program_nodes")
	node_1.owner = node_0
	node_2.owner = node_0
	node_3.owner = node_0
	node_4.owner = node_0
	node_5.owner = node_0
	node_6.owner = node_0
	node_7.owner = node_0
	node_8.owner = node_0
	node_0.scene_file_path = operands[112]
	return {"material_sites_bound": true, "nodes": [node_0, node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8], "private_materials": [material_0, material_1, material_2, material_3, material_4, material_5, material_6, material_7], "root": node_0, "geometry": [node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8], "materials": [], "cohorts": []}
