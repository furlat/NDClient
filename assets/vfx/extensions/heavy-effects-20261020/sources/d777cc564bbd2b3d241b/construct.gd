extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("factory_world_to_source", operands[1])
	material_0.set_shader_parameter("factory_occurrence_alpha", operands[2])
	material_0.set_shader_parameter("fresnelpower", operands[3])
	material_0.set_shader_parameter("AddTexture", operands[4])
	material_0.set_shader_parameter("Texture_add2_offset", operands[5])
	material_0.set_shader_parameter("AddTexture2", operands[6])
	material_0.set_shader_parameter("DetailsTexture", operands[7])
	material_0.set_shader_parameter("Color1DGradient", operands[8])
	material_0.set_shader_parameter("ColorIntensity", operands[9])
	material_0.set_meta("factory_occurrence_alpha", operands[10])
	material_0.set_meta("factory_prepared_shader", operands[11])
	material_0.set_meta("factory_opacity_prepared_shader", operands[12])
	material_0.set_meta("factory_clock_names", operands[13])
	material_0.set_meta("factory_clock_pool_required", operands[14])
	material_0.set_meta("factory_world_space_uniform", operands[15])
	var material_1 := ShaderMaterial.new()
	material_1.shader = operands[16]
	material_1.set_shader_parameter("factory_world_to_source", operands[17])
	material_1.set_shader_parameter("factory_occurrence_alpha", operands[18])
	material_1.set_shader_parameter("noise_tex", operands[19])
	material_1.set_shader_parameter("impact_age", operands[20])
	material_1.set_shader_parameter("visible_hit", operands[21])
	material_1.set_meta("factory_occurrence_alpha", operands[22])
	material_1.set_meta("factory_prepared_shader", operands[23])
	material_1.set_meta("factory_opacity_prepared_shader", operands[24])
	material_1.set_meta("factory_clock_names", operands[25])
	material_1.set_meta("factory_clock_pool_required", operands[26])
	material_1.set_meta("factory_world_space_uniform", operands[27])
	var material_2 := ShaderMaterial.new()
	material_2.shader = operands[28]
	material_2.set_shader_parameter("factory_world_to_source", operands[29])
	material_2.set_shader_parameter("factory_occurrence_alpha", operands[30])
	material_2.set_shader_parameter("frost", operands[31])
	material_2.set_meta("factory_occurrence_alpha", operands[32])
	material_2.set_meta("factory_prepared_shader", operands[33])
	material_2.set_meta("factory_opacity_prepared_shader", operands[34])
	material_2.set_meta("factory_clock_names", operands[35])
	material_2.set_meta("factory_clock_pool_required", operands[36])
	material_2.set_meta("factory_world_space_uniform", operands[37])
	var material_3 := ShaderMaterial.new()
	material_3.shader = operands[38]
	material_3.set_shader_parameter("factory_world_to_source", operands[39])
	material_3.set_shader_parameter("factory_occurrence_alpha", operands[40])
	material_3.set_shader_parameter("fresnelpower", operands[41])
	material_3.set_shader_parameter("AddTexture", operands[42])
	material_3.set_shader_parameter("Texture_add2_offset", operands[43])
	material_3.set_shader_parameter("AddTexture2", operands[44])
	material_3.set_shader_parameter("DetailsTexture", operands[45])
	material_3.set_shader_parameter("Color1DGradient", operands[46])
	material_3.set_shader_parameter("ColorIntensity", operands[47])
	material_3.set_meta("factory_occurrence_alpha", operands[48])
	material_3.set_meta("factory_prepared_shader", operands[49])
	material_3.set_meta("factory_opacity_prepared_shader", operands[50])
	material_3.set_meta("factory_clock_names", operands[51])
	material_3.set_meta("factory_clock_pool_required", operands[52])
	material_3.set_meta("factory_world_space_uniform", operands[53])
	var material_4 := ShaderMaterial.new()
	material_4.shader = operands[54]
	material_4.set_shader_parameter("factory_world_to_source", operands[55])
	material_4.set_shader_parameter("factory_occurrence_alpha", operands[56])
	material_4.set_shader_parameter("noise_tex", operands[57])
	material_4.set_shader_parameter("impact_age", operands[58])
	material_4.set_shader_parameter("visible_hit", operands[59])
	material_4.set_meta("factory_occurrence_alpha", operands[60])
	material_4.set_meta("factory_prepared_shader", operands[61])
	material_4.set_meta("factory_opacity_prepared_shader", operands[62])
	material_4.set_meta("factory_clock_names", operands[63])
	material_4.set_meta("factory_clock_pool_required", operands[64])
	material_4.set_meta("factory_world_space_uniform", operands[65])
	var material_5 := ShaderMaterial.new()
	material_5.shader = operands[66]
	material_5.set_shader_parameter("factory_world_to_source", operands[67])
	material_5.set_shader_parameter("factory_occurrence_alpha", operands[68])
	material_5.set_shader_parameter("frost", operands[69])
	material_5.set_meta("factory_occurrence_alpha", operands[70])
	material_5.set_meta("factory_prepared_shader", operands[71])
	material_5.set_meta("factory_opacity_prepared_shader", operands[72])
	material_5.set_meta("factory_clock_names", operands[73])
	material_5.set_meta("factory_clock_pool_required", operands[74])
	material_5.set_meta("factory_world_space_uniform", operands[75])
	var material_6 := ShaderMaterial.new()
	material_6.shader = operands[76]
	material_6.set_shader_parameter("factory_world_to_source", operands[77])
	material_6.set_shader_parameter("factory_occurrence_alpha", operands[78])
	material_6.set_shader_parameter("fresnelpower", operands[79])
	material_6.set_shader_parameter("AddTexture", operands[80])
	material_6.set_shader_parameter("Texture_add2_offset", operands[81])
	material_6.set_shader_parameter("AddTexture2", operands[82])
	material_6.set_shader_parameter("DetailsTexture", operands[83])
	material_6.set_shader_parameter("Color1DGradient", operands[84])
	material_6.set_shader_parameter("ColorIntensity", operands[85])
	material_6.set_meta("factory_occurrence_alpha", operands[86])
	material_6.set_meta("factory_prepared_shader", operands[87])
	material_6.set_meta("factory_opacity_prepared_shader", operands[88])
	material_6.set_meta("factory_clock_names", operands[89])
	material_6.set_meta("factory_clock_pool_required", operands[90])
	material_6.set_meta("factory_world_space_uniform", operands[91])
	var material_7 := ShaderMaterial.new()
	material_7.shader = operands[92]
	material_7.set_shader_parameter("factory_world_to_source", operands[93])
	material_7.set_shader_parameter("factory_occurrence_alpha", operands[94])
	material_7.set_shader_parameter("noise_tex", operands[95])
	material_7.set_shader_parameter("impact_age", operands[96])
	material_7.set_shader_parameter("visible_hit", operands[97])
	material_7.set_meta("factory_occurrence_alpha", operands[98])
	material_7.set_meta("factory_prepared_shader", operands[99])
	material_7.set_meta("factory_opacity_prepared_shader", operands[100])
	material_7.set_meta("factory_clock_names", operands[101])
	material_7.set_meta("factory_clock_pool_required", operands[102])
	material_7.set_meta("factory_world_space_uniform", operands[103])
	var material_8 := ShaderMaterial.new()
	material_8.shader = operands[104]
	material_8.set_shader_parameter("factory_world_to_source", operands[105])
	material_8.set_shader_parameter("factory_occurrence_alpha", operands[106])
	material_8.set_shader_parameter("frost", operands[107])
	material_8.set_meta("factory_occurrence_alpha", operands[108])
	material_8.set_meta("factory_prepared_shader", operands[109])
	material_8.set_meta("factory_opacity_prepared_shader", operands[110])
	material_8.set_meta("factory_clock_names", operands[111])
	material_8.set_meta("factory_clock_pool_required", operands[112])
	material_8.set_meta("factory_world_space_uniform", operands[113])
	var material_9 := ShaderMaterial.new()
	material_9.shader = operands[114]
	material_9.set_shader_parameter("factory_world_to_source", operands[115])
	material_9.set_shader_parameter("factory_occurrence_alpha", operands[116])
	material_9.set_shader_parameter("fresnelpower", operands[117])
	material_9.set_shader_parameter("AddTexture", operands[118])
	material_9.set_shader_parameter("Texture_add2_offset", operands[119])
	material_9.set_shader_parameter("AddTexture2", operands[120])
	material_9.set_shader_parameter("DetailsTexture", operands[121])
	material_9.set_shader_parameter("Color1DGradient", operands[122])
	material_9.set_shader_parameter("ColorIntensity", operands[123])
	material_9.set_meta("factory_occurrence_alpha", operands[124])
	material_9.set_meta("factory_prepared_shader", operands[125])
	material_9.set_meta("factory_opacity_prepared_shader", operands[126])
	material_9.set_meta("factory_clock_names", operands[127])
	material_9.set_meta("factory_clock_pool_required", operands[128])
	material_9.set_meta("factory_world_space_uniform", operands[129])
	var material_10 := ShaderMaterial.new()
	material_10.shader = operands[130]
	material_10.set_shader_parameter("factory_world_to_source", operands[131])
	material_10.set_shader_parameter("factory_occurrence_alpha", operands[132])
	material_10.set_shader_parameter("noise_tex", operands[133])
	material_10.set_shader_parameter("impact_age", operands[134])
	material_10.set_shader_parameter("visible_hit", operands[135])
	material_10.set_meta("factory_occurrence_alpha", operands[136])
	material_10.set_meta("factory_prepared_shader", operands[137])
	material_10.set_meta("factory_opacity_prepared_shader", operands[138])
	material_10.set_meta("factory_clock_names", operands[139])
	material_10.set_meta("factory_clock_pool_required", operands[140])
	material_10.set_meta("factory_world_space_uniform", operands[141])
	var material_11 := ShaderMaterial.new()
	material_11.shader = operands[142]
	material_11.set_shader_parameter("factory_world_to_source", operands[143])
	material_11.set_shader_parameter("factory_occurrence_alpha", operands[144])
	material_11.set_shader_parameter("frost", operands[145])
	material_11.set_meta("factory_occurrence_alpha", operands[146])
	material_11.set_meta("factory_prepared_shader", operands[147])
	material_11.set_meta("factory_opacity_prepared_shader", operands[148])
	material_11.set_meta("factory_clock_names", operands[149])
	material_11.set_meta("factory_clock_pool_required", operands[150])
	material_11.set_meta("factory_world_space_uniform", operands[151])
	var material_12 := ShaderMaterial.new()
	material_12.shader = operands[152]
	material_12.set_shader_parameter("factory_world_to_source", operands[153])
	material_12.set_shader_parameter("factory_occurrence_alpha", operands[154])
	material_12.set_shader_parameter("fresnelpower", operands[155])
	material_12.set_shader_parameter("AddTexture", operands[156])
	material_12.set_shader_parameter("Texture_add2_offset", operands[157])
	material_12.set_shader_parameter("AddTexture2", operands[158])
	material_12.set_shader_parameter("DetailsTexture", operands[159])
	material_12.set_shader_parameter("Color1DGradient", operands[160])
	material_12.set_shader_parameter("ColorIntensity", operands[161])
	material_12.set_meta("factory_occurrence_alpha", operands[162])
	material_12.set_meta("factory_prepared_shader", operands[163])
	material_12.set_meta("factory_opacity_prepared_shader", operands[164])
	material_12.set_meta("factory_clock_names", operands[165])
	material_12.set_meta("factory_clock_pool_required", operands[166])
	material_12.set_meta("factory_world_space_uniform", operands[167])
	var material_13 := ShaderMaterial.new()
	material_13.shader = operands[168]
	material_13.set_shader_parameter("factory_world_to_source", operands[169])
	material_13.set_shader_parameter("factory_occurrence_alpha", operands[170])
	material_13.set_shader_parameter("noise_tex", operands[171])
	material_13.set_shader_parameter("impact_age", operands[172])
	material_13.set_shader_parameter("visible_hit", operands[173])
	material_13.set_meta("factory_occurrence_alpha", operands[174])
	material_13.set_meta("factory_prepared_shader", operands[175])
	material_13.set_meta("factory_opacity_prepared_shader", operands[176])
	material_13.set_meta("factory_clock_names", operands[177])
	material_13.set_meta("factory_clock_pool_required", operands[178])
	material_13.set_meta("factory_world_space_uniform", operands[179])
	var material_14 := ShaderMaterial.new()
	material_14.shader = operands[180]
	material_14.set_shader_parameter("factory_world_to_source", operands[181])
	material_14.set_shader_parameter("factory_occurrence_alpha", operands[182])
	material_14.set_shader_parameter("frost", operands[183])
	material_14.set_meta("factory_occurrence_alpha", operands[184])
	material_14.set_meta("factory_prepared_shader", operands[185])
	material_14.set_meta("factory_opacity_prepared_shader", operands[186])
	material_14.set_meta("factory_clock_names", operands[187])
	material_14.set_meta("factory_clock_pool_required", operands[188])
	material_14.set_meta("factory_world_space_uniform", operands[189])
	var material_15 := ShaderMaterial.new()
	material_15.shader = operands[190]
	material_15.set_shader_parameter("factory_world_to_source", operands[191])
	material_15.set_shader_parameter("factory_occurrence_alpha", operands[192])
	material_15.set_shader_parameter("fresnelpower", operands[193])
	material_15.set_shader_parameter("AddTexture", operands[194])
	material_15.set_shader_parameter("Texture_add2_offset", operands[195])
	material_15.set_shader_parameter("AddTexture2", operands[196])
	material_15.set_shader_parameter("DetailsTexture", operands[197])
	material_15.set_shader_parameter("Color1DGradient", operands[198])
	material_15.set_shader_parameter("ColorIntensity", operands[199])
	material_15.set_meta("factory_occurrence_alpha", operands[200])
	material_15.set_meta("factory_prepared_shader", operands[201])
	material_15.set_meta("factory_opacity_prepared_shader", operands[202])
	material_15.set_meta("factory_clock_names", operands[203])
	material_15.set_meta("factory_clock_pool_required", operands[204])
	material_15.set_meta("factory_world_space_uniform", operands[205])
	var material_16 := ShaderMaterial.new()
	material_16.shader = operands[206]
	material_16.set_shader_parameter("factory_world_to_source", operands[207])
	material_16.set_shader_parameter("factory_occurrence_alpha", operands[208])
	material_16.set_shader_parameter("noise_tex", operands[209])
	material_16.set_shader_parameter("impact_age", operands[210])
	material_16.set_shader_parameter("visible_hit", operands[211])
	material_16.set_meta("factory_occurrence_alpha", operands[212])
	material_16.set_meta("factory_prepared_shader", operands[213])
	material_16.set_meta("factory_opacity_prepared_shader", operands[214])
	material_16.set_meta("factory_clock_names", operands[215])
	material_16.set_meta("factory_clock_pool_required", operands[216])
	material_16.set_meta("factory_world_space_uniform", operands[217])
	var material_17 := ShaderMaterial.new()
	material_17.shader = operands[218]
	material_17.set_shader_parameter("factory_world_to_source", operands[219])
	material_17.set_shader_parameter("factory_occurrence_alpha", operands[220])
	material_17.set_shader_parameter("frost", operands[221])
	material_17.set_meta("factory_occurrence_alpha", operands[222])
	material_17.set_meta("factory_prepared_shader", operands[223])
	material_17.set_meta("factory_opacity_prepared_shader", operands[224])
	material_17.set_meta("factory_clock_names", operands[225])
	material_17.set_meta("factory_clock_pool_required", operands[226])
	material_17.set_meta("factory_world_space_uniform", operands[227])
	var material_18 := ShaderMaterial.new()
	material_18.shader = operands[228]
	material_18.set_shader_parameter("factory_world_to_source", operands[229])
	material_18.set_shader_parameter("factory_occurrence_alpha", operands[230])
	material_18.set_shader_parameter("fresnelpower", operands[231])
	material_18.set_shader_parameter("AddTexture", operands[232])
	material_18.set_shader_parameter("Texture_add2_offset", operands[233])
	material_18.set_shader_parameter("AddTexture2", operands[234])
	material_18.set_shader_parameter("DetailsTexture", operands[235])
	material_18.set_shader_parameter("Color1DGradient", operands[236])
	material_18.set_shader_parameter("ColorIntensity", operands[237])
	material_18.set_meta("factory_occurrence_alpha", operands[238])
	material_18.set_meta("factory_prepared_shader", operands[239])
	material_18.set_meta("factory_opacity_prepared_shader", operands[240])
	material_18.set_meta("factory_clock_names", operands[241])
	material_18.set_meta("factory_clock_pool_required", operands[242])
	material_18.set_meta("factory_world_space_uniform", operands[243])
	var material_19 := ShaderMaterial.new()
	material_19.shader = operands[244]
	material_19.set_shader_parameter("factory_world_to_source", operands[245])
	material_19.set_shader_parameter("factory_occurrence_alpha", operands[246])
	material_19.set_shader_parameter("noise_tex", operands[247])
	material_19.set_shader_parameter("impact_age", operands[248])
	material_19.set_shader_parameter("visible_hit", operands[249])
	material_19.set_meta("factory_occurrence_alpha", operands[250])
	material_19.set_meta("factory_prepared_shader", operands[251])
	material_19.set_meta("factory_opacity_prepared_shader", operands[252])
	material_19.set_meta("factory_clock_names", operands[253])
	material_19.set_meta("factory_clock_pool_required", operands[254])
	material_19.set_meta("factory_world_space_uniform", operands[255])
	var material_20 := ShaderMaterial.new()
	material_20.shader = operands[256]
	material_20.set_shader_parameter("factory_world_to_source", operands[257])
	material_20.set_shader_parameter("factory_occurrence_alpha", operands[258])
	material_20.set_shader_parameter("frost", operands[259])
	material_20.set_meta("factory_occurrence_alpha", operands[260])
	material_20.set_meta("factory_prepared_shader", operands[261])
	material_20.set_meta("factory_opacity_prepared_shader", operands[262])
	material_20.set_meta("factory_clock_names", operands[263])
	material_20.set_meta("factory_clock_pool_required", operands[264])
	material_20.set_meta("factory_world_space_uniform", operands[265])
	var material_21 := ShaderMaterial.new()
	material_21.shader = operands[266]
	material_21.set_shader_parameter("factory_world_to_source", operands[267])
	material_21.set_shader_parameter("factory_occurrence_alpha", operands[268])
	material_21.set_shader_parameter("fresnelpower", operands[269])
	material_21.set_shader_parameter("AddTexture", operands[270])
	material_21.set_shader_parameter("Texture_add2_offset", operands[271])
	material_21.set_shader_parameter("AddTexture2", operands[272])
	material_21.set_shader_parameter("DetailsTexture", operands[273])
	material_21.set_shader_parameter("Color1DGradient", operands[274])
	material_21.set_shader_parameter("ColorIntensity", operands[275])
	material_21.set_meta("factory_occurrence_alpha", operands[276])
	material_21.set_meta("factory_prepared_shader", operands[277])
	material_21.set_meta("factory_opacity_prepared_shader", operands[278])
	material_21.set_meta("factory_clock_names", operands[279])
	material_21.set_meta("factory_clock_pool_required", operands[280])
	material_21.set_meta("factory_world_space_uniform", operands[281])
	var material_22 := ShaderMaterial.new()
	material_22.shader = operands[282]
	material_22.set_shader_parameter("factory_world_to_source", operands[283])
	material_22.set_shader_parameter("factory_occurrence_alpha", operands[284])
	material_22.set_shader_parameter("noise_tex", operands[285])
	material_22.set_shader_parameter("impact_age", operands[286])
	material_22.set_shader_parameter("visible_hit", operands[287])
	material_22.set_meta("factory_occurrence_alpha", operands[288])
	material_22.set_meta("factory_prepared_shader", operands[289])
	material_22.set_meta("factory_opacity_prepared_shader", operands[290])
	material_22.set_meta("factory_clock_names", operands[291])
	material_22.set_meta("factory_clock_pool_required", operands[292])
	material_22.set_meta("factory_world_space_uniform", operands[293])
	var material_23 := ShaderMaterial.new()
	material_23.shader = operands[294]
	material_23.set_shader_parameter("factory_world_to_source", operands[295])
	material_23.set_shader_parameter("factory_occurrence_alpha", operands[296])
	material_23.set_shader_parameter("frost", operands[297])
	material_23.set_meta("factory_occurrence_alpha", operands[298])
	material_23.set_meta("factory_prepared_shader", operands[299])
	material_23.set_meta("factory_opacity_prepared_shader", operands[300])
	material_23.set_meta("factory_clock_names", operands[301])
	material_23.set_meta("factory_clock_pool_required", operands[302])
	material_23.set_meta("factory_world_space_uniform", operands[303])
	var material_24 := ShaderMaterial.new()
	material_24.shader = operands[304]
	material_24.set_shader_parameter("factory_world_to_source", operands[305])
	material_24.set_shader_parameter("factory_occurrence_alpha", operands[306])
	material_24.set_shader_parameter("fresnelpower", operands[307])
	material_24.set_shader_parameter("AddTexture", operands[308])
	material_24.set_shader_parameter("Texture_add2_offset", operands[309])
	material_24.set_shader_parameter("AddTexture2", operands[310])
	material_24.set_shader_parameter("DetailsTexture", operands[311])
	material_24.set_shader_parameter("Color1DGradient", operands[312])
	material_24.set_shader_parameter("ColorIntensity", operands[313])
	material_24.set_meta("factory_occurrence_alpha", operands[314])
	material_24.set_meta("factory_prepared_shader", operands[315])
	material_24.set_meta("factory_opacity_prepared_shader", operands[316])
	material_24.set_meta("factory_clock_names", operands[317])
	material_24.set_meta("factory_clock_pool_required", operands[318])
	material_24.set_meta("factory_world_space_uniform", operands[319])
	var material_25 := ShaderMaterial.new()
	material_25.shader = operands[320]
	material_25.set_shader_parameter("factory_world_to_source", operands[321])
	material_25.set_shader_parameter("factory_occurrence_alpha", operands[322])
	material_25.set_shader_parameter("noise_tex", operands[323])
	material_25.set_shader_parameter("impact_age", operands[324])
	material_25.set_shader_parameter("visible_hit", operands[325])
	material_25.set_meta("factory_occurrence_alpha", operands[326])
	material_25.set_meta("factory_prepared_shader", operands[327])
	material_25.set_meta("factory_opacity_prepared_shader", operands[328])
	material_25.set_meta("factory_clock_names", operands[329])
	material_25.set_meta("factory_clock_pool_required", operands[330])
	material_25.set_meta("factory_world_space_uniform", operands[331])
	var material_26 := ShaderMaterial.new()
	material_26.shader = operands[332]
	material_26.set_shader_parameter("factory_world_to_source", operands[333])
	material_26.set_shader_parameter("factory_occurrence_alpha", operands[334])
	material_26.set_shader_parameter("frost", operands[335])
	material_26.set_meta("factory_occurrence_alpha", operands[336])
	material_26.set_meta("factory_prepared_shader", operands[337])
	material_26.set_meta("factory_opacity_prepared_shader", operands[338])
	material_26.set_meta("factory_clock_names", operands[339])
	material_26.set_meta("factory_clock_pool_required", operands[340])
	material_26.set_meta("factory_world_space_uniform", operands[341])
	var material_27 := ShaderMaterial.new()
	material_27.shader = operands[342]
	material_27.set_shader_parameter("factory_world_to_source", operands[343])
	material_27.set_shader_parameter("factory_occurrence_alpha", operands[344])
	material_27.set_shader_parameter("fresnelpower", operands[345])
	material_27.set_shader_parameter("AddTexture", operands[346])
	material_27.set_shader_parameter("Texture_add2_offset", operands[347])
	material_27.set_shader_parameter("AddTexture2", operands[348])
	material_27.set_shader_parameter("DetailsTexture", operands[349])
	material_27.set_shader_parameter("Color1DGradient", operands[350])
	material_27.set_shader_parameter("ColorIntensity", operands[351])
	material_27.set_meta("factory_occurrence_alpha", operands[352])
	material_27.set_meta("factory_prepared_shader", operands[353])
	material_27.set_meta("factory_opacity_prepared_shader", operands[354])
	material_27.set_meta("factory_clock_names", operands[355])
	material_27.set_meta("factory_clock_pool_required", operands[356])
	material_27.set_meta("factory_world_space_uniform", operands[357])
	var material_28 := ShaderMaterial.new()
	material_28.shader = operands[358]
	material_28.set_shader_parameter("factory_world_to_source", operands[359])
	material_28.set_shader_parameter("factory_occurrence_alpha", operands[360])
	material_28.set_shader_parameter("noise_tex", operands[361])
	material_28.set_shader_parameter("impact_age", operands[362])
	material_28.set_shader_parameter("visible_hit", operands[363])
	material_28.set_meta("factory_occurrence_alpha", operands[364])
	material_28.set_meta("factory_prepared_shader", operands[365])
	material_28.set_meta("factory_opacity_prepared_shader", operands[366])
	material_28.set_meta("factory_clock_names", operands[367])
	material_28.set_meta("factory_clock_pool_required", operands[368])
	material_28.set_meta("factory_world_space_uniform", operands[369])
	var material_29 := ShaderMaterial.new()
	material_29.shader = operands[370]
	material_29.set_shader_parameter("factory_world_to_source", operands[371])
	material_29.set_shader_parameter("factory_occurrence_alpha", operands[372])
	material_29.set_shader_parameter("frost", operands[373])
	material_29.set_meta("factory_occurrence_alpha", operands[374])
	material_29.set_meta("factory_prepared_shader", operands[375])
	material_29.set_meta("factory_opacity_prepared_shader", operands[376])
	material_29.set_meta("factory_clock_names", operands[377])
	material_29.set_meta("factory_clock_pool_required", operands[378])
	material_29.set_meta("factory_world_space_uniform", operands[379])
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "@Node3D@408"
	node_0.set("metadata/factory_native_gpu_emitters", operands[380])
	var node_1 := Node3D.new()
	node_1.name = "assembly"
	node_0.add_child(node_1)
	var node_2 := Node3D.new()
	node_2.name = "chunk_0"
	node_2.transform = operands[381]
	node_1.add_child(node_2)
	var node_3 := Node3D.new()
	node_3.name = "effect"
	node_2.add_child(node_3)
	var node_4 := Node3D.new()
	node_4.name = "Donor"
	node_3.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "FactoryGenerated_0000_MeshInstance3D"
	node_5.layers = operands[382]
	node_5.material_override = material_0
	node_5.mesh = operands[383]
	node_4.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "FactoryGenerated_0002_MeshInstance3D"
	node_6.transform = operands[384]
	node_6.layers = operands[385]
	node_6.material_override = material_1
	node_6.mesh = operands[386]
	node_4.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "FactoryGenerated_0004_MeshInstance3D"
	node_7.visible = operands[387]
	node_7.layers = operands[388]
	node_7.mesh = operands[389]
	node_7.set("surface_material_override/0", material_0)
	node_7.set("surface_material_override/1", material_2)
	node_4.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "FactoryGenerated_0006_MeshInstance3D"
	node_8.visible = operands[390]
	node_8.layers = operands[391]
	node_8.mesh = operands[392]
	node_8.set("surface_material_override/0", material_0)
	node_8.set("surface_material_override/1", material_2)
	node_4.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "FactoryGenerated_0008_MeshInstance3D"
	node_9.visible = operands[393]
	node_9.layers = operands[394]
	node_9.mesh = operands[395]
	node_9.set("surface_material_override/0", material_0)
	node_9.set("surface_material_override/1", material_2)
	node_4.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "FactoryGenerated_0010_MeshInstance3D"
	node_10.visible = operands[396]
	node_10.layers = operands[397]
	node_10.mesh = operands[398]
	node_10.set("surface_material_override/0", material_0)
	node_10.set("surface_material_override/1", material_2)
	node_4.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "FactoryGenerated_0012_MeshInstance3D"
	node_11.visible = operands[399]
	node_11.layers = operands[400]
	node_11.mesh = operands[401]
	node_11.set("surface_material_override/0", material_0)
	node_11.set("surface_material_override/1", material_2)
	node_4.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "FactoryGenerated_0014_MeshInstance3D"
	node_12.visible = operands[402]
	node_12.layers = operands[403]
	node_12.mesh = operands[404]
	node_12.set("surface_material_override/0", material_0)
	node_12.set("surface_material_override/1", material_2)
	node_4.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "FactoryGenerated_0016_MeshInstance3D"
	node_13.visible = operands[405]
	node_13.layers = operands[406]
	node_13.mesh = operands[407]
	node_13.set("surface_material_override/0", material_0)
	node_13.set("surface_material_override/1", material_2)
	node_4.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "FactoryGenerated_0018_MeshInstance3D"
	node_14.visible = operands[408]
	node_14.layers = operands[409]
	node_14.mesh = operands[410]
	node_14.set("surface_material_override/0", material_0)
	node_14.set("surface_material_override/1", material_2)
	node_4.add_child(node_14)
	var node_15 := MeshInstance3D.new()
	node_15.name = "FactoryGenerated_0020_MeshInstance3D"
	node_15.visible = operands[411]
	node_15.layers = operands[412]
	node_15.mesh = operands[413]
	node_15.set("surface_material_override/0", material_0)
	node_15.set("surface_material_override/1", material_2)
	node_4.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "FactoryGenerated_0022_MeshInstance3D"
	node_16.visible = operands[414]
	node_16.layers = operands[415]
	node_16.mesh = operands[416]
	node_16.set("surface_material_override/0", material_0)
	node_16.set("surface_material_override/1", material_2)
	node_4.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "FactoryGenerated_0024_MeshInstance3D"
	node_17.visible = operands[417]
	node_17.layers = operands[418]
	node_17.mesh = operands[419]
	node_17.set("surface_material_override/0", material_0)
	node_17.set("surface_material_override/1", material_2)
	node_4.add_child(node_17)
	var node_18 := MeshInstance3D.new()
	node_18.name = "FactoryGenerated_0026_MeshInstance3D"
	node_18.visible = operands[420]
	node_18.layers = operands[421]
	node_18.mesh = operands[422]
	node_18.set("surface_material_override/0", material_0)
	node_18.set("surface_material_override/1", material_2)
	node_4.add_child(node_18)
	var node_19 := Node3D.new()
	node_19.name = "chunk_1"
	node_19.transform = operands[423]
	node_19.visible = operands[424]
	node_1.add_child(node_19)
	var node_20 := Node3D.new()
	node_20.name = "effect"
	node_19.add_child(node_20)
	var node_21 := Node3D.new()
	node_21.name = "Donor"
	node_20.add_child(node_21)
	var node_22 := MeshInstance3D.new()
	node_22.name = "FactoryGenerated_0000_MeshInstance3D"
	node_22.layers = operands[425]
	node_22.material_override = material_3
	node_22.mesh = operands[426]
	node_21.add_child(node_22)
	var node_23 := MeshInstance3D.new()
	node_23.name = "FactoryGenerated_0002_MeshInstance3D"
	node_23.transform = operands[427]
	node_23.layers = operands[428]
	node_23.material_override = material_4
	node_23.mesh = operands[429]
	node_21.add_child(node_23)
	var node_24 := MeshInstance3D.new()
	node_24.name = "FactoryGenerated_0004_MeshInstance3D"
	node_24.visible = operands[430]
	node_24.layers = operands[431]
	node_24.mesh = operands[432]
	node_24.set("surface_material_override/0", material_3)
	node_24.set("surface_material_override/1", material_5)
	node_21.add_child(node_24)
	var node_25 := MeshInstance3D.new()
	node_25.name = "FactoryGenerated_0006_MeshInstance3D"
	node_25.visible = operands[433]
	node_25.layers = operands[434]
	node_25.mesh = operands[435]
	node_25.set("surface_material_override/0", material_3)
	node_25.set("surface_material_override/1", material_5)
	node_21.add_child(node_25)
	var node_26 := MeshInstance3D.new()
	node_26.name = "FactoryGenerated_0008_MeshInstance3D"
	node_26.visible = operands[436]
	node_26.layers = operands[437]
	node_26.mesh = operands[438]
	node_26.set("surface_material_override/0", material_3)
	node_26.set("surface_material_override/1", material_5)
	node_21.add_child(node_26)
	var node_27 := MeshInstance3D.new()
	node_27.name = "FactoryGenerated_0010_MeshInstance3D"
	node_27.visible = operands[439]
	node_27.layers = operands[440]
	node_27.mesh = operands[441]
	node_27.set("surface_material_override/0", material_3)
	node_27.set("surface_material_override/1", material_5)
	node_21.add_child(node_27)
	var node_28 := MeshInstance3D.new()
	node_28.name = "FactoryGenerated_0012_MeshInstance3D"
	node_28.visible = operands[442]
	node_28.layers = operands[443]
	node_28.mesh = operands[444]
	node_28.set("surface_material_override/0", material_3)
	node_28.set("surface_material_override/1", material_5)
	node_21.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "FactoryGenerated_0014_MeshInstance3D"
	node_29.visible = operands[445]
	node_29.layers = operands[446]
	node_29.mesh = operands[447]
	node_29.set("surface_material_override/0", material_3)
	node_29.set("surface_material_override/1", material_5)
	node_21.add_child(node_29)
	var node_30 := MeshInstance3D.new()
	node_30.name = "FactoryGenerated_0016_MeshInstance3D"
	node_30.visible = operands[448]
	node_30.layers = operands[449]
	node_30.mesh = operands[450]
	node_30.set("surface_material_override/0", material_3)
	node_30.set("surface_material_override/1", material_5)
	node_21.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "FactoryGenerated_0018_MeshInstance3D"
	node_31.visible = operands[451]
	node_31.layers = operands[452]
	node_31.mesh = operands[453]
	node_31.set("surface_material_override/0", material_3)
	node_31.set("surface_material_override/1", material_5)
	node_21.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "FactoryGenerated_0020_MeshInstance3D"
	node_32.visible = operands[454]
	node_32.layers = operands[455]
	node_32.mesh = operands[456]
	node_32.set("surface_material_override/0", material_3)
	node_32.set("surface_material_override/1", material_5)
	node_21.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "FactoryGenerated_0022_MeshInstance3D"
	node_33.visible = operands[457]
	node_33.layers = operands[458]
	node_33.mesh = operands[459]
	node_33.set("surface_material_override/0", material_3)
	node_33.set("surface_material_override/1", material_5)
	node_21.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "FactoryGenerated_0024_MeshInstance3D"
	node_34.visible = operands[460]
	node_34.layers = operands[461]
	node_34.mesh = operands[462]
	node_34.set("surface_material_override/0", material_3)
	node_34.set("surface_material_override/1", material_5)
	node_21.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "FactoryGenerated_0026_MeshInstance3D"
	node_35.visible = operands[463]
	node_35.layers = operands[464]
	node_35.mesh = operands[465]
	node_35.set("surface_material_override/0", material_3)
	node_35.set("surface_material_override/1", material_5)
	node_21.add_child(node_35)
	var node_36 := Node3D.new()
	node_36.name = "chunk_2"
	node_36.transform = operands[466]
	node_36.visible = operands[467]
	node_1.add_child(node_36)
	var node_37 := Node3D.new()
	node_37.name = "effect"
	node_36.add_child(node_37)
	var node_38 := Node3D.new()
	node_38.name = "Donor"
	node_37.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "FactoryGenerated_0000_MeshInstance3D"
	node_39.layers = operands[468]
	node_39.material_override = material_6
	node_39.mesh = operands[469]
	node_38.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "FactoryGenerated_0002_MeshInstance3D"
	node_40.transform = operands[470]
	node_40.layers = operands[471]
	node_40.material_override = material_7
	node_40.mesh = operands[472]
	node_38.add_child(node_40)
	var node_41 := MeshInstance3D.new()
	node_41.name = "FactoryGenerated_0004_MeshInstance3D"
	node_41.visible = operands[473]
	node_41.layers = operands[474]
	node_41.mesh = operands[475]
	node_41.set("surface_material_override/0", material_6)
	node_41.set("surface_material_override/1", material_8)
	node_38.add_child(node_41)
	var node_42 := MeshInstance3D.new()
	node_42.name = "FactoryGenerated_0006_MeshInstance3D"
	node_42.visible = operands[476]
	node_42.layers = operands[477]
	node_42.mesh = operands[478]
	node_42.set("surface_material_override/0", material_6)
	node_42.set("surface_material_override/1", material_8)
	node_38.add_child(node_42)
	var node_43 := MeshInstance3D.new()
	node_43.name = "FactoryGenerated_0008_MeshInstance3D"
	node_43.visible = operands[479]
	node_43.layers = operands[480]
	node_43.mesh = operands[481]
	node_43.set("surface_material_override/0", material_6)
	node_43.set("surface_material_override/1", material_8)
	node_38.add_child(node_43)
	var node_44 := MeshInstance3D.new()
	node_44.name = "FactoryGenerated_0010_MeshInstance3D"
	node_44.visible = operands[482]
	node_44.layers = operands[483]
	node_44.mesh = operands[484]
	node_44.set("surface_material_override/0", material_6)
	node_44.set("surface_material_override/1", material_8)
	node_38.add_child(node_44)
	var node_45 := MeshInstance3D.new()
	node_45.name = "FactoryGenerated_0012_MeshInstance3D"
	node_45.visible = operands[485]
	node_45.layers = operands[486]
	node_45.mesh = operands[487]
	node_45.set("surface_material_override/0", material_6)
	node_45.set("surface_material_override/1", material_8)
	node_38.add_child(node_45)
	var node_46 := MeshInstance3D.new()
	node_46.name = "FactoryGenerated_0014_MeshInstance3D"
	node_46.visible = operands[488]
	node_46.layers = operands[489]
	node_46.mesh = operands[490]
	node_46.set("surface_material_override/0", material_6)
	node_46.set("surface_material_override/1", material_8)
	node_38.add_child(node_46)
	var node_47 := MeshInstance3D.new()
	node_47.name = "FactoryGenerated_0016_MeshInstance3D"
	node_47.visible = operands[491]
	node_47.layers = operands[492]
	node_47.mesh = operands[493]
	node_47.set("surface_material_override/0", material_6)
	node_47.set("surface_material_override/1", material_8)
	node_38.add_child(node_47)
	var node_48 := MeshInstance3D.new()
	node_48.name = "FactoryGenerated_0018_MeshInstance3D"
	node_48.visible = operands[494]
	node_48.layers = operands[495]
	node_48.mesh = operands[496]
	node_48.set("surface_material_override/0", material_6)
	node_48.set("surface_material_override/1", material_8)
	node_38.add_child(node_48)
	var node_49 := MeshInstance3D.new()
	node_49.name = "FactoryGenerated_0020_MeshInstance3D"
	node_49.visible = operands[497]
	node_49.layers = operands[498]
	node_49.mesh = operands[499]
	node_49.set("surface_material_override/0", material_6)
	node_49.set("surface_material_override/1", material_8)
	node_38.add_child(node_49)
	var node_50 := MeshInstance3D.new()
	node_50.name = "FactoryGenerated_0022_MeshInstance3D"
	node_50.visible = operands[500]
	node_50.layers = operands[501]
	node_50.mesh = operands[502]
	node_50.set("surface_material_override/0", material_6)
	node_50.set("surface_material_override/1", material_8)
	node_38.add_child(node_50)
	var node_51 := MeshInstance3D.new()
	node_51.name = "FactoryGenerated_0024_MeshInstance3D"
	node_51.visible = operands[503]
	node_51.layers = operands[504]
	node_51.mesh = operands[505]
	node_51.set("surface_material_override/0", material_6)
	node_51.set("surface_material_override/1", material_8)
	node_38.add_child(node_51)
	var node_52 := MeshInstance3D.new()
	node_52.name = "FactoryGenerated_0026_MeshInstance3D"
	node_52.visible = operands[506]
	node_52.layers = operands[507]
	node_52.mesh = operands[508]
	node_52.set("surface_material_override/0", material_6)
	node_52.set("surface_material_override/1", material_8)
	node_38.add_child(node_52)
	var node_53 := Node3D.new()
	node_53.name = "chunk_3"
	node_53.transform = operands[509]
	node_53.visible = operands[510]
	node_1.add_child(node_53)
	var node_54 := Node3D.new()
	node_54.name = "effect"
	node_53.add_child(node_54)
	var node_55 := Node3D.new()
	node_55.name = "Donor"
	node_54.add_child(node_55)
	var node_56 := MeshInstance3D.new()
	node_56.name = "FactoryGenerated_0000_MeshInstance3D"
	node_56.layers = operands[511]
	node_56.material_override = material_9
	node_56.mesh = operands[512]
	node_55.add_child(node_56)
	var node_57 := MeshInstance3D.new()
	node_57.name = "FactoryGenerated_0002_MeshInstance3D"
	node_57.transform = operands[513]
	node_57.layers = operands[514]
	node_57.material_override = material_10
	node_57.mesh = operands[515]
	node_55.add_child(node_57)
	var node_58 := MeshInstance3D.new()
	node_58.name = "FactoryGenerated_0004_MeshInstance3D"
	node_58.visible = operands[516]
	node_58.layers = operands[517]
	node_58.mesh = operands[518]
	node_58.set("surface_material_override/0", material_9)
	node_58.set("surface_material_override/1", material_11)
	node_55.add_child(node_58)
	var node_59 := MeshInstance3D.new()
	node_59.name = "FactoryGenerated_0006_MeshInstance3D"
	node_59.visible = operands[519]
	node_59.layers = operands[520]
	node_59.mesh = operands[521]
	node_59.set("surface_material_override/0", material_9)
	node_59.set("surface_material_override/1", material_11)
	node_55.add_child(node_59)
	var node_60 := MeshInstance3D.new()
	node_60.name = "FactoryGenerated_0008_MeshInstance3D"
	node_60.visible = operands[522]
	node_60.layers = operands[523]
	node_60.mesh = operands[524]
	node_60.set("surface_material_override/0", material_9)
	node_60.set("surface_material_override/1", material_11)
	node_55.add_child(node_60)
	var node_61 := MeshInstance3D.new()
	node_61.name = "FactoryGenerated_0010_MeshInstance3D"
	node_61.visible = operands[525]
	node_61.layers = operands[526]
	node_61.mesh = operands[527]
	node_61.set("surface_material_override/0", material_9)
	node_61.set("surface_material_override/1", material_11)
	node_55.add_child(node_61)
	var node_62 := MeshInstance3D.new()
	node_62.name = "FactoryGenerated_0012_MeshInstance3D"
	node_62.visible = operands[528]
	node_62.layers = operands[529]
	node_62.mesh = operands[530]
	node_62.set("surface_material_override/0", material_9)
	node_62.set("surface_material_override/1", material_11)
	node_55.add_child(node_62)
	var node_63 := MeshInstance3D.new()
	node_63.name = "FactoryGenerated_0014_MeshInstance3D"
	node_63.visible = operands[531]
	node_63.layers = operands[532]
	node_63.mesh = operands[533]
	node_63.set("surface_material_override/0", material_9)
	node_63.set("surface_material_override/1", material_11)
	node_55.add_child(node_63)
	var node_64 := MeshInstance3D.new()
	node_64.name = "FactoryGenerated_0016_MeshInstance3D"
	node_64.visible = operands[534]
	node_64.layers = operands[535]
	node_64.mesh = operands[536]
	node_64.set("surface_material_override/0", material_9)
	node_64.set("surface_material_override/1", material_11)
	node_55.add_child(node_64)
	var node_65 := MeshInstance3D.new()
	node_65.name = "FactoryGenerated_0018_MeshInstance3D"
	node_65.visible = operands[537]
	node_65.layers = operands[538]
	node_65.mesh = operands[539]
	node_65.set("surface_material_override/0", material_9)
	node_65.set("surface_material_override/1", material_11)
	node_55.add_child(node_65)
	var node_66 := MeshInstance3D.new()
	node_66.name = "FactoryGenerated_0020_MeshInstance3D"
	node_66.visible = operands[540]
	node_66.layers = operands[541]
	node_66.mesh = operands[542]
	node_66.set("surface_material_override/0", material_9)
	node_66.set("surface_material_override/1", material_11)
	node_55.add_child(node_66)
	var node_67 := MeshInstance3D.new()
	node_67.name = "FactoryGenerated_0022_MeshInstance3D"
	node_67.visible = operands[543]
	node_67.layers = operands[544]
	node_67.mesh = operands[545]
	node_67.set("surface_material_override/0", material_9)
	node_67.set("surface_material_override/1", material_11)
	node_55.add_child(node_67)
	var node_68 := MeshInstance3D.new()
	node_68.name = "FactoryGenerated_0024_MeshInstance3D"
	node_68.visible = operands[546]
	node_68.layers = operands[547]
	node_68.mesh = operands[548]
	node_68.set("surface_material_override/0", material_9)
	node_68.set("surface_material_override/1", material_11)
	node_55.add_child(node_68)
	var node_69 := MeshInstance3D.new()
	node_69.name = "FactoryGenerated_0026_MeshInstance3D"
	node_69.visible = operands[549]
	node_69.layers = operands[550]
	node_69.mesh = operands[551]
	node_69.set("surface_material_override/0", material_9)
	node_69.set("surface_material_override/1", material_11)
	node_55.add_child(node_69)
	var node_70 := Node3D.new()
	node_70.name = "chunk_4"
	node_70.transform = operands[552]
	node_1.add_child(node_70)
	var node_71 := Node3D.new()
	node_71.name = "effect"
	node_70.add_child(node_71)
	var node_72 := Node3D.new()
	node_72.name = "Donor"
	node_71.add_child(node_72)
	var node_73 := MeshInstance3D.new()
	node_73.name = "FactoryGenerated_0000_MeshInstance3D"
	node_73.layers = operands[553]
	node_73.material_override = material_12
	node_73.mesh = operands[554]
	node_72.add_child(node_73)
	var node_74 := MeshInstance3D.new()
	node_74.name = "FactoryGenerated_0002_MeshInstance3D"
	node_74.transform = operands[555]
	node_74.layers = operands[556]
	node_74.material_override = material_13
	node_74.mesh = operands[557]
	node_72.add_child(node_74)
	var node_75 := MeshInstance3D.new()
	node_75.name = "FactoryGenerated_0004_MeshInstance3D"
	node_75.visible = operands[558]
	node_75.layers = operands[559]
	node_75.mesh = operands[560]
	node_75.set("surface_material_override/0", material_12)
	node_75.set("surface_material_override/1", material_14)
	node_72.add_child(node_75)
	var node_76 := MeshInstance3D.new()
	node_76.name = "FactoryGenerated_0006_MeshInstance3D"
	node_76.visible = operands[561]
	node_76.layers = operands[562]
	node_76.mesh = operands[563]
	node_76.set("surface_material_override/0", material_12)
	node_76.set("surface_material_override/1", material_14)
	node_72.add_child(node_76)
	var node_77 := MeshInstance3D.new()
	node_77.name = "FactoryGenerated_0008_MeshInstance3D"
	node_77.visible = operands[564]
	node_77.layers = operands[565]
	node_77.mesh = operands[566]
	node_77.set("surface_material_override/0", material_12)
	node_77.set("surface_material_override/1", material_14)
	node_72.add_child(node_77)
	var node_78 := MeshInstance3D.new()
	node_78.name = "FactoryGenerated_0010_MeshInstance3D"
	node_78.visible = operands[567]
	node_78.layers = operands[568]
	node_78.mesh = operands[569]
	node_78.set("surface_material_override/0", material_12)
	node_78.set("surface_material_override/1", material_14)
	node_72.add_child(node_78)
	var node_79 := MeshInstance3D.new()
	node_79.name = "FactoryGenerated_0012_MeshInstance3D"
	node_79.visible = operands[570]
	node_79.layers = operands[571]
	node_79.mesh = operands[572]
	node_79.set("surface_material_override/0", material_12)
	node_79.set("surface_material_override/1", material_14)
	node_72.add_child(node_79)
	var node_80 := MeshInstance3D.new()
	node_80.name = "FactoryGenerated_0014_MeshInstance3D"
	node_80.visible = operands[573]
	node_80.layers = operands[574]
	node_80.mesh = operands[575]
	node_80.set("surface_material_override/0", material_12)
	node_80.set("surface_material_override/1", material_14)
	node_72.add_child(node_80)
	var node_81 := MeshInstance3D.new()
	node_81.name = "FactoryGenerated_0016_MeshInstance3D"
	node_81.visible = operands[576]
	node_81.layers = operands[577]
	node_81.mesh = operands[578]
	node_81.set("surface_material_override/0", material_12)
	node_81.set("surface_material_override/1", material_14)
	node_72.add_child(node_81)
	var node_82 := MeshInstance3D.new()
	node_82.name = "FactoryGenerated_0018_MeshInstance3D"
	node_82.visible = operands[579]
	node_82.layers = operands[580]
	node_82.mesh = operands[581]
	node_82.set("surface_material_override/0", material_12)
	node_82.set("surface_material_override/1", material_14)
	node_72.add_child(node_82)
	var node_83 := MeshInstance3D.new()
	node_83.name = "FactoryGenerated_0020_MeshInstance3D"
	node_83.visible = operands[582]
	node_83.layers = operands[583]
	node_83.mesh = operands[584]
	node_83.set("surface_material_override/0", material_12)
	node_83.set("surface_material_override/1", material_14)
	node_72.add_child(node_83)
	var node_84 := MeshInstance3D.new()
	node_84.name = "FactoryGenerated_0022_MeshInstance3D"
	node_84.visible = operands[585]
	node_84.layers = operands[586]
	node_84.mesh = operands[587]
	node_84.set("surface_material_override/0", material_12)
	node_84.set("surface_material_override/1", material_14)
	node_72.add_child(node_84)
	var node_85 := MeshInstance3D.new()
	node_85.name = "FactoryGenerated_0024_MeshInstance3D"
	node_85.visible = operands[588]
	node_85.layers = operands[589]
	node_85.mesh = operands[590]
	node_85.set("surface_material_override/0", material_12)
	node_85.set("surface_material_override/1", material_14)
	node_72.add_child(node_85)
	var node_86 := MeshInstance3D.new()
	node_86.name = "FactoryGenerated_0026_MeshInstance3D"
	node_86.visible = operands[591]
	node_86.layers = operands[592]
	node_86.mesh = operands[593]
	node_86.set("surface_material_override/0", material_12)
	node_86.set("surface_material_override/1", material_14)
	node_72.add_child(node_86)
	var node_87 := Node3D.new()
	node_87.name = "chunk_5"
	node_1.add_child(node_87)
	var node_88 := Node3D.new()
	node_88.name = "effect"
	node_87.add_child(node_88)
	var node_89 := Node3D.new()
	node_89.name = "Donor"
	node_88.add_child(node_89)
	var node_90 := MeshInstance3D.new()
	node_90.name = "FactoryGenerated_0000_MeshInstance3D"
	node_90.layers = operands[594]
	node_90.material_override = material_15
	node_90.mesh = operands[595]
	node_89.add_child(node_90)
	var node_91 := MeshInstance3D.new()
	node_91.name = "FactoryGenerated_0002_MeshInstance3D"
	node_91.transform = operands[596]
	node_91.layers = operands[597]
	node_91.material_override = material_16
	node_91.mesh = operands[598]
	node_89.add_child(node_91)
	var node_92 := MeshInstance3D.new()
	node_92.name = "FactoryGenerated_0004_MeshInstance3D"
	node_92.visible = operands[599]
	node_92.layers = operands[600]
	node_92.mesh = operands[601]
	node_92.set("surface_material_override/0", material_15)
	node_92.set("surface_material_override/1", material_17)
	node_89.add_child(node_92)
	var node_93 := MeshInstance3D.new()
	node_93.name = "FactoryGenerated_0006_MeshInstance3D"
	node_93.visible = operands[602]
	node_93.layers = operands[603]
	node_93.mesh = operands[604]
	node_93.set("surface_material_override/0", material_15)
	node_93.set("surface_material_override/1", material_17)
	node_89.add_child(node_93)
	var node_94 := MeshInstance3D.new()
	node_94.name = "FactoryGenerated_0008_MeshInstance3D"
	node_94.visible = operands[605]
	node_94.layers = operands[606]
	node_94.mesh = operands[607]
	node_94.set("surface_material_override/0", material_15)
	node_94.set("surface_material_override/1", material_17)
	node_89.add_child(node_94)
	var node_95 := MeshInstance3D.new()
	node_95.name = "FactoryGenerated_0010_MeshInstance3D"
	node_95.visible = operands[608]
	node_95.layers = operands[609]
	node_95.mesh = operands[610]
	node_95.set("surface_material_override/0", material_15)
	node_95.set("surface_material_override/1", material_17)
	node_89.add_child(node_95)
	var node_96 := MeshInstance3D.new()
	node_96.name = "FactoryGenerated_0012_MeshInstance3D"
	node_96.visible = operands[611]
	node_96.layers = operands[612]
	node_96.mesh = operands[613]
	node_96.set("surface_material_override/0", material_15)
	node_96.set("surface_material_override/1", material_17)
	node_89.add_child(node_96)
	var node_97 := MeshInstance3D.new()
	node_97.name = "FactoryGenerated_0014_MeshInstance3D"
	node_97.visible = operands[614]
	node_97.layers = operands[615]
	node_97.mesh = operands[616]
	node_97.set("surface_material_override/0", material_15)
	node_97.set("surface_material_override/1", material_17)
	node_89.add_child(node_97)
	var node_98 := MeshInstance3D.new()
	node_98.name = "FactoryGenerated_0016_MeshInstance3D"
	node_98.visible = operands[617]
	node_98.layers = operands[618]
	node_98.mesh = operands[619]
	node_98.set("surface_material_override/0", material_15)
	node_98.set("surface_material_override/1", material_17)
	node_89.add_child(node_98)
	var node_99 := MeshInstance3D.new()
	node_99.name = "FactoryGenerated_0018_MeshInstance3D"
	node_99.visible = operands[620]
	node_99.layers = operands[621]
	node_99.mesh = operands[622]
	node_99.set("surface_material_override/0", material_15)
	node_99.set("surface_material_override/1", material_17)
	node_89.add_child(node_99)
	var node_100 := MeshInstance3D.new()
	node_100.name = "FactoryGenerated_0020_MeshInstance3D"
	node_100.visible = operands[623]
	node_100.layers = operands[624]
	node_100.mesh = operands[625]
	node_100.set("surface_material_override/0", material_15)
	node_100.set("surface_material_override/1", material_17)
	node_89.add_child(node_100)
	var node_101 := MeshInstance3D.new()
	node_101.name = "FactoryGenerated_0022_MeshInstance3D"
	node_101.visible = operands[626]
	node_101.layers = operands[627]
	node_101.mesh = operands[628]
	node_101.set("surface_material_override/0", material_15)
	node_101.set("surface_material_override/1", material_17)
	node_89.add_child(node_101)
	var node_102 := MeshInstance3D.new()
	node_102.name = "FactoryGenerated_0024_MeshInstance3D"
	node_102.visible = operands[629]
	node_102.layers = operands[630]
	node_102.mesh = operands[631]
	node_102.set("surface_material_override/0", material_15)
	node_102.set("surface_material_override/1", material_17)
	node_89.add_child(node_102)
	var node_103 := MeshInstance3D.new()
	node_103.name = "FactoryGenerated_0026_MeshInstance3D"
	node_103.visible = operands[632]
	node_103.layers = operands[633]
	node_103.mesh = operands[634]
	node_103.set("surface_material_override/0", material_15)
	node_103.set("surface_material_override/1", material_17)
	node_89.add_child(node_103)
	var node_104 := Node3D.new()
	node_104.name = "chunk_6"
	node_104.transform = operands[635]
	node_104.visible = operands[636]
	node_1.add_child(node_104)
	var node_105 := Node3D.new()
	node_105.name = "effect"
	node_104.add_child(node_105)
	var node_106 := Node3D.new()
	node_106.name = "Donor"
	node_105.add_child(node_106)
	var node_107 := MeshInstance3D.new()
	node_107.name = "FactoryGenerated_0000_MeshInstance3D"
	node_107.layers = operands[637]
	node_107.material_override = material_18
	node_107.mesh = operands[638]
	node_106.add_child(node_107)
	var node_108 := MeshInstance3D.new()
	node_108.name = "FactoryGenerated_0002_MeshInstance3D"
	node_108.transform = operands[639]
	node_108.layers = operands[640]
	node_108.material_override = material_19
	node_108.mesh = operands[641]
	node_106.add_child(node_108)
	var node_109 := MeshInstance3D.new()
	node_109.name = "FactoryGenerated_0004_MeshInstance3D"
	node_109.visible = operands[642]
	node_109.layers = operands[643]
	node_109.mesh = operands[644]
	node_109.set("surface_material_override/0", material_18)
	node_109.set("surface_material_override/1", material_20)
	node_106.add_child(node_109)
	var node_110 := MeshInstance3D.new()
	node_110.name = "FactoryGenerated_0006_MeshInstance3D"
	node_110.visible = operands[645]
	node_110.layers = operands[646]
	node_110.mesh = operands[647]
	node_110.set("surface_material_override/0", material_18)
	node_110.set("surface_material_override/1", material_20)
	node_106.add_child(node_110)
	var node_111 := MeshInstance3D.new()
	node_111.name = "FactoryGenerated_0008_MeshInstance3D"
	node_111.visible = operands[648]
	node_111.layers = operands[649]
	node_111.mesh = operands[650]
	node_111.set("surface_material_override/0", material_18)
	node_111.set("surface_material_override/1", material_20)
	node_106.add_child(node_111)
	var node_112 := MeshInstance3D.new()
	node_112.name = "FactoryGenerated_0010_MeshInstance3D"
	node_112.visible = operands[651]
	node_112.layers = operands[652]
	node_112.mesh = operands[653]
	node_112.set("surface_material_override/0", material_18)
	node_112.set("surface_material_override/1", material_20)
	node_106.add_child(node_112)
	var node_113 := MeshInstance3D.new()
	node_113.name = "FactoryGenerated_0012_MeshInstance3D"
	node_113.visible = operands[654]
	node_113.layers = operands[655]
	node_113.mesh = operands[656]
	node_113.set("surface_material_override/0", material_18)
	node_113.set("surface_material_override/1", material_20)
	node_106.add_child(node_113)
	var node_114 := MeshInstance3D.new()
	node_114.name = "FactoryGenerated_0014_MeshInstance3D"
	node_114.visible = operands[657]
	node_114.layers = operands[658]
	node_114.mesh = operands[659]
	node_114.set("surface_material_override/0", material_18)
	node_114.set("surface_material_override/1", material_20)
	node_106.add_child(node_114)
	var node_115 := MeshInstance3D.new()
	node_115.name = "FactoryGenerated_0016_MeshInstance3D"
	node_115.visible = operands[660]
	node_115.layers = operands[661]
	node_115.mesh = operands[662]
	node_115.set("surface_material_override/0", material_18)
	node_115.set("surface_material_override/1", material_20)
	node_106.add_child(node_115)
	var node_116 := MeshInstance3D.new()
	node_116.name = "FactoryGenerated_0018_MeshInstance3D"
	node_116.visible = operands[663]
	node_116.layers = operands[664]
	node_116.mesh = operands[665]
	node_116.set("surface_material_override/0", material_18)
	node_116.set("surface_material_override/1", material_20)
	node_106.add_child(node_116)
	var node_117 := MeshInstance3D.new()
	node_117.name = "FactoryGenerated_0020_MeshInstance3D"
	node_117.visible = operands[666]
	node_117.layers = operands[667]
	node_117.mesh = operands[668]
	node_117.set("surface_material_override/0", material_18)
	node_117.set("surface_material_override/1", material_20)
	node_106.add_child(node_117)
	var node_118 := MeshInstance3D.new()
	node_118.name = "FactoryGenerated_0022_MeshInstance3D"
	node_118.visible = operands[669]
	node_118.layers = operands[670]
	node_118.mesh = operands[671]
	node_118.set("surface_material_override/0", material_18)
	node_118.set("surface_material_override/1", material_20)
	node_106.add_child(node_118)
	var node_119 := MeshInstance3D.new()
	node_119.name = "FactoryGenerated_0024_MeshInstance3D"
	node_119.visible = operands[672]
	node_119.layers = operands[673]
	node_119.mesh = operands[674]
	node_119.set("surface_material_override/0", material_18)
	node_119.set("surface_material_override/1", material_20)
	node_106.add_child(node_119)
	var node_120 := MeshInstance3D.new()
	node_120.name = "FactoryGenerated_0026_MeshInstance3D"
	node_120.visible = operands[675]
	node_120.layers = operands[676]
	node_120.mesh = operands[677]
	node_120.set("surface_material_override/0", material_18)
	node_120.set("surface_material_override/1", material_20)
	node_106.add_child(node_120)
	var node_121 := Node3D.new()
	node_121.name = "chunk_7"
	node_121.transform = operands[678]
	node_121.visible = operands[679]
	node_1.add_child(node_121)
	var node_122 := Node3D.new()
	node_122.name = "effect"
	node_121.add_child(node_122)
	var node_123 := Node3D.new()
	node_123.name = "Donor"
	node_122.add_child(node_123)
	var node_124 := MeshInstance3D.new()
	node_124.name = "FactoryGenerated_0000_MeshInstance3D"
	node_124.layers = operands[680]
	node_124.material_override = material_21
	node_124.mesh = operands[681]
	node_123.add_child(node_124)
	var node_125 := MeshInstance3D.new()
	node_125.name = "FactoryGenerated_0002_MeshInstance3D"
	node_125.transform = operands[682]
	node_125.layers = operands[683]
	node_125.material_override = material_22
	node_125.mesh = operands[684]
	node_123.add_child(node_125)
	var node_126 := MeshInstance3D.new()
	node_126.name = "FactoryGenerated_0004_MeshInstance3D"
	node_126.visible = operands[685]
	node_126.layers = operands[686]
	node_126.mesh = operands[687]
	node_126.set("surface_material_override/0", material_21)
	node_126.set("surface_material_override/1", material_23)
	node_123.add_child(node_126)
	var node_127 := MeshInstance3D.new()
	node_127.name = "FactoryGenerated_0006_MeshInstance3D"
	node_127.visible = operands[688]
	node_127.layers = operands[689]
	node_127.mesh = operands[690]
	node_127.set("surface_material_override/0", material_21)
	node_127.set("surface_material_override/1", material_23)
	node_123.add_child(node_127)
	var node_128 := MeshInstance3D.new()
	node_128.name = "FactoryGenerated_0008_MeshInstance3D"
	node_128.visible = operands[691]
	node_128.layers = operands[692]
	node_128.mesh = operands[693]
	node_128.set("surface_material_override/0", material_21)
	node_128.set("surface_material_override/1", material_23)
	node_123.add_child(node_128)
	var node_129 := MeshInstance3D.new()
	node_129.name = "FactoryGenerated_0010_MeshInstance3D"
	node_129.visible = operands[694]
	node_129.layers = operands[695]
	node_129.mesh = operands[696]
	node_129.set("surface_material_override/0", material_21)
	node_129.set("surface_material_override/1", material_23)
	node_123.add_child(node_129)
	var node_130 := MeshInstance3D.new()
	node_130.name = "FactoryGenerated_0012_MeshInstance3D"
	node_130.visible = operands[697]
	node_130.layers = operands[698]
	node_130.mesh = operands[699]
	node_130.set("surface_material_override/0", material_21)
	node_130.set("surface_material_override/1", material_23)
	node_123.add_child(node_130)
	var node_131 := MeshInstance3D.new()
	node_131.name = "FactoryGenerated_0014_MeshInstance3D"
	node_131.visible = operands[700]
	node_131.layers = operands[701]
	node_131.mesh = operands[702]
	node_131.set("surface_material_override/0", material_21)
	node_131.set("surface_material_override/1", material_23)
	node_123.add_child(node_131)
	var node_132 := MeshInstance3D.new()
	node_132.name = "FactoryGenerated_0016_MeshInstance3D"
	node_132.visible = operands[703]
	node_132.layers = operands[704]
	node_132.mesh = operands[705]
	node_132.set("surface_material_override/0", material_21)
	node_132.set("surface_material_override/1", material_23)
	node_123.add_child(node_132)
	var node_133 := MeshInstance3D.new()
	node_133.name = "FactoryGenerated_0018_MeshInstance3D"
	node_133.visible = operands[706]
	node_133.layers = operands[707]
	node_133.mesh = operands[708]
	node_133.set("surface_material_override/0", material_21)
	node_133.set("surface_material_override/1", material_23)
	node_123.add_child(node_133)
	var node_134 := MeshInstance3D.new()
	node_134.name = "FactoryGenerated_0020_MeshInstance3D"
	node_134.visible = operands[709]
	node_134.layers = operands[710]
	node_134.mesh = operands[711]
	node_134.set("surface_material_override/0", material_21)
	node_134.set("surface_material_override/1", material_23)
	node_123.add_child(node_134)
	var node_135 := MeshInstance3D.new()
	node_135.name = "FactoryGenerated_0022_MeshInstance3D"
	node_135.visible = operands[712]
	node_135.layers = operands[713]
	node_135.mesh = operands[714]
	node_135.set("surface_material_override/0", material_21)
	node_135.set("surface_material_override/1", material_23)
	node_123.add_child(node_135)
	var node_136 := MeshInstance3D.new()
	node_136.name = "FactoryGenerated_0024_MeshInstance3D"
	node_136.visible = operands[715]
	node_136.layers = operands[716]
	node_136.mesh = operands[717]
	node_136.set("surface_material_override/0", material_21)
	node_136.set("surface_material_override/1", material_23)
	node_123.add_child(node_136)
	var node_137 := MeshInstance3D.new()
	node_137.name = "FactoryGenerated_0026_MeshInstance3D"
	node_137.visible = operands[718]
	node_137.layers = operands[719]
	node_137.mesh = operands[720]
	node_137.set("surface_material_override/0", material_21)
	node_137.set("surface_material_override/1", material_23)
	node_123.add_child(node_137)
	var node_138 := Node3D.new()
	node_138.name = "chunk_8"
	node_138.transform = operands[721]
	node_1.add_child(node_138)
	var node_139 := Node3D.new()
	node_139.name = "effect"
	node_138.add_child(node_139)
	var node_140 := Node3D.new()
	node_140.name = "Donor"
	node_139.add_child(node_140)
	var node_141 := MeshInstance3D.new()
	node_141.name = "FactoryGenerated_0000_MeshInstance3D"
	node_141.layers = operands[722]
	node_141.material_override = material_24
	node_141.mesh = operands[723]
	node_140.add_child(node_141)
	var node_142 := MeshInstance3D.new()
	node_142.name = "FactoryGenerated_0002_MeshInstance3D"
	node_142.transform = operands[724]
	node_142.layers = operands[725]
	node_142.material_override = material_25
	node_142.mesh = operands[726]
	node_140.add_child(node_142)
	var node_143 := MeshInstance3D.new()
	node_143.name = "FactoryGenerated_0004_MeshInstance3D"
	node_143.visible = operands[727]
	node_143.layers = operands[728]
	node_143.mesh = operands[729]
	node_143.set("surface_material_override/0", material_24)
	node_143.set("surface_material_override/1", material_26)
	node_140.add_child(node_143)
	var node_144 := MeshInstance3D.new()
	node_144.name = "FactoryGenerated_0006_MeshInstance3D"
	node_144.visible = operands[730]
	node_144.layers = operands[731]
	node_144.mesh = operands[732]
	node_144.set("surface_material_override/0", material_24)
	node_144.set("surface_material_override/1", material_26)
	node_140.add_child(node_144)
	var node_145 := MeshInstance3D.new()
	node_145.name = "FactoryGenerated_0008_MeshInstance3D"
	node_145.visible = operands[733]
	node_145.layers = operands[734]
	node_145.mesh = operands[735]
	node_145.set("surface_material_override/0", material_24)
	node_145.set("surface_material_override/1", material_26)
	node_140.add_child(node_145)
	var node_146 := MeshInstance3D.new()
	node_146.name = "FactoryGenerated_0010_MeshInstance3D"
	node_146.visible = operands[736]
	node_146.layers = operands[737]
	node_146.mesh = operands[738]
	node_146.set("surface_material_override/0", material_24)
	node_146.set("surface_material_override/1", material_26)
	node_140.add_child(node_146)
	var node_147 := MeshInstance3D.new()
	node_147.name = "FactoryGenerated_0012_MeshInstance3D"
	node_147.visible = operands[739]
	node_147.layers = operands[740]
	node_147.mesh = operands[741]
	node_147.set("surface_material_override/0", material_24)
	node_147.set("surface_material_override/1", material_26)
	node_140.add_child(node_147)
	var node_148 := MeshInstance3D.new()
	node_148.name = "FactoryGenerated_0014_MeshInstance3D"
	node_148.visible = operands[742]
	node_148.layers = operands[743]
	node_148.mesh = operands[744]
	node_148.set("surface_material_override/0", material_24)
	node_148.set("surface_material_override/1", material_26)
	node_140.add_child(node_148)
	var node_149 := MeshInstance3D.new()
	node_149.name = "FactoryGenerated_0016_MeshInstance3D"
	node_149.visible = operands[745]
	node_149.layers = operands[746]
	node_149.mesh = operands[747]
	node_149.set("surface_material_override/0", material_24)
	node_149.set("surface_material_override/1", material_26)
	node_140.add_child(node_149)
	var node_150 := MeshInstance3D.new()
	node_150.name = "FactoryGenerated_0018_MeshInstance3D"
	node_150.visible = operands[748]
	node_150.layers = operands[749]
	node_150.mesh = operands[750]
	node_150.set("surface_material_override/0", material_24)
	node_150.set("surface_material_override/1", material_26)
	node_140.add_child(node_150)
	var node_151 := MeshInstance3D.new()
	node_151.name = "FactoryGenerated_0020_MeshInstance3D"
	node_151.visible = operands[751]
	node_151.layers = operands[752]
	node_151.mesh = operands[753]
	node_151.set("surface_material_override/0", material_24)
	node_151.set("surface_material_override/1", material_26)
	node_140.add_child(node_151)
	var node_152 := MeshInstance3D.new()
	node_152.name = "FactoryGenerated_0022_MeshInstance3D"
	node_152.visible = operands[754]
	node_152.layers = operands[755]
	node_152.mesh = operands[756]
	node_152.set("surface_material_override/0", material_24)
	node_152.set("surface_material_override/1", material_26)
	node_140.add_child(node_152)
	var node_153 := MeshInstance3D.new()
	node_153.name = "FactoryGenerated_0024_MeshInstance3D"
	node_153.visible = operands[757]
	node_153.layers = operands[758]
	node_153.mesh = operands[759]
	node_153.set("surface_material_override/0", material_24)
	node_153.set("surface_material_override/1", material_26)
	node_140.add_child(node_153)
	var node_154 := MeshInstance3D.new()
	node_154.name = "FactoryGenerated_0026_MeshInstance3D"
	node_154.visible = operands[760]
	node_154.layers = operands[761]
	node_154.mesh = operands[762]
	node_154.set("surface_material_override/0", material_24)
	node_154.set("surface_material_override/1", material_26)
	node_140.add_child(node_154)
	var node_155 := Node3D.new()
	node_155.name = "chunk_9"
	node_155.transform = operands[763]
	node_155.visible = operands[764]
	node_1.add_child(node_155)
	var node_156 := Node3D.new()
	node_156.name = "effect"
	node_155.add_child(node_156)
	var node_157 := Node3D.new()
	node_157.name = "Donor"
	node_156.add_child(node_157)
	var node_158 := MeshInstance3D.new()
	node_158.name = "FactoryGenerated_0000_MeshInstance3D"
	node_158.layers = operands[765]
	node_158.material_override = material_27
	node_158.mesh = operands[766]
	node_157.add_child(node_158)
	var node_159 := MeshInstance3D.new()
	node_159.name = "FactoryGenerated_0002_MeshInstance3D"
	node_159.transform = operands[767]
	node_159.layers = operands[768]
	node_159.material_override = material_28
	node_159.mesh = operands[769]
	node_157.add_child(node_159)
	var node_160 := MeshInstance3D.new()
	node_160.name = "FactoryGenerated_0004_MeshInstance3D"
	node_160.visible = operands[770]
	node_160.layers = operands[771]
	node_160.mesh = operands[772]
	node_160.set("surface_material_override/0", material_27)
	node_160.set("surface_material_override/1", material_29)
	node_157.add_child(node_160)
	var node_161 := MeshInstance3D.new()
	node_161.name = "FactoryGenerated_0006_MeshInstance3D"
	node_161.visible = operands[773]
	node_161.layers = operands[774]
	node_161.mesh = operands[775]
	node_161.set("surface_material_override/0", material_27)
	node_161.set("surface_material_override/1", material_29)
	node_157.add_child(node_161)
	var node_162 := MeshInstance3D.new()
	node_162.name = "FactoryGenerated_0008_MeshInstance3D"
	node_162.visible = operands[776]
	node_162.layers = operands[777]
	node_162.mesh = operands[778]
	node_162.set("surface_material_override/0", material_27)
	node_162.set("surface_material_override/1", material_29)
	node_157.add_child(node_162)
	var node_163 := MeshInstance3D.new()
	node_163.name = "FactoryGenerated_0010_MeshInstance3D"
	node_163.visible = operands[779]
	node_163.layers = operands[780]
	node_163.mesh = operands[781]
	node_163.set("surface_material_override/0", material_27)
	node_163.set("surface_material_override/1", material_29)
	node_157.add_child(node_163)
	var node_164 := MeshInstance3D.new()
	node_164.name = "FactoryGenerated_0012_MeshInstance3D"
	node_164.visible = operands[782]
	node_164.layers = operands[783]
	node_164.mesh = operands[784]
	node_164.set("surface_material_override/0", material_27)
	node_164.set("surface_material_override/1", material_29)
	node_157.add_child(node_164)
	var node_165 := MeshInstance3D.new()
	node_165.name = "FactoryGenerated_0014_MeshInstance3D"
	node_165.visible = operands[785]
	node_165.layers = operands[786]
	node_165.mesh = operands[787]
	node_165.set("surface_material_override/0", material_27)
	node_165.set("surface_material_override/1", material_29)
	node_157.add_child(node_165)
	var node_166 := MeshInstance3D.new()
	node_166.name = "FactoryGenerated_0016_MeshInstance3D"
	node_166.visible = operands[788]
	node_166.layers = operands[789]
	node_166.mesh = operands[790]
	node_166.set("surface_material_override/0", material_27)
	node_166.set("surface_material_override/1", material_29)
	node_157.add_child(node_166)
	var node_167 := MeshInstance3D.new()
	node_167.name = "FactoryGenerated_0018_MeshInstance3D"
	node_167.visible = operands[791]
	node_167.layers = operands[792]
	node_167.mesh = operands[793]
	node_167.set("surface_material_override/0", material_27)
	node_167.set("surface_material_override/1", material_29)
	node_157.add_child(node_167)
	var node_168 := MeshInstance3D.new()
	node_168.name = "FactoryGenerated_0020_MeshInstance3D"
	node_168.visible = operands[794]
	node_168.layers = operands[795]
	node_168.mesh = operands[796]
	node_168.set("surface_material_override/0", material_27)
	node_168.set("surface_material_override/1", material_29)
	node_157.add_child(node_168)
	var node_169 := MeshInstance3D.new()
	node_169.name = "FactoryGenerated_0022_MeshInstance3D"
	node_169.visible = operands[797]
	node_169.layers = operands[798]
	node_169.mesh = operands[799]
	node_169.set("surface_material_override/0", material_27)
	node_169.set("surface_material_override/1", material_29)
	node_157.add_child(node_169)
	var node_170 := MeshInstance3D.new()
	node_170.name = "FactoryGenerated_0024_MeshInstance3D"
	node_170.visible = operands[800]
	node_170.layers = operands[801]
	node_170.mesh = operands[802]
	node_170.set("surface_material_override/0", material_27)
	node_170.set("surface_material_override/1", material_29)
	node_157.add_child(node_170)
	var node_171 := MeshInstance3D.new()
	node_171.name = "FactoryGenerated_0026_MeshInstance3D"
	node_171.visible = operands[803]
	node_171.layers = operands[804]
	node_171.mesh = operands[805]
	node_171.set("surface_material_override/0", material_27)
	node_171.set("surface_material_override/1", material_29)
	node_157.add_child(node_171)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"root": node_0, "geometry": [node_5, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_6, node_22, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_23, node_39, node_41, node_42, node_43, node_44, node_45, node_46, node_47, node_48, node_49, node_50, node_51, node_52, node_40, node_56, node_58, node_59, node_60, node_61, node_62, node_63, node_64, node_65, node_66, node_67, node_68, node_69, node_57, node_73, node_75, node_76, node_77, node_78, node_79, node_80, node_81, node_82, node_83, node_84, node_85, node_86, node_74, node_90, node_92, node_93, node_94, node_95, node_96, node_97, node_98, node_99, node_100, node_101, node_102, node_103, node_91, node_107, node_109, node_110, node_111, node_112, node_113, node_114, node_115, node_116, node_117, node_118, node_119, node_120, node_108, node_124, node_126, node_127, node_128, node_129, node_130, node_131, node_132, node_133, node_134, node_135, node_136, node_137, node_125, node_141, node_143, node_144, node_145, node_146, node_147, node_148, node_149, node_150, node_151, node_152, node_153, node_154, node_142, node_158, node_160, node_161, node_162, node_163, node_164, node_165, node_166, node_167, node_168, node_169, node_170, node_171, node_159, node_2, node_19, node_36, node_53, node_70, node_87, node_104, node_121, node_138, node_155], "materials": [node_5.material_override, node_6.material_override, node_7.get_surface_override_material(1), node_22.material_override, node_23.material_override, node_24.get_surface_override_material(1), node_39.material_override, node_40.material_override, node_41.get_surface_override_material(1), node_56.material_override, node_57.material_override, node_58.get_surface_override_material(1), node_73.material_override, node_74.material_override, node_75.get_surface_override_material(1), node_90.material_override, node_91.material_override, node_92.get_surface_override_material(1), node_107.material_override, node_108.material_override, node_109.get_surface_override_material(1), node_124.material_override, node_125.material_override, node_126.get_surface_override_material(1), node_141.material_override, node_142.material_override, node_143.get_surface_override_material(1), node_158.material_override, node_159.material_override, node_160.get_surface_override_material(1)], "cohorts": []}
