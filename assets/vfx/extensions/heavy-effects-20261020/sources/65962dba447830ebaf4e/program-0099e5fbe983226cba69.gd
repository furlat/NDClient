extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.render_priority = -2
	material_0.set_shader_parameter("factory_occurrence_alpha", operands[1])
	material_0.set_shader_parameter("clock", operands[2])
	material_0.set_shader_parameter("ghost", operands[3])
	material_0.set_shader_parameter("lightness", operands[4])
	material_0.set_shader_parameter("feast_role_tint", operands[5])
	material_0.set_shader_parameter("feast_value_gain", operands[6])
	material_0.set_shader_parameter("feast_world_to_source", operands[7])
	material_0.set_shader_parameter("feast_birth_seconds", operands[8])
	material_0.set_shader_parameter("feast_half_extent_cells", operands[9])
	material_0.set_meta("factory_occurrence_alpha", operands[10])
	material_0.set_meta("factory_prepared_shader", operands[11])
	material_0.set_meta("factory_opacity_prepared_shader", operands[12])
	material_0.set_meta("factory_world_space_uniform", operands[13])
	material_0.set_meta("factory_recorded_source_space_frozen", operands[14])
	material_0.set_meta("factory_clock_names", operands[15])
	material_0.set_meta("factory_clock_pool_required", operands[16])
	var material_1 := ShaderMaterial.new()
	material_1.shader = operands[17]
	material_1.render_priority = -1
	material_1.set_shader_parameter("factory_occurrence_alpha", operands[18])
	material_1.set_shader_parameter("clock", operands[19])
	material_1.set_shader_parameter("ghost", operands[20])
	material_1.set_shader_parameter("lightness", operands[21])
	material_1.set_shader_parameter("feast_role_tint", operands[22])
	material_1.set_shader_parameter("feast_value_gain", operands[23])
	material_1.set_shader_parameter("feast_world_to_source", operands[24])
	material_1.set_shader_parameter("feast_birth_seconds", operands[25])
	material_1.set_shader_parameter("feast_half_extent_cells", operands[26])
	material_1.set_meta("factory_occurrence_alpha", operands[27])
	material_1.set_meta("factory_prepared_shader", operands[28])
	material_1.set_meta("factory_opacity_prepared_shader", operands[29])
	material_1.set_meta("factory_world_space_uniform", operands[30])
	material_1.set_meta("factory_recorded_source_space_frozen", operands[31])
	material_1.set_meta("factory_clock_names", operands[32])
	material_1.set_meta("factory_clock_pool_required", operands[33])
	var material_2 := ShaderMaterial.new()
	material_2.shader = operands[34]
	material_2.render_priority = -3
	material_2.set_shader_parameter("factory_occurrence_alpha", operands[35])
	material_2.set_shader_parameter("clock", operands[36])
	material_2.set_shader_parameter("ghost", operands[37])
	material_2.set_shader_parameter("lightness", operands[38])
	material_2.set_shader_parameter("feast_role_tint", operands[39])
	material_2.set_shader_parameter("feast_value_gain", operands[40])
	material_2.set_shader_parameter("feast_world_to_source", operands[41])
	material_2.set_shader_parameter("feast_birth_seconds", operands[42])
	material_2.set_shader_parameter("feast_half_extent_cells", operands[43])
	material_2.set_meta("factory_occurrence_alpha", operands[44])
	material_2.set_meta("factory_prepared_shader", operands[45])
	material_2.set_meta("factory_opacity_prepared_shader", operands[46])
	material_2.set_meta("factory_world_space_uniform", operands[47])
	material_2.set_meta("factory_recorded_source_space_frozen", operands[48])
	material_2.set_meta("factory_clock_names", operands[49])
	material_2.set_meta("factory_clock_pool_required", operands[50])
	var material_3 := ShaderMaterial.new()
	material_3.shader = operands[51]
	material_3.set_shader_parameter("factory_occurrence_alpha", operands[52])
	material_3.set_shader_parameter("clock", operands[53])
	material_3.set_shader_parameter("ghost", operands[54])
	material_3.set_shader_parameter("lightness", operands[55])
	material_3.set_shader_parameter("feast_role_tint", operands[56])
	material_3.set_shader_parameter("feast_value_gain", operands[57])
	material_3.set_shader_parameter("feast_world_to_source", operands[58])
	material_3.set_shader_parameter("feast_birth_seconds", operands[59])
	material_3.set_shader_parameter("feast_half_extent_cells", operands[60])
	material_3.set_meta("factory_occurrence_alpha", operands[61])
	material_3.set_meta("factory_prepared_shader", operands[62])
	material_3.set_meta("factory_opacity_prepared_shader", operands[63])
	material_3.set_meta("factory_world_space_uniform", operands[64])
	material_3.set_meta("factory_recorded_source_space_frozen", operands[65])
	material_3.set_meta("factory_clock_names", operands[66])
	material_3.set_meta("factory_clock_pool_required", operands[67])
	var material_4 := ShaderMaterial.new()
	material_4.shader = operands[68]
	material_4.set_shader_parameter("factory_occurrence_alpha", operands[69])
	material_4.set_shader_parameter("clock", operands[70])
	material_4.set_shader_parameter("ghost", operands[71])
	material_4.set_shader_parameter("lightness", operands[72])
	material_4.set_shader_parameter("feast_role_tint", operands[73])
	material_4.set_shader_parameter("feast_value_gain", operands[74])
	material_4.set_shader_parameter("feast_world_to_source", operands[75])
	material_4.set_shader_parameter("feast_birth_seconds", operands[76])
	material_4.set_shader_parameter("feast_half_extent_cells", operands[77])
	material_4.set_meta("factory_occurrence_alpha", operands[78])
	material_4.set_meta("factory_prepared_shader", operands[79])
	material_4.set_meta("factory_opacity_prepared_shader", operands[80])
	material_4.set_meta("factory_world_space_uniform", operands[81])
	material_4.set_meta("factory_recorded_source_space_frozen", operands[82])
	material_4.set_meta("factory_clock_names", operands[83])
	material_4.set_meta("factory_clock_pool_required", operands[84])
	var material_5 := ShaderMaterial.new()
	material_5.shader = operands[85]
	material_5.set_shader_parameter("factory_occurrence_alpha", operands[86])
	material_5.set_shader_parameter("clock", operands[87])
	material_5.set_shader_parameter("ghost", operands[88])
	material_5.set_shader_parameter("lightness", operands[89])
	material_5.set_shader_parameter("feast_role_tint", operands[90])
	material_5.set_shader_parameter("feast_value_gain", operands[91])
	material_5.set_shader_parameter("feast_world_to_source", operands[92])
	material_5.set_shader_parameter("feast_birth_seconds", operands[93])
	material_5.set_shader_parameter("feast_half_extent_cells", operands[94])
	material_5.set_meta("factory_occurrence_alpha", operands[95])
	material_5.set_meta("factory_prepared_shader", operands[96])
	material_5.set_meta("factory_opacity_prepared_shader", operands[97])
	material_5.set_meta("factory_world_space_uniform", operands[98])
	material_5.set_meta("factory_recorded_source_space_frozen", operands[99])
	material_5.set_meta("factory_clock_names", operands[100])
	material_5.set_meta("factory_clock_pool_required", operands[101])
	var material_6 := ShaderMaterial.new()
	material_6.shader = operands[102]
	material_6.set_shader_parameter("factory_occurrence_alpha", operands[103])
	material_6.set_shader_parameter("clock", operands[104])
	material_6.set_shader_parameter("ghost", operands[105])
	material_6.set_shader_parameter("lightness", operands[106])
	material_6.set_shader_parameter("feast_role_tint", operands[107])
	material_6.set_shader_parameter("feast_value_gain", operands[108])
	material_6.set_shader_parameter("feast_world_to_source", operands[109])
	material_6.set_shader_parameter("feast_birth_seconds", operands[110])
	material_6.set_shader_parameter("feast_half_extent_cells", operands[111])
	material_6.set_meta("factory_occurrence_alpha", operands[112])
	material_6.set_meta("factory_prepared_shader", operands[113])
	material_6.set_meta("factory_opacity_prepared_shader", operands[114])
	material_6.set_meta("factory_world_space_uniform", operands[115])
	material_6.set_meta("factory_recorded_source_space_frozen", operands[116])
	material_6.set_meta("factory_clock_names", operands[117])
	material_6.set_meta("factory_clock_pool_required", operands[118])
	var material_7 := ShaderMaterial.new()
	material_7.shader = operands[119]
	material_7.set_shader_parameter("factory_occurrence_alpha", operands[120])
	material_7.set_shader_parameter("clock", operands[121])
	material_7.set_shader_parameter("ghost", operands[122])
	material_7.set_shader_parameter("lightness", operands[123])
	material_7.set_shader_parameter("feast_role_tint", operands[124])
	material_7.set_shader_parameter("feast_value_gain", operands[125])
	material_7.set_shader_parameter("feast_world_to_source", operands[126])
	material_7.set_shader_parameter("feast_birth_seconds", operands[127])
	material_7.set_shader_parameter("feast_half_extent_cells", operands[128])
	material_7.set_meta("factory_occurrence_alpha", operands[129])
	material_7.set_meta("factory_prepared_shader", operands[130])
	material_7.set_meta("factory_opacity_prepared_shader", operands[131])
	material_7.set_meta("factory_world_space_uniform", operands[132])
	material_7.set_meta("factory_recorded_source_space_frozen", operands[133])
	material_7.set_meta("factory_clock_names", operands[134])
	material_7.set_meta("factory_clock_pool_required", operands[135])
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "Recorded"
	node_0.set("metadata/factory_native_gpu_emitters", operands[136])
	var node_1 := Node3D.new()
	node_1.name = "assembly"
	node_0.add_child(node_1)
	var node_2 := Node3D.new()
	node_2.name = "feast"
	node_1.add_child(node_2)
	var node_3 := Node3D.new()
	node_3.name = "feast"
	node_2.add_child(node_3)
	var node_4 := Node3D.new()
	node_4.name = "feast"
	node_4.transform = operands[137]
	node_3.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "Scalloped serving stone"
	node_5.transform = operands[138]
	node_5.layers = operands[139]
	node_5.mesh = operands[140]
	node_5.set("surface_material_override/0", material_0)
	node_4.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "Scalloped serving stone_001"
	node_6.transform = operands[141]
	node_6.layers = operands[142]
	node_6.mesh = operands[143]
	node_6.set("surface_material_override/0", material_0)
	node_4.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "Silver rolled edge"
	node_7.layers = operands[144]
	node_7.mesh = operands[145]
	node_7.set("surface_material_override/0", material_1)
	node_4.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "Silver rolled edge_001"
	node_8.layers = operands[146]
	node_8.mesh = operands[147]
	node_8.set("surface_material_override/0", material_1)
	node_4.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "Rim inlay"
	node_9.layers = operands[148]
	node_9.mesh = operands[149]
	node_9.set("surface_material_override/0", material_1)
	node_4.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "Rim inlay_001"
	node_10.layers = operands[150]
	node_10.mesh = operands[151]
	node_10.set("surface_material_override/0", material_1)
	node_4.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "Rim inlay_002"
	node_11.layers = operands[152]
	node_11.mesh = operands[153]
	node_11.set("surface_material_override/0", material_1)
	node_4.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "Rim inlay_003"
	node_12.layers = operands[154]
	node_12.mesh = operands[155]
	node_12.set("surface_material_override/0", material_1)
	node_4.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "Rim inlay_004"
	node_13.layers = operands[156]
	node_13.mesh = operands[157]
	node_13.set("surface_material_override/0", material_1)
	node_4.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "Rim inlay_005"
	node_14.layers = operands[158]
	node_14.mesh = operands[159]
	node_14.set("surface_material_override/0", material_1)
	node_4.add_child(node_14)
	var node_15 := MeshInstance3D.new()
	node_15.name = "Rim inlay_006"
	node_15.layers = operands[160]
	node_15.mesh = operands[161]
	node_15.set("surface_material_override/0", material_1)
	node_4.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "Rim inlay_007"
	node_16.layers = operands[162]
	node_16.mesh = operands[163]
	node_16.set("surface_material_override/0", material_1)
	node_4.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "Rim inlay_008"
	node_17.layers = operands[164]
	node_17.mesh = operands[165]
	node_17.set("surface_material_override/0", material_1)
	node_4.add_child(node_17)
	var node_18 := MeshInstance3D.new()
	node_18.name = "Rim inlay_009"
	node_18.layers = operands[166]
	node_18.mesh = operands[167]
	node_18.set("surface_material_override/0", material_1)
	node_4.add_child(node_18)
	var node_19 := MeshInstance3D.new()
	node_19.name = "Rim inlay_010"
	node_19.layers = operands[168]
	node_19.mesh = operands[169]
	node_19.set("surface_material_override/0", material_1)
	node_4.add_child(node_19)
	var node_20 := MeshInstance3D.new()
	node_20.name = "Rim inlay_011"
	node_20.layers = operands[170]
	node_20.mesh = operands[171]
	node_20.set("surface_material_override/0", material_1)
	node_4.add_child(node_20)
	var node_21 := MeshInstance3D.new()
	node_21.name = "Rim inlay_012"
	node_21.layers = operands[172]
	node_21.mesh = operands[173]
	node_21.set("surface_material_override/0", material_1)
	node_4.add_child(node_21)
	var node_22 := MeshInstance3D.new()
	node_22.name = "Rim inlay_013"
	node_22.layers = operands[174]
	node_22.mesh = operands[175]
	node_22.set("surface_material_override/0", material_1)
	node_4.add_child(node_22)
	var node_23 := MeshInstance3D.new()
	node_23.name = "Rim inlay_014"
	node_23.layers = operands[176]
	node_23.mesh = operands[177]
	node_23.set("surface_material_override/0", material_1)
	node_4.add_child(node_23)
	var node_24 := MeshInstance3D.new()
	node_24.name = "Rim inlay_015"
	node_24.layers = operands[178]
	node_24.mesh = operands[179]
	node_24.set("surface_material_override/0", material_1)
	node_4.add_child(node_24)
	var node_25 := MeshInstance3D.new()
	node_25.name = "Rim inlay_016"
	node_25.layers = operands[180]
	node_25.mesh = operands[181]
	node_25.set("surface_material_override/0", material_1)
	node_4.add_child(node_25)
	var node_26 := MeshInstance3D.new()
	node_26.name = "Rim inlay_017"
	node_26.layers = operands[182]
	node_26.mesh = operands[183]
	node_26.set("surface_material_override/0", material_1)
	node_4.add_child(node_26)
	var node_27 := MeshInstance3D.new()
	node_27.name = "Rim inlay_018"
	node_27.layers = operands[184]
	node_27.mesh = operands[185]
	node_27.set("surface_material_override/0", material_1)
	node_4.add_child(node_27)
	var node_28 := MeshInstance3D.new()
	node_28.name = "Rim inlay_019"
	node_28.layers = operands[186]
	node_28.mesh = operands[187]
	node_28.set("surface_material_override/0", material_1)
	node_4.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "Rim inlay_020"
	node_29.layers = operands[188]
	node_29.mesh = operands[189]
	node_29.set("surface_material_override/0", material_1)
	node_4.add_child(node_29)
	var node_30 := MeshInstance3D.new()
	node_30.name = "Rim inlay_021"
	node_30.layers = operands[190]
	node_30.mesh = operands[191]
	node_30.set("surface_material_override/0", material_1)
	node_4.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "Rim inlay_022"
	node_31.layers = operands[192]
	node_31.mesh = operands[193]
	node_31.set("surface_material_override/0", material_1)
	node_4.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "Rim inlay_023"
	node_32.layers = operands[194]
	node_32.mesh = operands[195]
	node_32.set("surface_material_override/0", material_1)
	node_4.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "Rim inlay_024"
	node_33.layers = operands[196]
	node_33.mesh = operands[197]
	node_33.set("surface_material_override/0", material_1)
	node_4.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "Rim inlay_025"
	node_34.layers = operands[198]
	node_34.mesh = operands[199]
	node_34.set("surface_material_override/0", material_1)
	node_4.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "Rim inlay_026"
	node_35.layers = operands[200]
	node_35.mesh = operands[201]
	node_35.set("surface_material_override/0", material_1)
	node_4.add_child(node_35)
	var node_36 := MeshInstance3D.new()
	node_36.name = "Rim inlay_027"
	node_36.layers = operands[202]
	node_36.mesh = operands[203]
	node_36.set("surface_material_override/0", material_1)
	node_4.add_child(node_36)
	var node_37 := MeshInstance3D.new()
	node_37.name = "Rim inlay_028"
	node_37.layers = operands[204]
	node_37.mesh = operands[205]
	node_37.set("surface_material_override/0", material_1)
	node_4.add_child(node_37)
	var node_38 := MeshInstance3D.new()
	node_38.name = "Rim inlay_029"
	node_38.layers = operands[206]
	node_38.mesh = operands[207]
	node_38.set("surface_material_override/0", material_1)
	node_4.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "Rim inlay_030"
	node_39.layers = operands[208]
	node_39.mesh = operands[209]
	node_39.set("surface_material_override/0", material_1)
	node_4.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "Rim inlay_031"
	node_40.layers = operands[210]
	node_40.mesh = operands[211]
	node_40.set("surface_material_override/0", material_1)
	node_4.add_child(node_40)
	var node_41 := MeshInstance3D.new()
	node_41.name = "Spectral drapery"
	node_41.layers = operands[212]
	node_41.mesh = operands[213]
	node_41.set("surface_material_override/0", material_2)
	node_4.add_child(node_41)
	var node_42 := MeshInstance3D.new()
	node_42.name = "Carved crescent support"
	node_42.layers = operands[214]
	node_42.mesh = operands[215]
	node_42.set("surface_material_override/0", material_0)
	node_4.add_child(node_42)
	var node_43 := MeshInstance3D.new()
	node_43.name = "Suspended pearl"
	node_43.transform = operands[216]
	node_43.layers = operands[217]
	node_43.mesh = operands[218]
	node_43.set("surface_material_override/0", material_1)
	node_4.add_child(node_43)
	var node_44 := MeshInstance3D.new()
	node_44.name = "Carved crescent support_001"
	node_44.layers = operands[219]
	node_44.mesh = operands[220]
	node_44.set("surface_material_override/0", material_0)
	node_4.add_child(node_44)
	var node_45 := MeshInstance3D.new()
	node_45.name = "Suspended pearl_001"
	node_45.transform = operands[221]
	node_45.layers = operands[222]
	node_45.mesh = operands[223]
	node_45.set("surface_material_override/0", material_1)
	node_4.add_child(node_45)
	var node_46 := MeshInstance3D.new()
	node_46.name = "Porcelain plate"
	node_46.transform = operands[224]
	node_46.layers = operands[225]
	node_46.mesh = operands[226]
	node_46.set("surface_material_override/0", material_1)
	node_4.add_child(node_46)
	var node_47 := MeshInstance3D.new()
	node_47.name = "Plate engraved rim"
	node_47.transform = operands[227]
	node_47.layers = operands[228]
	node_47.mesh = operands[229]
	node_47.set("surface_material_override/0", material_0)
	node_4.add_child(node_47)
	var node_48 := MeshInstance3D.new()
	node_48.name = "Golden bread roll"
	node_48.transform = operands[230]
	node_48.layers = operands[231]
	node_48.mesh = operands[232]
	node_48.set("surface_material_override/0", material_3)
	node_4.add_child(node_48)
	var node_49 := MeshInstance3D.new()
	node_49.name = "Roll score"
	node_49.layers = operands[233]
	node_49.mesh = operands[234]
	node_49.set("surface_material_override/0", material_1)
	node_4.add_child(node_49)
	var node_50 := MeshInstance3D.new()
	node_50.name = "Roll score_001"
	node_50.layers = operands[235]
	node_50.mesh = operands[236]
	node_50.set("surface_material_override/0", material_1)
	node_4.add_child(node_50)
	var node_51 := MeshInstance3D.new()
	node_51.name = "Roll score_002"
	node_51.layers = operands[237]
	node_51.mesh = operands[238]
	node_51.set("surface_material_override/0", material_1)
	node_4.add_child(node_51)
	var node_52 := MeshInstance3D.new()
	node_52.name = "Porcelain plate_001"
	node_52.transform = operands[239]
	node_52.layers = operands[240]
	node_52.mesh = operands[241]
	node_52.set("surface_material_override/0", material_1)
	node_4.add_child(node_52)
	var node_53 := MeshInstance3D.new()
	node_53.name = "Plate engraved rim_001"
	node_53.transform = operands[242]
	node_53.layers = operands[243]
	node_53.mesh = operands[244]
	node_53.set("surface_material_override/0", material_0)
	node_4.add_child(node_53)
	var node_54 := MeshInstance3D.new()
	node_54.name = "Golden bread roll_001"
	node_54.transform = operands[245]
	node_54.layers = operands[246]
	node_54.mesh = operands[247]
	node_54.set("surface_material_override/0", material_3)
	node_4.add_child(node_54)
	var node_55 := MeshInstance3D.new()
	node_55.name = "Roll score_003"
	node_55.layers = operands[248]
	node_55.mesh = operands[249]
	node_55.set("surface_material_override/0", material_1)
	node_4.add_child(node_55)
	var node_56 := MeshInstance3D.new()
	node_56.name = "Roll score_004"
	node_56.layers = operands[250]
	node_56.mesh = operands[251]
	node_56.set("surface_material_override/0", material_1)
	node_4.add_child(node_56)
	var node_57 := MeshInstance3D.new()
	node_57.name = "Roll score_005"
	node_57.layers = operands[252]
	node_57.mesh = operands[253]
	node_57.set("surface_material_override/0", material_1)
	node_4.add_child(node_57)
	var node_58 := MeshInstance3D.new()
	node_58.name = "Porcelain plate_002"
	node_58.transform = operands[254]
	node_58.layers = operands[255]
	node_58.mesh = operands[256]
	node_58.set("surface_material_override/0", material_1)
	node_4.add_child(node_58)
	var node_59 := MeshInstance3D.new()
	node_59.name = "Plate engraved rim_002"
	node_59.transform = operands[257]
	node_59.layers = operands[258]
	node_59.mesh = operands[259]
	node_59.set("surface_material_override/0", material_0)
	node_4.add_child(node_59)
	var node_60 := MeshInstance3D.new()
	node_60.name = "Golden bread roll_002"
	node_60.transform = operands[260]
	node_60.layers = operands[261]
	node_60.mesh = operands[262]
	node_60.set("surface_material_override/0", material_3)
	node_4.add_child(node_60)
	var node_61 := MeshInstance3D.new()
	node_61.name = "Roll score_006"
	node_61.layers = operands[263]
	node_61.mesh = operands[264]
	node_61.set("surface_material_override/0", material_1)
	node_4.add_child(node_61)
	var node_62 := MeshInstance3D.new()
	node_62.name = "Roll score_007"
	node_62.layers = operands[265]
	node_62.mesh = operands[266]
	node_62.set("surface_material_override/0", material_1)
	node_4.add_child(node_62)
	var node_63 := MeshInstance3D.new()
	node_63.name = "Roll score_008"
	node_63.layers = operands[267]
	node_63.mesh = operands[268]
	node_63.set("surface_material_override/0", material_1)
	node_4.add_child(node_63)
	var node_64 := MeshInstance3D.new()
	node_64.name = "Porcelain plate_003"
	node_64.transform = operands[269]
	node_64.layers = operands[270]
	node_64.mesh = operands[271]
	node_64.set("surface_material_override/0", material_1)
	node_4.add_child(node_64)
	var node_65 := MeshInstance3D.new()
	node_65.name = "Plate engraved rim_003"
	node_65.transform = operands[272]
	node_65.layers = operands[273]
	node_65.mesh = operands[274]
	node_65.set("surface_material_override/0", material_0)
	node_4.add_child(node_65)
	var node_66 := MeshInstance3D.new()
	node_66.name = "Golden bread roll_003"
	node_66.transform = operands[275]
	node_66.layers = operands[276]
	node_66.mesh = operands[277]
	node_66.set("surface_material_override/0", material_3)
	node_4.add_child(node_66)
	var node_67 := MeshInstance3D.new()
	node_67.name = "Roll score_009"
	node_67.layers = operands[278]
	node_67.mesh = operands[279]
	node_67.set("surface_material_override/0", material_1)
	node_4.add_child(node_67)
	var node_68 := MeshInstance3D.new()
	node_68.name = "Roll score_010"
	node_68.layers = operands[280]
	node_68.mesh = operands[281]
	node_68.set("surface_material_override/0", material_1)
	node_4.add_child(node_68)
	var node_69 := MeshInstance3D.new()
	node_69.name = "Roll score_011"
	node_69.layers = operands[282]
	node_69.mesh = operands[283]
	node_69.set("surface_material_override/0", material_1)
	node_4.add_child(node_69)
	var node_70 := MeshInstance3D.new()
	node_70.name = "Porcelain plate_004"
	node_70.transform = operands[284]
	node_70.layers = operands[285]
	node_70.mesh = operands[286]
	node_70.set("surface_material_override/0", material_1)
	node_4.add_child(node_70)
	var node_71 := MeshInstance3D.new()
	node_71.name = "Plate engraved rim_004"
	node_71.transform = operands[287]
	node_71.layers = operands[288]
	node_71.mesh = operands[289]
	node_71.set("surface_material_override/0", material_0)
	node_4.add_child(node_71)
	var node_72 := MeshInstance3D.new()
	node_72.name = "Golden bread roll_004"
	node_72.transform = operands[290]
	node_72.layers = operands[291]
	node_72.mesh = operands[292]
	node_72.set("surface_material_override/0", material_3)
	node_4.add_child(node_72)
	var node_73 := MeshInstance3D.new()
	node_73.name = "Roll score_012"
	node_73.layers = operands[293]
	node_73.mesh = operands[294]
	node_73.set("surface_material_override/0", material_1)
	node_4.add_child(node_73)
	var node_74 := MeshInstance3D.new()
	node_74.name = "Roll score_013"
	node_74.layers = operands[295]
	node_74.mesh = operands[296]
	node_74.set("surface_material_override/0", material_1)
	node_4.add_child(node_74)
	var node_75 := MeshInstance3D.new()
	node_75.name = "Roll score_014"
	node_75.layers = operands[297]
	node_75.mesh = operands[298]
	node_75.set("surface_material_override/0", material_1)
	node_4.add_child(node_75)
	var node_76 := MeshInstance3D.new()
	node_76.name = "Porcelain plate_005"
	node_76.transform = operands[299]
	node_76.layers = operands[300]
	node_76.mesh = operands[301]
	node_76.set("surface_material_override/0", material_1)
	node_4.add_child(node_76)
	var node_77 := MeshInstance3D.new()
	node_77.name = "Plate engraved rim_005"
	node_77.transform = operands[302]
	node_77.layers = operands[303]
	node_77.mesh = operands[304]
	node_77.set("surface_material_override/0", material_0)
	node_4.add_child(node_77)
	var node_78 := MeshInstance3D.new()
	node_78.name = "Golden bread roll_005"
	node_78.transform = operands[305]
	node_78.layers = operands[306]
	node_78.mesh = operands[307]
	node_78.set("surface_material_override/0", material_3)
	node_4.add_child(node_78)
	var node_79 := MeshInstance3D.new()
	node_79.name = "Roll score_015"
	node_79.layers = operands[308]
	node_79.mesh = operands[309]
	node_79.set("surface_material_override/0", material_1)
	node_4.add_child(node_79)
	var node_80 := MeshInstance3D.new()
	node_80.name = "Roll score_016"
	node_80.layers = operands[310]
	node_80.mesh = operands[311]
	node_80.set("surface_material_override/0", material_1)
	node_4.add_child(node_80)
	var node_81 := MeshInstance3D.new()
	node_81.name = "Roll score_017"
	node_81.layers = operands[312]
	node_81.mesh = operands[313]
	node_81.set("surface_material_override/0", material_1)
	node_4.add_child(node_81)
	var node_82 := MeshInstance3D.new()
	node_82.name = "Goblet foot"
	node_82.transform = operands[314]
	node_82.layers = operands[315]
	node_82.mesh = operands[316]
	node_82.set("surface_material_override/0", material_1)
	node_4.add_child(node_82)
	var node_83 := MeshInstance3D.new()
	node_83.name = "Goblet stem"
	node_83.transform = operands[317]
	node_83.layers = operands[318]
	node_83.mesh = operands[319]
	node_83.set("surface_material_override/0", material_0)
	node_4.add_child(node_83)
	var node_84 := MeshInstance3D.new()
	node_84.name = "Pearl chalice"
	node_84.layers = operands[320]
	node_84.mesh = operands[321]
	node_84.set("surface_material_override/0", material_1)
	node_4.add_child(node_84)
	var node_85 := MeshInstance3D.new()
	node_85.name = "Ruby nectar"
	node_85.transform = operands[322]
	node_85.layers = operands[323]
	node_85.mesh = operands[324]
	node_85.set("surface_material_override/0", material_4)
	node_4.add_child(node_85)
	var node_86 := MeshInstance3D.new()
	node_86.name = "Goblet foot_001"
	node_86.transform = operands[325]
	node_86.layers = operands[326]
	node_86.mesh = operands[327]
	node_86.set("surface_material_override/0", material_1)
	node_4.add_child(node_86)
	var node_87 := MeshInstance3D.new()
	node_87.name = "Goblet stem_001"
	node_87.transform = operands[328]
	node_87.layers = operands[329]
	node_87.mesh = operands[330]
	node_87.set("surface_material_override/0", material_0)
	node_4.add_child(node_87)
	var node_88 := MeshInstance3D.new()
	node_88.name = "Pearl chalice_001"
	node_88.layers = operands[331]
	node_88.mesh = operands[332]
	node_88.set("surface_material_override/0", material_1)
	node_4.add_child(node_88)
	var node_89 := MeshInstance3D.new()
	node_89.name = "Ruby nectar_001"
	node_89.transform = operands[333]
	node_89.layers = operands[334]
	node_89.mesh = operands[335]
	node_89.set("surface_material_override/0", material_4)
	node_4.add_child(node_89)
	var node_90 := MeshInstance3D.new()
	node_90.name = "Goblet foot_002"
	node_90.transform = operands[336]
	node_90.layers = operands[337]
	node_90.mesh = operands[338]
	node_90.set("surface_material_override/0", material_1)
	node_4.add_child(node_90)
	var node_91 := MeshInstance3D.new()
	node_91.name = "Goblet stem_002"
	node_91.transform = operands[339]
	node_91.layers = operands[340]
	node_91.mesh = operands[341]
	node_91.set("surface_material_override/0", material_0)
	node_4.add_child(node_91)
	var node_92 := MeshInstance3D.new()
	node_92.name = "Pearl chalice_002"
	node_92.layers = operands[342]
	node_92.mesh = operands[343]
	node_92.set("surface_material_override/0", material_1)
	node_4.add_child(node_92)
	var node_93 := MeshInstance3D.new()
	node_93.name = "Ruby nectar_002"
	node_93.transform = operands[344]
	node_93.layers = operands[345]
	node_93.mesh = operands[346]
	node_93.set("surface_material_override/0", material_4)
	node_4.add_child(node_93)
	var node_94 := MeshInstance3D.new()
	node_94.name = "Goblet foot_003"
	node_94.transform = operands[347]
	node_94.layers = operands[348]
	node_94.mesh = operands[349]
	node_94.set("surface_material_override/0", material_1)
	node_4.add_child(node_94)
	var node_95 := MeshInstance3D.new()
	node_95.name = "Goblet stem_003"
	node_95.transform = operands[350]
	node_95.layers = operands[351]
	node_95.mesh = operands[352]
	node_95.set("surface_material_override/0", material_0)
	node_4.add_child(node_95)
	var node_96 := MeshInstance3D.new()
	node_96.name = "Pearl chalice_003"
	node_96.layers = operands[353]
	node_96.mesh = operands[354]
	node_96.set("surface_material_override/0", material_1)
	node_4.add_child(node_96)
	var node_97 := MeshInstance3D.new()
	node_97.name = "Ruby nectar_003"
	node_97.transform = operands[355]
	node_97.layers = operands[356]
	node_97.mesh = operands[357]
	node_97.set("surface_material_override/0", material_4)
	node_4.add_child(node_97)
	var node_98 := MeshInstance3D.new()
	node_98.name = "Central platter"
	node_98.transform = operands[358]
	node_98.layers = operands[359]
	node_98.mesh = operands[360]
	node_98.set("surface_material_override/0", material_1)
	node_4.add_child(node_98)
	var node_99 := MeshInstance3D.new()
	node_99.name = "Roast"
	node_99.transform = operands[361]
	node_99.layers = operands[362]
	node_99.mesh = operands[363]
	node_99.set("surface_material_override/0", material_3)
	node_4.add_child(node_99)
	var node_100 := MeshInstance3D.new()
	node_100.name = "Roast drumstick"
	node_100.transform = operands[364]
	node_100.layers = operands[365]
	node_100.mesh = operands[366]
	node_100.set("surface_material_override/0", material_5)
	node_4.add_child(node_100)
	var node_101 := MeshInstance3D.new()
	node_101.name = "Drumstick bone"
	node_101.transform = operands[367]
	node_101.layers = operands[368]
	node_101.mesh = operands[369]
	node_101.set("surface_material_override/0", material_1)
	node_4.add_child(node_101)
	var node_102 := MeshInstance3D.new()
	node_102.name = "Roast drumstick_001"
	node_102.transform = operands[370]
	node_102.layers = operands[371]
	node_102.mesh = operands[372]
	node_102.set("surface_material_override/0", material_5)
	node_4.add_child(node_102)
	var node_103 := MeshInstance3D.new()
	node_103.name = "Drumstick bone_001"
	node_103.transform = operands[373]
	node_103.layers = operands[374]
	node_103.mesh = operands[375]
	node_103.set("surface_material_override/0", material_1)
	node_4.add_child(node_103)
	var node_104 := MeshInstance3D.new()
	node_104.name = "Herb leaf"
	node_104.transform = operands[376]
	node_104.layers = operands[377]
	node_104.mesh = operands[378]
	node_104.set("surface_material_override/0", material_6)
	node_4.add_child(node_104)
	var node_105 := MeshInstance3D.new()
	node_105.name = "Herb leaf_001"
	node_105.transform = operands[379]
	node_105.layers = operands[380]
	node_105.mesh = operands[381]
	node_105.set("surface_material_override/0", material_6)
	node_4.add_child(node_105)
	var node_106 := MeshInstance3D.new()
	node_106.name = "Herb leaf_002"
	node_106.transform = operands[382]
	node_106.layers = operands[383]
	node_106.mesh = operands[384]
	node_106.set("surface_material_override/0", material_6)
	node_4.add_child(node_106)
	var node_107 := MeshInstance3D.new()
	node_107.name = "Herb leaf_003"
	node_107.transform = operands[385]
	node_107.layers = operands[386]
	node_107.mesh = operands[387]
	node_107.set("surface_material_override/0", material_6)
	node_4.add_child(node_107)
	var node_108 := MeshInstance3D.new()
	node_108.name = "Herb leaf_004"
	node_108.transform = operands[388]
	node_108.layers = operands[389]
	node_108.mesh = operands[390]
	node_108.set("surface_material_override/0", material_6)
	node_4.add_child(node_108)
	var node_109 := MeshInstance3D.new()
	node_109.name = "Herb leaf_005"
	node_109.transform = operands[391]
	node_109.layers = operands[392]
	node_109.mesh = operands[393]
	node_109.set("surface_material_override/0", material_6)
	node_4.add_child(node_109)
	var node_110 := MeshInstance3D.new()
	node_110.name = "Herb leaf_006"
	node_110.transform = operands[394]
	node_110.layers = operands[395]
	node_110.mesh = operands[396]
	node_110.set("surface_material_override/0", material_6)
	node_4.add_child(node_110)
	var node_111 := MeshInstance3D.new()
	node_111.name = "Herb leaf_007"
	node_111.transform = operands[397]
	node_111.layers = operands[398]
	node_111.mesh = operands[399]
	node_111.set("surface_material_override/0", material_6)
	node_4.add_child(node_111)
	var node_112 := MeshInstance3D.new()
	node_112.name = "Herb leaf_008"
	node_112.transform = operands[400]
	node_112.layers = operands[401]
	node_112.mesh = operands[402]
	node_112.set("surface_material_override/0", material_6)
	node_4.add_child(node_112)
	var node_113 := MeshInstance3D.new()
	node_113.name = "Herb leaf_009"
	node_113.transform = operands[403]
	node_113.layers = operands[404]
	node_113.mesh = operands[405]
	node_113.set("surface_material_override/0", material_6)
	node_4.add_child(node_113)
	var node_114 := MeshInstance3D.new()
	node_114.name = "Herb leaf_010"
	node_114.transform = operands[406]
	node_114.layers = operands[407]
	node_114.mesh = operands[408]
	node_114.set("surface_material_override/0", material_6)
	node_4.add_child(node_114)
	var node_115 := MeshInstance3D.new()
	node_115.name = "Fruit dish"
	node_115.transform = operands[409]
	node_115.layers = operands[410]
	node_115.mesh = operands[411]
	node_115.set("surface_material_override/0", material_0)
	node_4.add_child(node_115)
	var node_116 := MeshInstance3D.new()
	node_116.name = "Ruby pear"
	node_116.transform = operands[412]
	node_116.layers = operands[413]
	node_116.mesh = operands[414]
	node_116.set("surface_material_override/0", material_3)
	node_4.add_child(node_116)
	var node_117 := MeshInstance3D.new()
	node_117.name = "Apricot"
	node_117.transform = operands[415]
	node_117.layers = operands[416]
	node_117.mesh = operands[417]
	node_117.set("surface_material_override/0", material_4)
	node_4.add_child(node_117)
	var node_118 := MeshInstance3D.new()
	node_118.name = "Apricot_001"
	node_118.transform = operands[418]
	node_118.layers = operands[419]
	node_118.mesh = operands[420]
	node_118.set("surface_material_override/0", material_3)
	node_4.add_child(node_118)
	var node_119 := MeshInstance3D.new()
	node_119.name = "Ruby pear_001"
	node_119.transform = operands[421]
	node_119.layers = operands[422]
	node_119.mesh = operands[423]
	node_119.set("surface_material_override/0", material_4)
	node_4.add_child(node_119)
	var node_120 := MeshInstance3D.new()
	node_120.name = "Apricot_002"
	node_120.transform = operands[424]
	node_120.layers = operands[425]
	node_120.mesh = operands[426]
	node_120.set("surface_material_override/0", material_3)
	node_4.add_child(node_120)
	var node_121 := MeshInstance3D.new()
	node_121.name = "Apricot_003"
	node_121.transform = operands[427]
	node_121.layers = operands[428]
	node_121.mesh = operands[429]
	node_121.set("surface_material_override/0", material_4)
	node_4.add_child(node_121)
	var node_122 := MeshInstance3D.new()
	node_122.name = "Ruby pear_002"
	node_122.transform = operands[430]
	node_122.layers = operands[431]
	node_122.mesh = operands[432]
	node_122.set("surface_material_override/0", material_3)
	node_4.add_child(node_122)
	var node_123 := MeshInstance3D.new()
	node_123.name = "Apricot_004"
	node_123.transform = operands[433]
	node_123.layers = operands[434]
	node_123.mesh = operands[435]
	node_123.set("surface_material_override/0", material_4)
	node_4.add_child(node_123)
	var node_124 := MeshInstance3D.new()
	node_124.name = "Fruit dish_001"
	node_124.transform = operands[436]
	node_124.layers = operands[437]
	node_124.mesh = operands[438]
	node_124.set("surface_material_override/0", material_0)
	node_4.add_child(node_124)
	var node_125 := MeshInstance3D.new()
	node_125.name = "Ruby pear_003"
	node_125.transform = operands[439]
	node_125.layers = operands[440]
	node_125.mesh = operands[441]
	node_125.set("surface_material_override/0", material_3)
	node_4.add_child(node_125)
	var node_126 := MeshInstance3D.new()
	node_126.name = "Apricot_005"
	node_126.transform = operands[442]
	node_126.layers = operands[443]
	node_126.mesh = operands[444]
	node_126.set("surface_material_override/0", material_4)
	node_4.add_child(node_126)
	var node_127 := MeshInstance3D.new()
	node_127.name = "Apricot_006"
	node_127.transform = operands[445]
	node_127.layers = operands[446]
	node_127.mesh = operands[447]
	node_127.set("surface_material_override/0", material_3)
	node_4.add_child(node_127)
	var node_128 := MeshInstance3D.new()
	node_128.name = "Ruby pear_004"
	node_128.transform = operands[448]
	node_128.layers = operands[449]
	node_128.mesh = operands[450]
	node_128.set("surface_material_override/0", material_4)
	node_4.add_child(node_128)
	var node_129 := MeshInstance3D.new()
	node_129.name = "Apricot_007"
	node_129.transform = operands[451]
	node_129.layers = operands[452]
	node_129.mesh = operands[453]
	node_129.set("surface_material_override/0", material_3)
	node_4.add_child(node_129)
	var node_130 := MeshInstance3D.new()
	node_130.name = "Apricot_008"
	node_130.transform = operands[454]
	node_130.layers = operands[455]
	node_130.mesh = operands[456]
	node_130.set("surface_material_override/0", material_4)
	node_4.add_child(node_130)
	var node_131 := MeshInstance3D.new()
	node_131.name = "Ruby pear_005"
	node_131.transform = operands[457]
	node_131.layers = operands[458]
	node_131.mesh = operands[459]
	node_131.set("surface_material_override/0", material_3)
	node_4.add_child(node_131)
	var node_132 := MeshInstance3D.new()
	node_132.name = "Apricot_009"
	node_132.transform = operands[460]
	node_132.layers = operands[461]
	node_132.mesh = operands[462]
	node_132.set("surface_material_override/0", material_4)
	node_4.add_child(node_132)
	var node_133 := MeshInstance3D.new()
	node_133.name = "Candle holder"
	node_133.transform = operands[463]
	node_133.layers = operands[464]
	node_133.mesh = operands[465]
	node_133.set("surface_material_override/0", material_0)
	node_4.add_child(node_133)
	var node_134 := MeshInstance3D.new()
	node_134.name = "Ivory taper"
	node_134.transform = operands[466]
	node_134.layers = operands[467]
	node_134.mesh = operands[468]
	node_134.set("surface_material_override/0", material_1)
	node_4.add_child(node_134)
	var node_135 := MeshInstance3D.new()
	node_135.name = "Flame"
	node_135.transform = operands[469]
	node_135.layers = operands[470]
	node_135.mesh = operands[471]
	node_135.set("surface_material_override/0", material_7)
	node_4.add_child(node_135)
	var node_136 := MeshInstance3D.new()
	node_136.name = "Candle holder_001"
	node_136.transform = operands[472]
	node_136.layers = operands[473]
	node_136.mesh = operands[474]
	node_136.set("surface_material_override/0", material_0)
	node_4.add_child(node_136)
	var node_137 := MeshInstance3D.new()
	node_137.name = "Ivory taper_001"
	node_137.transform = operands[475]
	node_137.layers = operands[476]
	node_137.mesh = operands[477]
	node_137.set("surface_material_override/0", material_1)
	node_4.add_child(node_137)
	var node_138 := MeshInstance3D.new()
	node_138.name = "Flame_001"
	node_138.transform = operands[478]
	node_138.layers = operands[479]
	node_138.mesh = operands[480]
	node_138.set("surface_material_override/0", material_7)
	node_4.add_child(node_138)
	var node_139 := MeshInstance3D.new()
	node_139.name = "FactoryGenerated_0134_MeshInstance3D"
	node_139.transform = operands[481]
	node_139.layers = operands[482]
	node_139.material_override = material_7
	node_139.mesh = operands[483]
	node_4.add_child(node_139)
	var node_140 := MeshInstance3D.new()
	node_140.name = "FactoryGenerated_0135_MeshInstance3D"
	node_140.transform = operands[484]
	node_140.layers = operands[485]
	node_140.material_override = material_7
	node_140.mesh = operands[486]
	node_4.add_child(node_140)
	var node_141 := MeshInstance3D.new()
	node_141.name = "FactoryGenerated_0136_MeshInstance3D"
	node_141.transform = operands[487]
	node_141.layers = operands[488]
	node_141.material_override = material_7
	node_141.mesh = operands[489]
	node_4.add_child(node_141)
	var node_142 := MeshInstance3D.new()
	node_142.name = "FactoryGenerated_0137_MeshInstance3D"
	node_142.transform = operands[490]
	node_142.layers = operands[491]
	node_142.material_override = material_7
	node_142.mesh = operands[492]
	node_4.add_child(node_142)
	var node_143 := MeshInstance3D.new()
	node_143.name = "FactoryGenerated_0138_MeshInstance3D"
	node_143.transform = operands[493]
	node_143.layers = operands[494]
	node_143.material_override = material_7
	node_143.mesh = operands[495]
	node_4.add_child(node_143)
	var node_144 := MeshInstance3D.new()
	node_144.name = "FactoryGenerated_0139_MeshInstance3D"
	node_144.transform = operands[496]
	node_144.layers = operands[497]
	node_144.material_override = material_7
	node_144.mesh = operands[498]
	node_4.add_child(node_144)
	var node_145 := MeshInstance3D.new()
	node_145.name = "FactoryGenerated_0140_MeshInstance3D"
	node_145.transform = operands[499]
	node_145.layers = operands[500]
	node_145.material_override = material_7
	node_145.mesh = operands[501]
	node_4.add_child(node_145)
	var node_146 := MeshInstance3D.new()
	node_146.name = "FactoryGenerated_0141_MeshInstance3D"
	node_146.transform = operands[502]
	node_146.layers = operands[503]
	node_146.material_override = material_7
	node_146.mesh = operands[504]
	node_4.add_child(node_146)
	var node_147 := MeshInstance3D.new()
	node_147.name = "FactoryGenerated_0142_MeshInstance3D"
	node_147.transform = operands[505]
	node_147.layers = operands[506]
	node_147.material_override = material_7
	node_147.mesh = operands[507]
	node_4.add_child(node_147)
	var node_148 := MeshInstance3D.new()
	node_148.name = "FactoryGenerated_0143_MeshInstance3D"
	node_148.transform = operands[508]
	node_148.layers = operands[509]
	node_148.material_override = material_7
	node_148.mesh = operands[510]
	node_4.add_child(node_148)
	var node_149 := MeshInstance3D.new()
	node_149.name = "FactoryGenerated_0144_MeshInstance3D"
	node_149.transform = operands[511]
	node_149.layers = operands[512]
	node_149.material_override = material_7
	node_149.mesh = operands[513]
	node_4.add_child(node_149)
	var node_150 := MeshInstance3D.new()
	node_150.name = "FactoryGenerated_0145_MeshInstance3D"
	node_150.transform = operands[514]
	node_150.layers = operands[515]
	node_150.material_override = material_7
	node_150.mesh = operands[516]
	node_4.add_child(node_150)
	var node_151 := MeshInstance3D.new()
	node_151.name = "FactoryGenerated_0146_MeshInstance3D"
	node_151.transform = operands[517]
	node_151.layers = operands[518]
	node_151.material_override = material_7
	node_151.mesh = operands[519]
	node_4.add_child(node_151)
	var node_152 := MeshInstance3D.new()
	node_152.name = "FactoryGenerated_0147_MeshInstance3D"
	node_152.transform = operands[520]
	node_152.layers = operands[521]
	node_152.material_override = material_7
	node_152.mesh = operands[522]
	node_4.add_child(node_152)
	var node_153 := MeshInstance3D.new()
	node_153.name = "FactoryGenerated_0148_MeshInstance3D"
	node_153.transform = operands[523]
	node_153.layers = operands[524]
	node_153.material_override = material_7
	node_153.mesh = operands[525]
	node_4.add_child(node_153)
	var node_154 := MeshInstance3D.new()
	node_154.name = "FactoryGenerated_0149_MeshInstance3D"
	node_154.transform = operands[526]
	node_154.layers = operands[527]
	node_154.material_override = material_7
	node_154.mesh = operands[528]
	node_4.add_child(node_154)
	var node_155 := MeshInstance3D.new()
	node_155.name = "FactoryGenerated_0150_MeshInstance3D"
	node_155.transform = operands[529]
	node_155.layers = operands[530]
	node_155.material_override = material_7
	node_155.mesh = operands[531]
	node_4.add_child(node_155)
	var node_156 := MeshInstance3D.new()
	node_156.name = "FactoryGenerated_0151_MeshInstance3D"
	node_156.transform = operands[532]
	node_156.layers = operands[533]
	node_156.material_override = material_7
	node_156.mesh = operands[534]
	node_4.add_child(node_156)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"root": node_0, "geometry": [node_5, node_6, node_42, node_44, node_47, node_53, node_59, node_65, node_71, node_77, node_83, node_87, node_91, node_95, node_115, node_124, node_133, node_136, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_43, node_45, node_46, node_49, node_50, node_51, node_52, node_55, node_56, node_57, node_58, node_61, node_62, node_63, node_64, node_67, node_68, node_69, node_70, node_73, node_74, node_75, node_76, node_79, node_80, node_81, node_82, node_84, node_86, node_88, node_90, node_92, node_94, node_96, node_98, node_101, node_103, node_134, node_137, node_41, node_48, node_54, node_60, node_66, node_72, node_78, node_99, node_116, node_118, node_120, node_122, node_125, node_127, node_129, node_131, node_85, node_89, node_93, node_97, node_117, node_119, node_121, node_123, node_126, node_128, node_130, node_132, node_100, node_102, node_104, node_105, node_106, node_107, node_108, node_109, node_110, node_111, node_112, node_113, node_114, node_135, node_138, node_139, node_140, node_141, node_142, node_143, node_144, node_145, node_146, node_147, node_148, node_149, node_150, node_151, node_152, node_153, node_154, node_155, node_156, node_2], "materials": [node_5.get_surface_override_material(0), node_7.get_surface_override_material(0), node_41.get_surface_override_material(0), node_48.get_surface_override_material(0), node_85.get_surface_override_material(0), node_100.get_surface_override_material(0), node_104.get_surface_override_material(0), node_135.get_surface_override_material(0)], "cohorts": []}
