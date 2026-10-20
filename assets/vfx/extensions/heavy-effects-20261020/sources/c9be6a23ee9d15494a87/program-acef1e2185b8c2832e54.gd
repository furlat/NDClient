extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("age", operands[1])
	material_0.set_shader_parameter("neutral_albedo_is_encoded", operands[2])
	material_0.set_shader_parameter("neutral_count", operands[3])
	material_0.set_shader_parameter("neutral_family", operands[4])
	material_0.set_shader_parameter("neutral_gain", operands[5])
	material_0.set_shader_parameter("neutral_levels", operands[6])
	material_0.set_shader_parameter("noise_tex", operands[7])
	material_0.set_shader_parameter("strength", operands[8])
	material_0.set_shader_parameter("vfx_package_clock_slot", operands[9])
	material_0.set_shader_parameter("vortex_tex", operands[10])
	material_0.set_meta("factory_clock_names", operands[11])
	material_0.set_meta("factory_clock_pool_required", operands[12])
	material_0.set_meta("factory_opacity_prepared_shader", operands[13])
	material_0.set_meta("factory_prepared_shader", operands[14])
	material_0.set_meta("factory_world_space_uniform", operands[15])
	material_0.set_meta("neutral_family_palette", operands[16])
	var material_1 := ShaderMaterial.new()
	material_1.shader = operands[17]
	material_1.set_shader_parameter("age", operands[18])
	material_1.set_shader_parameter("camera_ground", operands[19])
	material_1.set_shader_parameter("gpu_summon_age", operands[20])
	material_1.set_shader_parameter("gpu_summon_kind", operands[21])
	material_1.set_shader_parameter("neutral_albedo_is_encoded", operands[22])
	material_1.set_shader_parameter("neutral_count", operands[23])
	material_1.set_shader_parameter("neutral_family", operands[24])
	material_1.set_shader_parameter("neutral_gain", operands[25])
	material_1.set_shader_parameter("neutral_levels", operands[26])
	material_1.set_shader_parameter("noise_tex", operands[27])
	material_1.set_shader_parameter("seed", operands[28])
	material_1.set_shader_parameter("side", operands[29])
	material_1.set_shader_parameter("strength", operands[30])
	material_1.set_shader_parameter("vfx_package_clock_slot", operands[31])
	material_1.set_meta("factory_clock_names", operands[32])
	material_1.set_meta("factory_clock_pool_required", operands[33])
	material_1.set_meta("factory_opacity_prepared_shader", operands[34])
	material_1.set_meta("factory_prepared_shader", operands[35])
	material_1.set_meta("factory_world_space_uniform", operands[36])
	material_1.set_meta("neutral_family_palette", operands[37])
	var material_2 := ShaderMaterial.new()
	material_2.shader = operands[38]
	material_2.set_shader_parameter("age", operands[39])
	material_2.set_shader_parameter("camera_ground", operands[40])
	material_2.set_shader_parameter("gpu_summon_age", operands[41])
	material_2.set_shader_parameter("gpu_summon_kind", operands[42])
	material_2.set_shader_parameter("neutral_albedo_is_encoded", operands[43])
	material_2.set_shader_parameter("neutral_count", operands[44])
	material_2.set_shader_parameter("neutral_family", operands[45])
	material_2.set_shader_parameter("neutral_gain", operands[46])
	material_2.set_shader_parameter("neutral_levels", operands[47])
	material_2.set_shader_parameter("noise_tex", operands[48])
	material_2.set_shader_parameter("seed", operands[49])
	material_2.set_shader_parameter("side", operands[50])
	material_2.set_shader_parameter("strength", operands[51])
	material_2.set_shader_parameter("vfx_package_clock_slot", operands[52])
	material_2.set_meta("factory_clock_names", operands[53])
	material_2.set_meta("factory_clock_pool_required", operands[54])
	material_2.set_meta("factory_opacity_prepared_shader", operands[55])
	material_2.set_meta("factory_prepared_shader", operands[56])
	material_2.set_meta("factory_world_space_uniform", operands[57])
	material_2.set_meta("neutral_family_palette", operands[58])
	var material_3 := ShaderMaterial.new()
	material_3.shader = operands[59]
	material_3.set_shader_parameter("age", operands[60])
	material_3.set_shader_parameter("camera_ground", operands[61])
	material_3.set_shader_parameter("gpu_summon_age", operands[62])
	material_3.set_shader_parameter("gpu_summon_kind", operands[63])
	material_3.set_shader_parameter("neutral_albedo_is_encoded", operands[64])
	material_3.set_shader_parameter("neutral_count", operands[65])
	material_3.set_shader_parameter("neutral_family", operands[66])
	material_3.set_shader_parameter("neutral_gain", operands[67])
	material_3.set_shader_parameter("neutral_levels", operands[68])
	material_3.set_shader_parameter("noise_tex", operands[69])
	material_3.set_shader_parameter("seed", operands[70])
	material_3.set_shader_parameter("side", operands[71])
	material_3.set_shader_parameter("strength", operands[72])
	material_3.set_shader_parameter("vfx_package_clock_slot", operands[73])
	material_3.set_meta("factory_clock_names", operands[74])
	material_3.set_meta("factory_clock_pool_required", operands[75])
	material_3.set_meta("factory_opacity_prepared_shader", operands[76])
	material_3.set_meta("factory_prepared_shader", operands[77])
	material_3.set_meta("factory_world_space_uniform", operands[78])
	material_3.set_meta("neutral_family_palette", operands[79])
	var material_4 := ShaderMaterial.new()
	material_4.shader = operands[80]
	material_4.set_shader_parameter("camera_ground", operands[81])
	material_4.set_shader_parameter("neutral_albedo_is_encoded", operands[82])
	material_4.set_shader_parameter("neutral_count", operands[83])
	material_4.set_shader_parameter("neutral_family", operands[84])
	material_4.set_shader_parameter("neutral_gain", operands[85])
	material_4.set_shader_parameter("neutral_levels", operands[86])
	material_4.set_shader_parameter("side", operands[87])
	material_4.set_shader_parameter("strength", operands[88])
	material_4.set_meta("factory_clock_names", operands[89])
	material_4.set_meta("factory_clock_pool_required", operands[90])
	material_4.set_meta("factory_opacity_prepared_shader", operands[91])
	material_4.set_meta("factory_prepared_shader", operands[92])
	material_4.set_meta("factory_world_space_uniform", operands[93])
	material_4.set_meta("neutral_family_palette", operands[94])
	var material_5 := ShaderMaterial.new()
	material_5.shader = operands[95]
	material_5.set_shader_parameter("camera_ground", operands[96])
	material_5.set_shader_parameter("neutral_albedo_is_encoded", operands[97])
	material_5.set_shader_parameter("neutral_count", operands[98])
	material_5.set_shader_parameter("neutral_family", operands[99])
	material_5.set_shader_parameter("neutral_gain", operands[100])
	material_5.set_shader_parameter("neutral_levels", operands[101])
	material_5.set_shader_parameter("side", operands[102])
	material_5.set_shader_parameter("strength", operands[103])
	material_5.set_meta("factory_clock_names", operands[104])
	material_5.set_meta("factory_clock_pool_required", operands[105])
	material_5.set_meta("factory_opacity_prepared_shader", operands[106])
	material_5.set_meta("factory_prepared_shader", operands[107])
	material_5.set_meta("factory_world_space_uniform", operands[108])
	material_5.set_meta("neutral_family_palette", operands[109])
	var material_6 := ShaderMaterial.new()
	material_6.shader = operands[110]
	material_6.set_shader_parameter("camera_ground", operands[111])
	material_6.set_shader_parameter("neutral_albedo_is_encoded", operands[112])
	material_6.set_shader_parameter("neutral_count", operands[113])
	material_6.set_shader_parameter("neutral_family", operands[114])
	material_6.set_shader_parameter("neutral_gain", operands[115])
	material_6.set_shader_parameter("neutral_levels", operands[116])
	material_6.set_shader_parameter("side", operands[117])
	material_6.set_shader_parameter("strength", operands[118])
	material_6.set_meta("factory_clock_names", operands[119])
	material_6.set_meta("factory_clock_pool_required", operands[120])
	material_6.set_meta("factory_opacity_prepared_shader", operands[121])
	material_6.set_meta("factory_prepared_shader", operands[122])
	material_6.set_meta("factory_world_space_uniform", operands[123])
	material_6.set_meta("neutral_family_palette", operands[124])
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "Donor"
	node_0.transform = operands[125]
	var node_1 := MeshInstance3D.new()
	node_1.name = "Ground"
	node_1.transform = operands[126]
	node_1.material_override = material_0
	node_1.mesh = operands[127]
	node_0.add_child(node_1)
	var node_2 := MeshInstance3D.new()
	node_2.name = "Ribbon00"
	node_2.material_override = material_1
	node_2.custom_aabb = operands[128]
	node_2.mesh = operands[129]
	node_2.set("metadata/gpu_bound_age", operands[130])
	node_0.add_child(node_2)
	var node_3 := MeshInstance3D.new()
	node_3.name = "Ribbon01"
	node_3.material_override = material_2
	node_3.custom_aabb = operands[131]
	node_3.mesh = operands[132]
	node_3.set("metadata/gpu_bound_age", operands[133])
	node_0.add_child(node_3)
	var node_4 := MeshInstance3D.new()
	node_4.name = "Ribbon02"
	node_4.material_override = material_3
	node_4.custom_aabb = operands[134]
	node_4.mesh = operands[135]
	node_4.set("metadata/gpu_bound_age", operands[136])
	node_0.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "Ribbon03"
	node_5.material_override = material_1
	node_5.custom_aabb = operands[137]
	node_5.set("instance_shader_parameters/gpu_summon_index", operands[138])
	node_5.mesh = operands[139]
	node_5.set("metadata/gpu_bound_age", operands[140])
	node_0.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "Ribbon04"
	node_6.material_override = material_2
	node_6.custom_aabb = operands[141]
	node_6.set("instance_shader_parameters/gpu_summon_index", operands[142])
	node_6.mesh = operands[143]
	node_6.set("metadata/gpu_bound_age", operands[144])
	node_0.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "Ribbon05"
	node_7.material_override = material_3
	node_7.custom_aabb = operands[145]
	node_7.set("instance_shader_parameters/gpu_summon_index", operands[146])
	node_7.mesh = operands[147]
	node_7.set("metadata/gpu_bound_age", operands[148])
	node_0.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "Ribbon06"
	node_8.material_override = material_1
	node_8.custom_aabb = operands[149]
	node_8.set("instance_shader_parameters/gpu_summon_index", operands[150])
	node_8.mesh = operands[151]
	node_8.set("metadata/gpu_bound_age", operands[152])
	node_0.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "Ribbon07"
	node_9.material_override = material_2
	node_9.custom_aabb = operands[153]
	node_9.set("instance_shader_parameters/gpu_summon_index", operands[154])
	node_9.mesh = operands[155]
	node_9.set("metadata/gpu_bound_age", operands[156])
	node_0.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "Ribbon08"
	node_10.material_override = material_3
	node_10.custom_aabb = operands[157]
	node_10.set("instance_shader_parameters/gpu_summon_index", operands[158])
	node_10.mesh = operands[159]
	node_10.set("metadata/gpu_bound_age", operands[160])
	node_0.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "Ribbon09"
	node_11.material_override = material_1
	node_11.custom_aabb = operands[161]
	node_11.set("instance_shader_parameters/gpu_summon_index", operands[162])
	node_11.mesh = operands[163]
	node_11.set("metadata/gpu_bound_age", operands[164])
	node_0.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "Ribbon10"
	node_12.material_override = material_2
	node_12.custom_aabb = operands[165]
	node_12.set("instance_shader_parameters/gpu_summon_index", operands[166])
	node_12.mesh = operands[167]
	node_12.set("metadata/gpu_bound_age", operands[168])
	node_0.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "Ribbon11"
	node_13.material_override = material_3
	node_13.custom_aabb = operands[169]
	node_13.set("instance_shader_parameters/gpu_summon_index", operands[170])
	node_13.mesh = operands[171]
	node_13.set("metadata/gpu_bound_age", operands[172])
	node_0.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "SourceMote00"
	node_14.transform = operands[173]
	node_14.material_override = material_4
	node_14.mesh = operands[174]
	node_0.add_child(node_14)
	var node_15 := MeshInstance3D.new()
	node_15.name = "SourceMote01"
	node_15.transform = operands[175]
	node_15.material_override = material_5
	node_15.mesh = operands[176]
	node_0.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "SourceMote02"
	node_16.transform = operands[177]
	node_16.material_override = material_6
	node_16.mesh = operands[178]
	node_0.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "SourceMote03"
	node_17.transform = operands[179]
	node_17.material_override = material_4
	node_17.mesh = operands[180]
	node_0.add_child(node_17)
	var node_18 := MeshInstance3D.new()
	node_18.name = "SourceMote04"
	node_18.transform = operands[181]
	node_18.material_override = material_5
	node_18.mesh = operands[182]
	node_0.add_child(node_18)
	var node_19 := MeshInstance3D.new()
	node_19.name = "SourceMote05"
	node_19.transform = operands[183]
	node_19.material_override = material_6
	node_19.mesh = operands[184]
	node_0.add_child(node_19)
	var node_20 := MeshInstance3D.new()
	node_20.name = "SourceMote06"
	node_20.transform = operands[185]
	node_20.material_override = material_4
	node_20.mesh = operands[186]
	node_0.add_child(node_20)
	var node_21 := MeshInstance3D.new()
	node_21.name = "SourceMote07"
	node_21.transform = operands[187]
	node_21.material_override = material_5
	node_21.mesh = operands[188]
	node_0.add_child(node_21)
	var node_22 := MeshInstance3D.new()
	node_22.name = "SourceMote08"
	node_22.transform = operands[189]
	node_22.material_override = material_4
	node_22.mesh = operands[190]
	node_0.add_child(node_22)
	var node_23 := MeshInstance3D.new()
	node_23.name = "SourceMote09"
	node_23.transform = operands[191]
	node_23.material_override = material_5
	node_23.mesh = operands[192]
	node_0.add_child(node_23)
	var node_24 := MeshInstance3D.new()
	node_24.name = "SourceMote10"
	node_24.transform = operands[193]
	node_24.material_override = material_6
	node_24.mesh = operands[194]
	node_0.add_child(node_24)
	var node_25 := MeshInstance3D.new()
	node_25.name = "SourceMote11"
	node_25.transform = operands[195]
	node_25.material_override = material_4
	node_25.mesh = operands[196]
	node_0.add_child(node_25)
	var node_26 := MeshInstance3D.new()
	node_26.name = "SourceMote12"
	node_26.transform = operands[197]
	node_26.material_override = material_5
	node_26.mesh = operands[198]
	node_0.add_child(node_26)
	var node_27 := MeshInstance3D.new()
	node_27.name = "SourceMote13"
	node_27.transform = operands[199]
	node_27.material_override = material_6
	node_27.mesh = operands[200]
	node_0.add_child(node_27)
	var node_28 := MeshInstance3D.new()
	node_28.name = "SourceMote14"
	node_28.transform = operands[201]
	node_28.material_override = material_4
	node_28.mesh = operands[202]
	node_0.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "SourceMote15"
	node_29.transform = operands[203]
	node_29.material_override = material_5
	node_29.mesh = operands[204]
	node_0.add_child(node_29)
	var node_30 := MeshInstance3D.new()
	node_30.name = "SourceMote16"
	node_30.transform = operands[205]
	node_30.material_override = material_4
	node_30.mesh = operands[206]
	node_0.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "SourceMote17"
	node_31.transform = operands[207]
	node_31.material_override = material_5
	node_31.mesh = operands[208]
	node_0.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "SourceMote18"
	node_32.transform = operands[209]
	node_32.material_override = material_6
	node_32.mesh = operands[210]
	node_0.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "SourceMote19"
	node_33.transform = operands[211]
	node_33.material_override = material_4
	node_33.mesh = operands[212]
	node_0.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "SourceMote20"
	node_34.transform = operands[213]
	node_34.material_override = material_5
	node_34.mesh = operands[214]
	node_0.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "SourceMote21"
	node_35.transform = operands[215]
	node_35.material_override = material_6
	node_35.mesh = operands[216]
	node_0.add_child(node_35)
	var node_36 := MeshInstance3D.new()
	node_36.name = "SourceMote22"
	node_36.transform = operands[217]
	node_36.material_override = material_4
	node_36.mesh = operands[218]
	node_0.add_child(node_36)
	var node_37 := MeshInstance3D.new()
	node_37.name = "SourceMote23"
	node_37.transform = operands[219]
	node_37.material_override = material_5
	node_37.mesh = operands[220]
	node_0.add_child(node_37)
	var node_38 := MeshInstance3D.new()
	node_38.name = "SourceMote24"
	node_38.transform = operands[221]
	node_38.material_override = material_4
	node_38.mesh = operands[222]
	node_0.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "SourceMote25"
	node_39.transform = operands[223]
	node_39.material_override = material_5
	node_39.mesh = operands[224]
	node_0.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "SourceMote26"
	node_40.transform = operands[225]
	node_40.material_override = material_6
	node_40.mesh = operands[226]
	node_0.add_child(node_40)
	var node_41 := MeshInstance3D.new()
	node_41.name = "SourceMote27"
	node_41.transform = operands[227]
	node_41.material_override = material_4
	node_41.mesh = operands[228]
	node_0.add_child(node_41)
	var node_42 := MeshInstance3D.new()
	node_42.name = "SourceMote28"
	node_42.transform = operands[229]
	node_42.material_override = material_5
	node_42.mesh = operands[230]
	node_0.add_child(node_42)
	var node_43 := MeshInstance3D.new()
	node_43.name = "SourceMote29"
	node_43.transform = operands[231]
	node_43.material_override = material_6
	node_43.mesh = operands[232]
	node_0.add_child(node_43)
	var node_44 := MeshInstance3D.new()
	node_44.name = "SourceMote30"
	node_44.transform = operands[233]
	node_44.material_override = material_4
	node_44.mesh = operands[234]
	node_0.add_child(node_44)
	var node_45 := MeshInstance3D.new()
	node_45.name = "SourceMote31"
	node_45.transform = operands[235]
	node_45.material_override = material_5
	node_45.mesh = operands[236]
	node_0.add_child(node_45)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"root": node_0, "geometry": [node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_41, node_42, node_43, node_44, node_45], "materials": [node_1.material_override, node_2.material_override, node_3.material_override, node_4.material_override, node_5.material_override, node_6.material_override, node_7.material_override, node_8.material_override, node_9.material_override, node_10.material_override, node_11.material_override, node_12.material_override, node_13.material_override, node_14.material_override, node_15.material_override, node_16.material_override, node_17.material_override, node_18.material_override, node_19.material_override, node_20.material_override, node_21.material_override, node_22.material_override, node_23.material_override, node_24.material_override, node_25.material_override, node_26.material_override, node_27.material_override, node_28.material_override, node_29.material_override, node_30.material_override, node_31.material_override, node_32.material_override, node_33.material_override, node_34.material_override, node_35.material_override, node_36.material_override, node_37.material_override, node_38.material_override, node_39.material_override, node_40.material_override, node_41.material_override, node_42.material_override, node_43.material_override, node_44.material_override, node_45.material_override], "cohorts": []}
