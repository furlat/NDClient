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
	var node_4 := MeshInstance3D.new()
	node_4.name = "FactoryGenerated_0003_MeshInstance3D"
	node_4.transform = operands[21]
	node_4.material_override = material_0
	node_4.mesh = operands[22]
	node_0.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "FactoryGenerated_0004_MeshInstance3D"
	node_5.transform = operands[23]
	node_5.material_override = material_0
	node_5.mesh = operands[24]
	node_0.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "FactoryGenerated_0005_MeshInstance3D"
	node_6.transform = operands[25]
	node_6.material_override = material_0
	node_6.mesh = operands[26]
	node_0.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "FactoryGenerated_0006_MeshInstance3D"
	node_7.transform = operands[27]
	node_7.material_override = material_0
	node_7.mesh = operands[28]
	node_0.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "FactoryGenerated_0007_MeshInstance3D"
	node_8.transform = operands[29]
	node_8.material_override = material_0
	node_8.mesh = operands[30]
	node_0.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "FactoryGenerated_0008_MeshInstance3D"
	node_9.transform = operands[31]
	node_9.material_override = material_0
	node_9.mesh = operands[32]
	node_0.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "FactoryGenerated_0009_MeshInstance3D"
	node_10.transform = operands[33]
	node_10.material_override = material_0
	node_10.mesh = operands[34]
	node_0.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "FactoryGenerated_0010_MeshInstance3D"
	node_11.transform = operands[35]
	node_11.material_override = material_0
	node_11.mesh = operands[36]
	node_0.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "FactoryGenerated_0011_MeshInstance3D"
	node_12.transform = operands[37]
	node_12.material_override = material_0
	node_12.mesh = operands[38]
	node_0.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "FactoryGenerated_0012_MeshInstance3D"
	node_13.transform = operands[39]
	node_13.material_override = material_0
	node_13.mesh = operands[40]
	node_0.add_child(node_13)
	var node_14 := Node3D.new()
	node_14.name = "FactoryGenerated_0013_Node3D"
	node_14.transform = operands[41]
	node_0.add_child(node_14)
	var node_15 := MeshInstance3D.new()
	node_15.name = "FactoryGenerated_0000_MeshInstance3D"
	node_15.material_override = material_0
	node_15.mesh = operands[42]
	node_14.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "FactoryGenerated_0001_MeshInstance3D"
	node_16.transform = operands[43]
	node_16.material_override = material_0
	node_16.mesh = operands[44]
	node_14.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "FactoryGenerated_0002_MeshInstance3D"
	node_17.transform = operands[45]
	node_17.material_override = material_0
	node_17.mesh = operands[46]
	node_14.add_child(node_17)
	var node_18 := MeshInstance3D.new()
	node_18.name = "FactoryGenerated_0003_MeshInstance3D"
	node_18.transform = operands[47]
	node_18.material_override = material_0
	node_18.mesh = operands[48]
	node_14.add_child(node_18)
	var node_19 := MeshInstance3D.new()
	node_19.name = "FactoryGenerated_0004_MeshInstance3D"
	node_19.transform = operands[49]
	node_19.material_override = material_0
	node_19.mesh = operands[50]
	node_14.add_child(node_19)
	var node_20 := MeshInstance3D.new()
	node_20.name = "FactoryGenerated_0014_MeshInstance3D"
	node_20.transform = operands[51]
	node_20.material_override = material_0
	node_20.mesh = operands[52]
	node_0.add_child(node_20)
	var node_21 := MeshInstance3D.new()
	node_21.name = "FactoryGenerated_0015_MeshInstance3D"
	node_21.transform = operands[53]
	node_21.material_override = material_0
	node_21.mesh = operands[54]
	node_0.add_child(node_21)
	var node_22 := MeshInstance3D.new()
	node_22.name = "FactoryGenerated_0016_MeshInstance3D"
	node_22.transform = operands[55]
	node_22.material_override = material_0
	node_22.mesh = operands[56]
	node_0.add_child(node_22)
	var node_23 := MeshInstance3D.new()
	node_23.name = "FactoryGenerated_0017_MeshInstance3D"
	node_23.transform = operands[57]
	node_23.material_override = material_0
	node_23.mesh = operands[58]
	node_0.add_child(node_23)
	var node_24 := MeshInstance3D.new()
	node_24.name = "FactoryGenerated_0018_MeshInstance3D"
	node_24.transform = operands[59]
	node_24.material_override = material_0
	node_24.mesh = operands[60]
	node_0.add_child(node_24)
	var node_25 := MeshInstance3D.new()
	node_25.name = "FactoryGenerated_0019_MeshInstance3D"
	node_25.transform = operands[61]
	node_25.material_override = material_0
	node_25.mesh = operands[62]
	node_0.add_child(node_25)
	var node_26 := MeshInstance3D.new()
	node_26.name = "FactoryGenerated_0020_MeshInstance3D"
	node_26.transform = operands[63]
	node_26.material_override = material_0
	node_26.mesh = operands[64]
	node_0.add_child(node_26)
	var node_27 := MeshInstance3D.new()
	node_27.name = "FactoryGenerated_0021_MeshInstance3D"
	node_27.transform = operands[65]
	node_27.material_override = material_0
	node_27.mesh = operands[66]
	node_0.add_child(node_27)
	var node_28 := MeshInstance3D.new()
	node_28.name = "FactoryGenerated_0022_MeshInstance3D"
	node_28.transform = operands[67]
	node_28.material_override = material_0
	node_28.mesh = operands[68]
	node_0.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "FactoryGenerated_0023_MeshInstance3D"
	node_29.transform = operands[69]
	node_29.material_override = material_0
	node_29.mesh = operands[70]
	node_0.add_child(node_29)
	var node_30 := Node3D.new()
	node_30.name = "FactoryGenerated_0024_Node3D"
	node_30.transform = operands[71]
	node_0.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "FactoryGenerated_0000_MeshInstance3D"
	node_31.material_override = material_0
	node_31.mesh = operands[72]
	node_30.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "FactoryGenerated_0001_MeshInstance3D"
	node_32.transform = operands[73]
	node_32.material_override = material_0
	node_32.mesh = operands[74]
	node_30.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "FactoryGenerated_0002_MeshInstance3D"
	node_33.transform = operands[75]
	node_33.material_override = material_0
	node_33.mesh = operands[76]
	node_30.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "FactoryGenerated_0003_MeshInstance3D"
	node_34.transform = operands[77]
	node_34.material_override = material_0
	node_34.mesh = operands[78]
	node_30.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "FactoryGenerated_0004_MeshInstance3D"
	node_35.transform = operands[79]
	node_35.material_override = material_0
	node_35.mesh = operands[80]
	node_30.add_child(node_35)
	var node_36 := MeshInstance3D.new()
	node_36.name = "FactoryGenerated_0025_MeshInstance3D"
	node_36.transform = operands[81]
	node_36.material_override = material_0
	node_36.mesh = operands[82]
	node_0.add_child(node_36)
	var node_37 := MeshInstance3D.new()
	node_37.name = "FactoryGenerated_0026_MeshInstance3D"
	node_37.transform = operands[83]
	node_37.material_override = material_0
	node_37.mesh = operands[84]
	node_0.add_child(node_37)
	var node_38 := MeshInstance3D.new()
	node_38.name = "FactoryGenerated_0027_MeshInstance3D"
	node_38.transform = operands[85]
	node_38.material_override = material_0
	node_38.mesh = operands[86]
	node_0.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "FactoryGenerated_0028_MeshInstance3D"
	node_39.transform = operands[87]
	node_39.material_override = material_0
	node_39.mesh = operands[88]
	node_0.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "FactoryGenerated_0029_MeshInstance3D"
	node_40.transform = operands[89]
	node_40.material_override = material_0
	node_40.mesh = operands[90]
	node_0.add_child(node_40)
	var node_41 := MeshInstance3D.new()
	node_41.name = "FactoryGenerated_0030_MeshInstance3D"
	node_41.transform = operands[91]
	node_41.material_override = material_0
	node_41.mesh = operands[92]
	node_0.add_child(node_41)
	var node_42 := MeshInstance3D.new()
	node_42.name = "FactoryGenerated_0031_MeshInstance3D"
	node_42.transform = operands[93]
	node_42.material_override = material_0
	node_42.mesh = operands[94]
	node_0.add_child(node_42)
	var node_43 := MeshInstance3D.new()
	node_43.name = "FactoryGenerated_0032_MeshInstance3D"
	node_43.transform = operands[95]
	node_43.material_override = material_0
	node_43.mesh = operands[96]
	node_0.add_child(node_43)
	var node_44 := MeshInstance3D.new()
	node_44.name = "FactoryGenerated_0033_MeshInstance3D"
	node_44.transform = operands[97]
	node_44.material_override = material_0
	node_44.mesh = operands[98]
	node_0.add_child(node_44)
	var node_45 := MeshInstance3D.new()
	node_45.name = "FactoryGenerated_0034_MeshInstance3D"
	node_45.transform = operands[99]
	node_45.material_override = material_0
	node_45.mesh = operands[100]
	node_0.add_child(node_45)
	var node_46 := MeshInstance3D.new()
	node_46.name = "FactoryGenerated_0035_MeshInstance3D"
	node_46.transform = operands[101]
	node_46.material_override = material_0
	node_46.mesh = operands[102]
	node_0.add_child(node_46)
	var node_47 := MeshInstance3D.new()
	node_47.name = "FactoryGenerated_0036_MeshInstance3D"
	node_47.transform = operands[103]
	node_47.material_override = material_0
	node_47.mesh = operands[104]
	node_0.add_child(node_47)
	var node_48 := MeshInstance3D.new()
	node_48.name = "FactoryGenerated_0037_MeshInstance3D"
	node_48.transform = operands[105]
	node_48.material_override = material_0
	node_48.mesh = operands[106]
	node_0.add_child(node_48)
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
	node_15.owner = node_0
	node_16.owner = node_0
	node_17.owner = node_0
	node_18.owner = node_0
	node_19.owner = node_0
	node_20.owner = node_0
	node_21.owner = node_0
	node_22.owner = node_0
	node_23.owner = node_0
	node_24.owner = node_0
	node_25.owner = node_0
	node_26.owner = node_0
	node_27.owner = node_0
	node_28.owner = node_0
	node_29.owner = node_0
	node_30.owner = node_0
	node_31.owner = node_0
	node_32.owner = node_0
	node_33.owner = node_0
	node_34.owner = node_0
	node_35.owner = node_0
	node_36.owner = node_0
	node_37.owner = node_0
	node_38.owner = node_0
	node_39.owner = node_0
	node_40.owner = node_0
	node_41.owner = node_0
	node_42.owner = node_0
	node_43.owner = node_0
	node_44.owner = node_0
	node_45.owner = node_0
	node_46.owner = node_0
	node_47.owner = node_0
	node_48.owner = node_0
	node_0.scene_file_path = operands[107]
	return {"material_sites_bound": true, "nodes": [node_0, node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_41, node_42, node_43, node_44, node_45, node_46, node_47, node_48], "private_materials": [material_0], "root": node_0, "geometry": [node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_41, node_42, node_43, node_44, node_45, node_46, node_47, node_48], "materials": [], "cohorts": []}
