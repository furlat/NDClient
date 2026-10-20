extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("factory_world_to_source", operands[1])
	material_0.set_shader_parameter("wall_clock", operands[2])
	material_0.set_shader_parameter("opacity", operands[3])
	material_0.set_shader_parameter("fracture", operands[4])
	material_0.set_shader_parameter("actor_ground", operands[5])
	material_0.set_shader_parameter("camera_ground", operands[6])
	material_0.set_shader_parameter("foreground", operands[7])
	material_0.set_shader_parameter("fresnelpower", operands[8])
	material_0.set_shader_parameter("AddTexture", operands[9])
	material_0.set_shader_parameter("BreakFactorGlobal", operands[10])
	material_0.set_shader_parameter("Texture_add2_offset", operands[11])
	material_0.set_shader_parameter("AddTexture2", operands[12])
	material_0.set_shader_parameter("Details_scale", operands[13])
	material_0.set_shader_parameter("Details_speed", operands[14])
	material_0.set_shader_parameter("DetailsTexture", operands[15])
	material_0.set_shader_parameter("Color1DGradient", operands[16])
	material_0.set_shader_parameter("ColorIntensity", operands[17])
	material_0.set_meta("factory_prepared_shader", operands[18])
	material_0.set_meta("factory_opacity_prepared_shader", operands[19])
	material_0.set_meta("factory_world_space_uniform", operands[20])
	material_0.set_meta("factory_recorded_source_space_frozen", operands[21])
	material_0.set_meta("factory_clock_names", operands[22])
	material_0.set_meta("factory_clock_pool_required", operands[23])
	var material_1 := ShaderMaterial.new()
	material_1.shader = operands[24]
	material_1.set_shader_parameter("factory_world_to_source", operands[25])
	material_1.set_shader_parameter("wall_clock", operands[26])
	material_1.set_shader_parameter("opacity", operands[27])
	material_1.set_shader_parameter("fracture", operands[28])
	material_1.set_shader_parameter("actor_ground", operands[29])
	material_1.set_shader_parameter("camera_ground", operands[30])
	material_1.set_shader_parameter("foreground", operands[31])
	material_1.set_shader_parameter("fresnelpower", operands[32])
	material_1.set_shader_parameter("AddTexture", operands[33])
	material_1.set_shader_parameter("BreakFactorGlobal", operands[34])
	material_1.set_shader_parameter("Texture_add2_offset", operands[35])
	material_1.set_shader_parameter("AddTexture2", operands[36])
	material_1.set_shader_parameter("Details_scale", operands[37])
	material_1.set_shader_parameter("Details_speed", operands[38])
	material_1.set_shader_parameter("DetailsTexture", operands[39])
	material_1.set_shader_parameter("Color1DGradient", operands[40])
	material_1.set_shader_parameter("ColorIntensity", operands[41])
	material_1.set_meta("factory_prepared_shader", operands[42])
	material_1.set_meta("factory_opacity_prepared_shader", operands[43])
	material_1.set_meta("factory_world_space_uniform", operands[44])
	material_1.set_meta("factory_recorded_source_space_frozen", operands[45])
	material_1.set_meta("factory_clock_names", operands[46])
	material_1.set_meta("factory_clock_pool_required", operands[47])
	var material_2 := ShaderMaterial.new()
	material_2.shader = operands[48]
	material_2.set_shader_parameter("factory_world_to_source", operands[49])
	material_2.set_shader_parameter("wall_clock", operands[50])
	material_2.set_shader_parameter("opacity", operands[51])
	material_2.set_shader_parameter("fracture", operands[52])
	material_2.set_shader_parameter("actor_ground", operands[53])
	material_2.set_shader_parameter("camera_ground", operands[54])
	material_2.set_shader_parameter("foreground", operands[55])
	material_2.set_shader_parameter("fresnelpower", operands[56])
	material_2.set_shader_parameter("AddTexture", operands[57])
	material_2.set_shader_parameter("BreakFactorGlobal", operands[58])
	material_2.set_shader_parameter("Texture_add2_offset", operands[59])
	material_2.set_shader_parameter("AddTexture2", operands[60])
	material_2.set_shader_parameter("Details_scale", operands[61])
	material_2.set_shader_parameter("Details_speed", operands[62])
	material_2.set_shader_parameter("DetailsTexture", operands[63])
	material_2.set_shader_parameter("Color1DGradient", operands[64])
	material_2.set_shader_parameter("ColorIntensity", operands[65])
	material_2.set_meta("factory_prepared_shader", operands[66])
	material_2.set_meta("factory_opacity_prepared_shader", operands[67])
	material_2.set_meta("factory_world_space_uniform", operands[68])
	material_2.set_meta("factory_recorded_source_space_frozen", operands[69])
	material_2.set_meta("factory_clock_names", operands[70])
	material_2.set_meta("factory_clock_pool_required", operands[71])
	var material_3 := ShaderMaterial.new()
	material_3.shader = operands[72]
	material_3.set_shader_parameter("factory_world_to_source", operands[73])
	material_3.set_shader_parameter("wall_clock", operands[74])
	material_3.set_shader_parameter("opacity", operands[75])
	material_3.set_shader_parameter("fracture", operands[76])
	material_3.set_shader_parameter("actor_ground", operands[77])
	material_3.set_shader_parameter("camera_ground", operands[78])
	material_3.set_shader_parameter("foreground", operands[79])
	material_3.set_shader_parameter("fresnelpower", operands[80])
	material_3.set_shader_parameter("AddTexture", operands[81])
	material_3.set_shader_parameter("BreakFactorGlobal", operands[82])
	material_3.set_shader_parameter("Texture_add2_offset", operands[83])
	material_3.set_shader_parameter("AddTexture2", operands[84])
	material_3.set_shader_parameter("Details_scale", operands[85])
	material_3.set_shader_parameter("Details_speed", operands[86])
	material_3.set_shader_parameter("DetailsTexture", operands[87])
	material_3.set_shader_parameter("Color1DGradient", operands[88])
	material_3.set_shader_parameter("ColorIntensity", operands[89])
	material_3.set_meta("factory_prepared_shader", operands[90])
	material_3.set_meta("factory_opacity_prepared_shader", operands[91])
	material_3.set_meta("factory_world_space_uniform", operands[92])
	material_3.set_meta("factory_recorded_source_space_frozen", operands[93])
	material_3.set_meta("factory_clock_names", operands[94])
	material_3.set_meta("factory_clock_pool_required", operands[95])
	var material_4 := ShaderMaterial.new()
	material_4.shader = operands[96]
	material_4.set_shader_parameter("factory_world_to_source", operands[97])
	material_4.set_shader_parameter("wall_clock", operands[98])
	material_4.set_shader_parameter("opacity", operands[99])
	material_4.set_shader_parameter("fracture", operands[100])
	material_4.set_shader_parameter("actor_ground", operands[101])
	material_4.set_shader_parameter("camera_ground", operands[102])
	material_4.set_shader_parameter("foreground", operands[103])
	material_4.set_shader_parameter("fresnelpower", operands[104])
	material_4.set_shader_parameter("AddTexture", operands[105])
	material_4.set_shader_parameter("BreakFactorGlobal", operands[106])
	material_4.set_shader_parameter("Texture_add2_offset", operands[107])
	material_4.set_shader_parameter("AddTexture2", operands[108])
	material_4.set_shader_parameter("Details_scale", operands[109])
	material_4.set_shader_parameter("Details_speed", operands[110])
	material_4.set_shader_parameter("DetailsTexture", operands[111])
	material_4.set_shader_parameter("Color1DGradient", operands[112])
	material_4.set_shader_parameter("ColorIntensity", operands[113])
	material_4.set_meta("factory_prepared_shader", operands[114])
	material_4.set_meta("factory_opacity_prepared_shader", operands[115])
	material_4.set_meta("factory_world_space_uniform", operands[116])
	material_4.set_meta("factory_recorded_source_space_frozen", operands[117])
	material_4.set_meta("factory_clock_names", operands[118])
	material_4.set_meta("factory_clock_pool_required", operands[119])
	var material_5 := ShaderMaterial.new()
	material_5.shader = operands[120]
	material_5.set_shader_parameter("factory_world_to_source", operands[121])
	material_5.set_shader_parameter("wall_clock", operands[122])
	material_5.set_shader_parameter("opacity", operands[123])
	material_5.set_shader_parameter("fracture", operands[124])
	material_5.set_shader_parameter("actor_ground", operands[125])
	material_5.set_shader_parameter("camera_ground", operands[126])
	material_5.set_shader_parameter("foreground", operands[127])
	material_5.set_shader_parameter("fresnelpower", operands[128])
	material_5.set_shader_parameter("AddTexture", operands[129])
	material_5.set_shader_parameter("BreakFactorGlobal", operands[130])
	material_5.set_shader_parameter("Texture_add2_offset", operands[131])
	material_5.set_shader_parameter("AddTexture2", operands[132])
	material_5.set_shader_parameter("Details_scale", operands[133])
	material_5.set_shader_parameter("Details_speed", operands[134])
	material_5.set_shader_parameter("DetailsTexture", operands[135])
	material_5.set_shader_parameter("Color1DGradient", operands[136])
	material_5.set_shader_parameter("ColorIntensity", operands[137])
	material_5.set_meta("factory_prepared_shader", operands[138])
	material_5.set_meta("factory_opacity_prepared_shader", operands[139])
	material_5.set_meta("factory_world_space_uniform", operands[140])
	material_5.set_meta("factory_recorded_source_space_frozen", operands[141])
	material_5.set_meta("factory_clock_names", operands[142])
	material_5.set_meta("factory_clock_pool_required", operands[143])
	var material_6 := ShaderMaterial.new()
	material_6.shader = operands[144]
	material_6.set_shader_parameter("factory_world_to_source", operands[145])
	material_6.set_shader_parameter("wall_clock", operands[146])
	material_6.set_shader_parameter("opacity", operands[147])
	material_6.set_shader_parameter("fracture", operands[148])
	material_6.set_shader_parameter("actor_ground", operands[149])
	material_6.set_shader_parameter("camera_ground", operands[150])
	material_6.set_shader_parameter("foreground", operands[151])
	material_6.set_shader_parameter("fresnelpower", operands[152])
	material_6.set_shader_parameter("AddTexture", operands[153])
	material_6.set_shader_parameter("BreakFactorGlobal", operands[154])
	material_6.set_shader_parameter("Texture_add2_offset", operands[155])
	material_6.set_shader_parameter("AddTexture2", operands[156])
	material_6.set_shader_parameter("Details_scale", operands[157])
	material_6.set_shader_parameter("Details_speed", operands[158])
	material_6.set_shader_parameter("DetailsTexture", operands[159])
	material_6.set_shader_parameter("Color1DGradient", operands[160])
	material_6.set_shader_parameter("ColorIntensity", operands[161])
	material_6.set_meta("factory_prepared_shader", operands[162])
	material_6.set_meta("factory_opacity_prepared_shader", operands[163])
	material_6.set_meta("factory_world_space_uniform", operands[164])
	material_6.set_meta("factory_recorded_source_space_frozen", operands[165])
	material_6.set_meta("factory_clock_names", operands[166])
	material_6.set_meta("factory_clock_pool_required", operands[167])
	var material_7 := ShaderMaterial.new()
	material_7.shader = operands[168]
	material_7.set_shader_parameter("factory_world_to_source", operands[169])
	material_7.set_shader_parameter("wall_clock", operands[170])
	material_7.set_shader_parameter("opacity", operands[171])
	material_7.set_shader_parameter("fracture", operands[172])
	material_7.set_shader_parameter("actor_ground", operands[173])
	material_7.set_shader_parameter("camera_ground", operands[174])
	material_7.set_shader_parameter("foreground", operands[175])
	material_7.set_shader_parameter("fresnelpower", operands[176])
	material_7.set_shader_parameter("AddTexture", operands[177])
	material_7.set_shader_parameter("BreakFactorGlobal", operands[178])
	material_7.set_shader_parameter("Texture_add2_offset", operands[179])
	material_7.set_shader_parameter("AddTexture2", operands[180])
	material_7.set_shader_parameter("Details_scale", operands[181])
	material_7.set_shader_parameter("Details_speed", operands[182])
	material_7.set_shader_parameter("DetailsTexture", operands[183])
	material_7.set_shader_parameter("Color1DGradient", operands[184])
	material_7.set_shader_parameter("ColorIntensity", operands[185])
	material_7.set_meta("factory_prepared_shader", operands[186])
	material_7.set_meta("factory_opacity_prepared_shader", operands[187])
	material_7.set_meta("factory_world_space_uniform", operands[188])
	material_7.set_meta("factory_recorded_source_space_frozen", operands[189])
	material_7.set_meta("factory_clock_names", operands[190])
	material_7.set_meta("factory_clock_pool_required", operands[191])
	var material_8 := ShaderMaterial.new()
	material_8.shader = operands[192]
	material_8.set_shader_parameter("factory_world_to_source", operands[193])
	material_8.set_shader_parameter("wall_clock", operands[194])
	material_8.set_shader_parameter("opacity", operands[195])
	material_8.set_shader_parameter("fracture", operands[196])
	material_8.set_shader_parameter("actor_ground", operands[197])
	material_8.set_shader_parameter("camera_ground", operands[198])
	material_8.set_shader_parameter("foreground", operands[199])
	material_8.set_shader_parameter("fresnelpower", operands[200])
	material_8.set_shader_parameter("AddTexture", operands[201])
	material_8.set_shader_parameter("BreakFactorGlobal", operands[202])
	material_8.set_shader_parameter("Texture_add2_offset", operands[203])
	material_8.set_shader_parameter("AddTexture2", operands[204])
	material_8.set_shader_parameter("Details_scale", operands[205])
	material_8.set_shader_parameter("Details_speed", operands[206])
	material_8.set_shader_parameter("DetailsTexture", operands[207])
	material_8.set_shader_parameter("Color1DGradient", operands[208])
	material_8.set_shader_parameter("ColorIntensity", operands[209])
	material_8.set_meta("factory_prepared_shader", operands[210])
	material_8.set_meta("factory_opacity_prepared_shader", operands[211])
	material_8.set_meta("factory_world_space_uniform", operands[212])
	material_8.set_meta("factory_recorded_source_space_frozen", operands[213])
	material_8.set_meta("factory_clock_names", operands[214])
	material_8.set_meta("factory_clock_pool_required", operands[215])
	var material_9 := ShaderMaterial.new()
	material_9.shader = operands[216]
	material_9.set_shader_parameter("factory_world_to_source", operands[217])
	material_9.set_shader_parameter("wall_clock", operands[218])
	material_9.set_shader_parameter("opacity", operands[219])
	material_9.set_shader_parameter("fracture", operands[220])
	material_9.set_shader_parameter("actor_ground", operands[221])
	material_9.set_shader_parameter("camera_ground", operands[222])
	material_9.set_shader_parameter("foreground", operands[223])
	material_9.set_shader_parameter("fresnelpower", operands[224])
	material_9.set_shader_parameter("AddTexture", operands[225])
	material_9.set_shader_parameter("BreakFactorGlobal", operands[226])
	material_9.set_shader_parameter("Texture_add2_offset", operands[227])
	material_9.set_shader_parameter("AddTexture2", operands[228])
	material_9.set_shader_parameter("Details_scale", operands[229])
	material_9.set_shader_parameter("Details_speed", operands[230])
	material_9.set_shader_parameter("DetailsTexture", operands[231])
	material_9.set_shader_parameter("Color1DGradient", operands[232])
	material_9.set_shader_parameter("ColorIntensity", operands[233])
	material_9.set_meta("factory_prepared_shader", operands[234])
	material_9.set_meta("factory_opacity_prepared_shader", operands[235])
	material_9.set_meta("factory_world_space_uniform", operands[236])
	material_9.set_meta("factory_recorded_source_space_frozen", operands[237])
	material_9.set_meta("factory_clock_names", operands[238])
	material_9.set_meta("factory_clock_pool_required", operands[239])
	var material_10 := ShaderMaterial.new()
	material_10.shader = operands[240]
	material_10.set_shader_parameter("factory_world_to_source", operands[241])
	material_10.set_shader_parameter("wall_clock", operands[242])
	material_10.set_shader_parameter("opacity", operands[243])
	material_10.set_shader_parameter("fracture", operands[244])
	material_10.set_shader_parameter("actor_ground", operands[245])
	material_10.set_shader_parameter("camera_ground", operands[246])
	material_10.set_shader_parameter("foreground", operands[247])
	material_10.set_shader_parameter("fresnelpower", operands[248])
	material_10.set_shader_parameter("AddTexture", operands[249])
	material_10.set_shader_parameter("BreakFactorGlobal", operands[250])
	material_10.set_shader_parameter("Texture_add2_offset", operands[251])
	material_10.set_shader_parameter("AddTexture2", operands[252])
	material_10.set_shader_parameter("Details_scale", operands[253])
	material_10.set_shader_parameter("Details_speed", operands[254])
	material_10.set_shader_parameter("DetailsTexture", operands[255])
	material_10.set_shader_parameter("Color1DGradient", operands[256])
	material_10.set_shader_parameter("ColorIntensity", operands[257])
	material_10.set_meta("factory_prepared_shader", operands[258])
	material_10.set_meta("factory_opacity_prepared_shader", operands[259])
	material_10.set_meta("factory_world_space_uniform", operands[260])
	material_10.set_meta("factory_recorded_source_space_frozen", operands[261])
	material_10.set_meta("factory_clock_names", operands[262])
	material_10.set_meta("factory_clock_pool_required", operands[263])
	var material_11 := ShaderMaterial.new()
	material_11.shader = operands[264]
	material_11.set_shader_parameter("factory_world_to_source", operands[265])
	material_11.set_shader_parameter("wall_clock", operands[266])
	material_11.set_shader_parameter("opacity", operands[267])
	material_11.set_shader_parameter("fracture", operands[268])
	material_11.set_shader_parameter("actor_ground", operands[269])
	material_11.set_shader_parameter("camera_ground", operands[270])
	material_11.set_shader_parameter("foreground", operands[271])
	material_11.set_shader_parameter("fresnelpower", operands[272])
	material_11.set_shader_parameter("AddTexture", operands[273])
	material_11.set_shader_parameter("BreakFactorGlobal", operands[274])
	material_11.set_shader_parameter("Texture_add2_offset", operands[275])
	material_11.set_shader_parameter("AddTexture2", operands[276])
	material_11.set_shader_parameter("Details_scale", operands[277])
	material_11.set_shader_parameter("Details_speed", operands[278])
	material_11.set_shader_parameter("DetailsTexture", operands[279])
	material_11.set_shader_parameter("Color1DGradient", operands[280])
	material_11.set_shader_parameter("ColorIntensity", operands[281])
	material_11.set_meta("factory_prepared_shader", operands[282])
	material_11.set_meta("factory_opacity_prepared_shader", operands[283])
	material_11.set_meta("factory_world_space_uniform", operands[284])
	material_11.set_meta("factory_recorded_source_space_frozen", operands[285])
	material_11.set_meta("factory_clock_names", operands[286])
	material_11.set_meta("factory_clock_pool_required", operands[287])
	var material_12 := ShaderMaterial.new()
	material_12.shader = operands[288]
	material_12.set_shader_parameter("factory_world_to_source", operands[289])
	material_12.set_shader_parameter("wall_clock", operands[290])
	material_12.set_shader_parameter("opacity", operands[291])
	material_12.set_shader_parameter("fracture", operands[292])
	material_12.set_shader_parameter("actor_ground", operands[293])
	material_12.set_shader_parameter("camera_ground", operands[294])
	material_12.set_shader_parameter("foreground", operands[295])
	material_12.set_shader_parameter("fresnelpower", operands[296])
	material_12.set_shader_parameter("AddTexture", operands[297])
	material_12.set_shader_parameter("BreakFactorGlobal", operands[298])
	material_12.set_shader_parameter("Texture_add2_offset", operands[299])
	material_12.set_shader_parameter("AddTexture2", operands[300])
	material_12.set_shader_parameter("Details_scale", operands[301])
	material_12.set_shader_parameter("Details_speed", operands[302])
	material_12.set_shader_parameter("DetailsTexture", operands[303])
	material_12.set_shader_parameter("Color1DGradient", operands[304])
	material_12.set_shader_parameter("ColorIntensity", operands[305])
	material_12.set_meta("factory_prepared_shader", operands[306])
	material_12.set_meta("factory_opacity_prepared_shader", operands[307])
	material_12.set_meta("factory_world_space_uniform", operands[308])
	material_12.set_meta("factory_recorded_source_space_frozen", operands[309])
	material_12.set_meta("factory_clock_names", operands[310])
	material_12.set_meta("factory_clock_pool_required", operands[311])
	var material_13 := ShaderMaterial.new()
	material_13.shader = operands[312]
	material_13.set_shader_parameter("factory_world_to_source", operands[313])
	material_13.set_shader_parameter("wall_clock", operands[314])
	material_13.set_shader_parameter("opacity", operands[315])
	material_13.set_shader_parameter("fracture", operands[316])
	material_13.set_shader_parameter("actor_ground", operands[317])
	material_13.set_shader_parameter("camera_ground", operands[318])
	material_13.set_shader_parameter("foreground", operands[319])
	material_13.set_shader_parameter("fresnelpower", operands[320])
	material_13.set_shader_parameter("AddTexture", operands[321])
	material_13.set_shader_parameter("BreakFactorGlobal", operands[322])
	material_13.set_shader_parameter("Texture_add2_offset", operands[323])
	material_13.set_shader_parameter("AddTexture2", operands[324])
	material_13.set_shader_parameter("Details_scale", operands[325])
	material_13.set_shader_parameter("Details_speed", operands[326])
	material_13.set_shader_parameter("DetailsTexture", operands[327])
	material_13.set_shader_parameter("Color1DGradient", operands[328])
	material_13.set_shader_parameter("ColorIntensity", operands[329])
	material_13.set_meta("factory_prepared_shader", operands[330])
	material_13.set_meta("factory_opacity_prepared_shader", operands[331])
	material_13.set_meta("factory_world_space_uniform", operands[332])
	material_13.set_meta("factory_recorded_source_space_frozen", operands[333])
	material_13.set_meta("factory_clock_names", operands[334])
	material_13.set_meta("factory_clock_pool_required", operands[335])
	var material_14 := ShaderMaterial.new()
	material_14.shader = operands[336]
	material_14.set_shader_parameter("factory_world_to_source", operands[337])
	material_14.set_shader_parameter("wall_clock", operands[338])
	material_14.set_shader_parameter("opacity", operands[339])
	material_14.set_shader_parameter("fracture", operands[340])
	material_14.set_shader_parameter("actor_ground", operands[341])
	material_14.set_shader_parameter("camera_ground", operands[342])
	material_14.set_shader_parameter("foreground", operands[343])
	material_14.set_shader_parameter("fresnelpower", operands[344])
	material_14.set_shader_parameter("AddTexture", operands[345])
	material_14.set_shader_parameter("BreakFactorGlobal", operands[346])
	material_14.set_shader_parameter("Texture_add2_offset", operands[347])
	material_14.set_shader_parameter("AddTexture2", operands[348])
	material_14.set_shader_parameter("Details_scale", operands[349])
	material_14.set_shader_parameter("Details_speed", operands[350])
	material_14.set_shader_parameter("DetailsTexture", operands[351])
	material_14.set_shader_parameter("Color1DGradient", operands[352])
	material_14.set_shader_parameter("ColorIntensity", operands[353])
	material_14.set_meta("factory_prepared_shader", operands[354])
	material_14.set_meta("factory_opacity_prepared_shader", operands[355])
	material_14.set_meta("factory_world_space_uniform", operands[356])
	material_14.set_meta("factory_recorded_source_space_frozen", operands[357])
	material_14.set_meta("factory_clock_names", operands[358])
	material_14.set_meta("factory_clock_pool_required", operands[359])
	var material_15 := ShaderMaterial.new()
	material_15.shader = operands[360]
	material_15.set_shader_parameter("factory_world_to_source", operands[361])
	material_15.set_shader_parameter("wall_clock", operands[362])
	material_15.set_shader_parameter("opacity", operands[363])
	material_15.set_shader_parameter("fracture", operands[364])
	material_15.set_shader_parameter("actor_ground", operands[365])
	material_15.set_shader_parameter("camera_ground", operands[366])
	material_15.set_shader_parameter("foreground", operands[367])
	material_15.set_shader_parameter("fresnelpower", operands[368])
	material_15.set_shader_parameter("AddTexture", operands[369])
	material_15.set_shader_parameter("BreakFactorGlobal", operands[370])
	material_15.set_shader_parameter("Texture_add2_offset", operands[371])
	material_15.set_shader_parameter("AddTexture2", operands[372])
	material_15.set_shader_parameter("Details_scale", operands[373])
	material_15.set_shader_parameter("Details_speed", operands[374])
	material_15.set_shader_parameter("DetailsTexture", operands[375])
	material_15.set_shader_parameter("Color1DGradient", operands[376])
	material_15.set_shader_parameter("ColorIntensity", operands[377])
	material_15.set_meta("factory_prepared_shader", operands[378])
	material_15.set_meta("factory_opacity_prepared_shader", operands[379])
	material_15.set_meta("factory_world_space_uniform", operands[380])
	material_15.set_meta("factory_recorded_source_space_frozen", operands[381])
	material_15.set_meta("factory_clock_names", operands[382])
	material_15.set_meta("factory_clock_pool_required", operands[383])
	var material_16 := ShaderMaterial.new()
	material_16.shader = operands[384]
	material_16.set_shader_parameter("factory_world_to_source", operands[385])
	material_16.set_shader_parameter("wall_clock", operands[386])
	material_16.set_shader_parameter("opacity", operands[387])
	material_16.set_shader_parameter("fracture", operands[388])
	material_16.set_shader_parameter("actor_ground", operands[389])
	material_16.set_shader_parameter("camera_ground", operands[390])
	material_16.set_shader_parameter("foreground", operands[391])
	material_16.set_shader_parameter("fresnelpower", operands[392])
	material_16.set_shader_parameter("AddTexture", operands[393])
	material_16.set_shader_parameter("BreakFactorGlobal", operands[394])
	material_16.set_shader_parameter("Texture_add2_offset", operands[395])
	material_16.set_shader_parameter("AddTexture2", operands[396])
	material_16.set_shader_parameter("Details_scale", operands[397])
	material_16.set_shader_parameter("Details_speed", operands[398])
	material_16.set_shader_parameter("DetailsTexture", operands[399])
	material_16.set_shader_parameter("Color1DGradient", operands[400])
	material_16.set_shader_parameter("ColorIntensity", operands[401])
	material_16.set_meta("factory_prepared_shader", operands[402])
	material_16.set_meta("factory_opacity_prepared_shader", operands[403])
	material_16.set_meta("factory_world_space_uniform", operands[404])
	material_16.set_meta("factory_recorded_source_space_frozen", operands[405])
	material_16.set_meta("factory_clock_names", operands[406])
	material_16.set_meta("factory_clock_pool_required", operands[407])
	var material_17 := ShaderMaterial.new()
	material_17.shader = operands[408]
	material_17.set_shader_parameter("factory_world_to_source", operands[409])
	material_17.set_shader_parameter("wall_clock", operands[410])
	material_17.set_shader_parameter("opacity", operands[411])
	material_17.set_shader_parameter("fracture", operands[412])
	material_17.set_shader_parameter("actor_ground", operands[413])
	material_17.set_shader_parameter("camera_ground", operands[414])
	material_17.set_shader_parameter("foreground", operands[415])
	material_17.set_shader_parameter("fresnelpower", operands[416])
	material_17.set_shader_parameter("AddTexture", operands[417])
	material_17.set_shader_parameter("BreakFactorGlobal", operands[418])
	material_17.set_shader_parameter("Texture_add2_offset", operands[419])
	material_17.set_shader_parameter("AddTexture2", operands[420])
	material_17.set_shader_parameter("Details_scale", operands[421])
	material_17.set_shader_parameter("Details_speed", operands[422])
	material_17.set_shader_parameter("DetailsTexture", operands[423])
	material_17.set_shader_parameter("Color1DGradient", operands[424])
	material_17.set_shader_parameter("ColorIntensity", operands[425])
	material_17.set_meta("factory_prepared_shader", operands[426])
	material_17.set_meta("factory_opacity_prepared_shader", operands[427])
	material_17.set_meta("factory_world_space_uniform", operands[428])
	material_17.set_meta("factory_recorded_source_space_frozen", operands[429])
	material_17.set_meta("factory_clock_names", operands[430])
	material_17.set_meta("factory_clock_pool_required", operands[431])
	var material_18 := ShaderMaterial.new()
	material_18.shader = operands[432]
	material_18.set_shader_parameter("factory_world_to_source", operands[433])
	material_18.set_shader_parameter("wall_clock", operands[434])
	material_18.set_shader_parameter("opacity", operands[435])
	material_18.set_shader_parameter("fracture", operands[436])
	material_18.set_shader_parameter("actor_ground", operands[437])
	material_18.set_shader_parameter("camera_ground", operands[438])
	material_18.set_shader_parameter("foreground", operands[439])
	material_18.set_shader_parameter("fresnelpower", operands[440])
	material_18.set_shader_parameter("AddTexture", operands[441])
	material_18.set_shader_parameter("BreakFactorGlobal", operands[442])
	material_18.set_shader_parameter("Texture_add2_offset", operands[443])
	material_18.set_shader_parameter("AddTexture2", operands[444])
	material_18.set_shader_parameter("Details_scale", operands[445])
	material_18.set_shader_parameter("Details_speed", operands[446])
	material_18.set_shader_parameter("DetailsTexture", operands[447])
	material_18.set_shader_parameter("Color1DGradient", operands[448])
	material_18.set_shader_parameter("ColorIntensity", operands[449])
	material_18.set_meta("factory_prepared_shader", operands[450])
	material_18.set_meta("factory_opacity_prepared_shader", operands[451])
	material_18.set_meta("factory_world_space_uniform", operands[452])
	material_18.set_meta("factory_recorded_source_space_frozen", operands[453])
	material_18.set_meta("factory_clock_names", operands[454])
	material_18.set_meta("factory_clock_pool_required", operands[455])
	var material_19 := ShaderMaterial.new()
	material_19.shader = operands[456]
	material_19.set_shader_parameter("factory_world_to_source", operands[457])
	material_19.set_shader_parameter("wall_clock", operands[458])
	material_19.set_shader_parameter("opacity", operands[459])
	material_19.set_shader_parameter("fracture", operands[460])
	material_19.set_shader_parameter("actor_ground", operands[461])
	material_19.set_shader_parameter("camera_ground", operands[462])
	material_19.set_shader_parameter("foreground", operands[463])
	material_19.set_shader_parameter("fresnelpower", operands[464])
	material_19.set_shader_parameter("AddTexture", operands[465])
	material_19.set_shader_parameter("BreakFactorGlobal", operands[466])
	material_19.set_shader_parameter("Texture_add2_offset", operands[467])
	material_19.set_shader_parameter("AddTexture2", operands[468])
	material_19.set_shader_parameter("Details_scale", operands[469])
	material_19.set_shader_parameter("Details_speed", operands[470])
	material_19.set_shader_parameter("DetailsTexture", operands[471])
	material_19.set_shader_parameter("Color1DGradient", operands[472])
	material_19.set_shader_parameter("ColorIntensity", operands[473])
	material_19.set_meta("factory_prepared_shader", operands[474])
	material_19.set_meta("factory_opacity_prepared_shader", operands[475])
	material_19.set_meta("factory_world_space_uniform", operands[476])
	material_19.set_meta("factory_recorded_source_space_frozen", operands[477])
	material_19.set_meta("factory_clock_names", operands[478])
	material_19.set_meta("factory_clock_pool_required", operands[479])
	var material_20 := ShaderMaterial.new()
	material_20.shader = operands[480]
	material_20.set_shader_parameter("factory_world_to_source", operands[481])
	material_20.set_shader_parameter("wall_clock", operands[482])
	material_20.set_shader_parameter("opacity", operands[483])
	material_20.set_shader_parameter("fracture", operands[484])
	material_20.set_shader_parameter("actor_ground", operands[485])
	material_20.set_shader_parameter("camera_ground", operands[486])
	material_20.set_shader_parameter("foreground", operands[487])
	material_20.set_shader_parameter("fresnelpower", operands[488])
	material_20.set_shader_parameter("AddTexture", operands[489])
	material_20.set_shader_parameter("BreakFactorGlobal", operands[490])
	material_20.set_shader_parameter("Texture_add2_offset", operands[491])
	material_20.set_shader_parameter("AddTexture2", operands[492])
	material_20.set_shader_parameter("Details_scale", operands[493])
	material_20.set_shader_parameter("Details_speed", operands[494])
	material_20.set_shader_parameter("DetailsTexture", operands[495])
	material_20.set_shader_parameter("Color1DGradient", operands[496])
	material_20.set_shader_parameter("ColorIntensity", operands[497])
	material_20.set_meta("factory_prepared_shader", operands[498])
	material_20.set_meta("factory_opacity_prepared_shader", operands[499])
	material_20.set_meta("factory_world_space_uniform", operands[500])
	material_20.set_meta("factory_recorded_source_space_frozen", operands[501])
	material_20.set_meta("factory_clock_names", operands[502])
	material_20.set_meta("factory_clock_pool_required", operands[503])
	var material_21 := ShaderMaterial.new()
	material_21.shader = operands[504]
	material_21.set_shader_parameter("factory_world_to_source", operands[505])
	material_21.set_shader_parameter("wall_clock", operands[506])
	material_21.set_shader_parameter("opacity", operands[507])
	material_21.set_shader_parameter("fracture", operands[508])
	material_21.set_shader_parameter("actor_ground", operands[509])
	material_21.set_shader_parameter("camera_ground", operands[510])
	material_21.set_shader_parameter("foreground", operands[511])
	material_21.set_shader_parameter("fresnelpower", operands[512])
	material_21.set_shader_parameter("AddTexture", operands[513])
	material_21.set_shader_parameter("BreakFactorGlobal", operands[514])
	material_21.set_shader_parameter("Texture_add2_offset", operands[515])
	material_21.set_shader_parameter("AddTexture2", operands[516])
	material_21.set_shader_parameter("Details_scale", operands[517])
	material_21.set_shader_parameter("Details_speed", operands[518])
	material_21.set_shader_parameter("DetailsTexture", operands[519])
	material_21.set_shader_parameter("Color1DGradient", operands[520])
	material_21.set_shader_parameter("ColorIntensity", operands[521])
	material_21.set_meta("factory_prepared_shader", operands[522])
	material_21.set_meta("factory_opacity_prepared_shader", operands[523])
	material_21.set_meta("factory_world_space_uniform", operands[524])
	material_21.set_meta("factory_recorded_source_space_frozen", operands[525])
	material_21.set_meta("factory_clock_names", operands[526])
	material_21.set_meta("factory_clock_pool_required", operands[527])
	var material_22 := ShaderMaterial.new()
	material_22.shader = operands[528]
	material_22.set_shader_parameter("factory_world_to_source", operands[529])
	material_22.set_shader_parameter("wall_clock", operands[530])
	material_22.set_shader_parameter("opacity", operands[531])
	material_22.set_shader_parameter("fracture", operands[532])
	material_22.set_shader_parameter("actor_ground", operands[533])
	material_22.set_shader_parameter("camera_ground", operands[534])
	material_22.set_shader_parameter("foreground", operands[535])
	material_22.set_shader_parameter("fresnelpower", operands[536])
	material_22.set_shader_parameter("AddTexture", operands[537])
	material_22.set_shader_parameter("BreakFactorGlobal", operands[538])
	material_22.set_shader_parameter("Texture_add2_offset", operands[539])
	material_22.set_shader_parameter("AddTexture2", operands[540])
	material_22.set_shader_parameter("Details_scale", operands[541])
	material_22.set_shader_parameter("Details_speed", operands[542])
	material_22.set_shader_parameter("DetailsTexture", operands[543])
	material_22.set_shader_parameter("Color1DGradient", operands[544])
	material_22.set_shader_parameter("ColorIntensity", operands[545])
	material_22.set_meta("factory_prepared_shader", operands[546])
	material_22.set_meta("factory_opacity_prepared_shader", operands[547])
	material_22.set_meta("factory_world_space_uniform", operands[548])
	material_22.set_meta("factory_recorded_source_space_frozen", operands[549])
	material_22.set_meta("factory_clock_names", operands[550])
	material_22.set_meta("factory_clock_pool_required", operands[551])
	var material_23 := ShaderMaterial.new()
	material_23.shader = operands[552]
	material_23.set_shader_parameter("factory_world_to_source", operands[553])
	material_23.set_shader_parameter("wall_clock", operands[554])
	material_23.set_shader_parameter("opacity", operands[555])
	material_23.set_shader_parameter("fracture", operands[556])
	material_23.set_shader_parameter("actor_ground", operands[557])
	material_23.set_shader_parameter("camera_ground", operands[558])
	material_23.set_shader_parameter("foreground", operands[559])
	material_23.set_shader_parameter("fresnelpower", operands[560])
	material_23.set_shader_parameter("AddTexture", operands[561])
	material_23.set_shader_parameter("BreakFactorGlobal", operands[562])
	material_23.set_shader_parameter("Texture_add2_offset", operands[563])
	material_23.set_shader_parameter("AddTexture2", operands[564])
	material_23.set_shader_parameter("Details_scale", operands[565])
	material_23.set_shader_parameter("Details_speed", operands[566])
	material_23.set_shader_parameter("DetailsTexture", operands[567])
	material_23.set_shader_parameter("Color1DGradient", operands[568])
	material_23.set_shader_parameter("ColorIntensity", operands[569])
	material_23.set_meta("factory_prepared_shader", operands[570])
	material_23.set_meta("factory_opacity_prepared_shader", operands[571])
	material_23.set_meta("factory_world_space_uniform", operands[572])
	material_23.set_meta("factory_recorded_source_space_frozen", operands[573])
	material_23.set_meta("factory_clock_names", operands[574])
	material_23.set_meta("factory_clock_pool_required", operands[575])
	var material_24 := ShaderMaterial.new()
	material_24.shader = operands[576]
	material_24.set_shader_parameter("factory_world_to_source", operands[577])
	material_24.set_shader_parameter("wall_clock", operands[578])
	material_24.set_shader_parameter("opacity", operands[579])
	material_24.set_shader_parameter("fracture", operands[580])
	material_24.set_shader_parameter("actor_ground", operands[581])
	material_24.set_shader_parameter("camera_ground", operands[582])
	material_24.set_shader_parameter("foreground", operands[583])
	material_24.set_shader_parameter("fresnelpower", operands[584])
	material_24.set_shader_parameter("AddTexture", operands[585])
	material_24.set_shader_parameter("BreakFactorGlobal", operands[586])
	material_24.set_shader_parameter("Texture_add2_offset", operands[587])
	material_24.set_shader_parameter("AddTexture2", operands[588])
	material_24.set_shader_parameter("Details_scale", operands[589])
	material_24.set_shader_parameter("Details_speed", operands[590])
	material_24.set_shader_parameter("DetailsTexture", operands[591])
	material_24.set_shader_parameter("Color1DGradient", operands[592])
	material_24.set_shader_parameter("ColorIntensity", operands[593])
	material_24.set_meta("factory_prepared_shader", operands[594])
	material_24.set_meta("factory_opacity_prepared_shader", operands[595])
	material_24.set_meta("factory_world_space_uniform", operands[596])
	material_24.set_meta("factory_recorded_source_space_frozen", operands[597])
	material_24.set_meta("factory_clock_names", operands[598])
	material_24.set_meta("factory_clock_pool_required", operands[599])
	var material_25 := ShaderMaterial.new()
	material_25.shader = operands[600]
	material_25.set_shader_parameter("factory_world_to_source", operands[601])
	material_25.set_shader_parameter("wall_clock", operands[602])
	material_25.set_shader_parameter("opacity", operands[603])
	material_25.set_shader_parameter("fracture", operands[604])
	material_25.set_shader_parameter("actor_ground", operands[605])
	material_25.set_shader_parameter("camera_ground", operands[606])
	material_25.set_shader_parameter("foreground", operands[607])
	material_25.set_shader_parameter("fresnelpower", operands[608])
	material_25.set_shader_parameter("AddTexture", operands[609])
	material_25.set_shader_parameter("BreakFactorGlobal", operands[610])
	material_25.set_shader_parameter("Texture_add2_offset", operands[611])
	material_25.set_shader_parameter("AddTexture2", operands[612])
	material_25.set_shader_parameter("Details_scale", operands[613])
	material_25.set_shader_parameter("Details_speed", operands[614])
	material_25.set_shader_parameter("DetailsTexture", operands[615])
	material_25.set_shader_parameter("Color1DGradient", operands[616])
	material_25.set_shader_parameter("ColorIntensity", operands[617])
	material_25.set_meta("factory_prepared_shader", operands[618])
	material_25.set_meta("factory_opacity_prepared_shader", operands[619])
	material_25.set_meta("factory_world_space_uniform", operands[620])
	material_25.set_meta("factory_recorded_source_space_frozen", operands[621])
	material_25.set_meta("factory_clock_names", operands[622])
	material_25.set_meta("factory_clock_pool_required", operands[623])
	var material_26 := ShaderMaterial.new()
	material_26.shader = operands[624]
	material_26.set_shader_parameter("factory_world_to_source", operands[625])
	material_26.set_shader_parameter("wall_clock", operands[626])
	material_26.set_shader_parameter("opacity", operands[627])
	material_26.set_shader_parameter("fracture", operands[628])
	material_26.set_shader_parameter("actor_ground", operands[629])
	material_26.set_shader_parameter("camera_ground", operands[630])
	material_26.set_shader_parameter("foreground", operands[631])
	material_26.set_shader_parameter("fresnelpower", operands[632])
	material_26.set_shader_parameter("AddTexture", operands[633])
	material_26.set_shader_parameter("BreakFactorGlobal", operands[634])
	material_26.set_shader_parameter("Texture_add2_offset", operands[635])
	material_26.set_shader_parameter("AddTexture2", operands[636])
	material_26.set_shader_parameter("Details_scale", operands[637])
	material_26.set_shader_parameter("Details_speed", operands[638])
	material_26.set_shader_parameter("DetailsTexture", operands[639])
	material_26.set_shader_parameter("Color1DGradient", operands[640])
	material_26.set_shader_parameter("ColorIntensity", operands[641])
	material_26.set_meta("factory_prepared_shader", operands[642])
	material_26.set_meta("factory_opacity_prepared_shader", operands[643])
	material_26.set_meta("factory_world_space_uniform", operands[644])
	material_26.set_meta("factory_recorded_source_space_frozen", operands[645])
	material_26.set_meta("factory_clock_names", operands[646])
	material_26.set_meta("factory_clock_pool_required", operands[647])
	var material_27 := ShaderMaterial.new()
	material_27.shader = operands[648]
	material_27.set_shader_parameter("factory_world_to_source", operands[649])
	material_27.set_shader_parameter("wall_clock", operands[650])
	material_27.set_shader_parameter("opacity", operands[651])
	material_27.set_shader_parameter("fracture", operands[652])
	material_27.set_shader_parameter("actor_ground", operands[653])
	material_27.set_shader_parameter("camera_ground", operands[654])
	material_27.set_shader_parameter("foreground", operands[655])
	material_27.set_shader_parameter("fresnelpower", operands[656])
	material_27.set_shader_parameter("AddTexture", operands[657])
	material_27.set_shader_parameter("BreakFactorGlobal", operands[658])
	material_27.set_shader_parameter("Texture_add2_offset", operands[659])
	material_27.set_shader_parameter("AddTexture2", operands[660])
	material_27.set_shader_parameter("Details_scale", operands[661])
	material_27.set_shader_parameter("Details_speed", operands[662])
	material_27.set_shader_parameter("DetailsTexture", operands[663])
	material_27.set_shader_parameter("Color1DGradient", operands[664])
	material_27.set_shader_parameter("ColorIntensity", operands[665])
	material_27.set_meta("factory_prepared_shader", operands[666])
	material_27.set_meta("factory_opacity_prepared_shader", operands[667])
	material_27.set_meta("factory_world_space_uniform", operands[668])
	material_27.set_meta("factory_recorded_source_space_frozen", operands[669])
	material_27.set_meta("factory_clock_names", operands[670])
	material_27.set_meta("factory_clock_pool_required", operands[671])
	var material_28 := ShaderMaterial.new()
	material_28.shader = operands[672]
	material_28.set_shader_parameter("factory_world_to_source", operands[673])
	material_28.set_shader_parameter("wall_clock", operands[674])
	material_28.set_shader_parameter("opacity", operands[675])
	material_28.set_shader_parameter("fracture", operands[676])
	material_28.set_shader_parameter("actor_ground", operands[677])
	material_28.set_shader_parameter("camera_ground", operands[678])
	material_28.set_shader_parameter("foreground", operands[679])
	material_28.set_shader_parameter("fresnelpower", operands[680])
	material_28.set_shader_parameter("AddTexture", operands[681])
	material_28.set_shader_parameter("BreakFactorGlobal", operands[682])
	material_28.set_shader_parameter("Texture_add2_offset", operands[683])
	material_28.set_shader_parameter("AddTexture2", operands[684])
	material_28.set_shader_parameter("Details_scale", operands[685])
	material_28.set_shader_parameter("Details_speed", operands[686])
	material_28.set_shader_parameter("DetailsTexture", operands[687])
	material_28.set_shader_parameter("Color1DGradient", operands[688])
	material_28.set_shader_parameter("ColorIntensity", operands[689])
	material_28.set_meta("factory_prepared_shader", operands[690])
	material_28.set_meta("factory_opacity_prepared_shader", operands[691])
	material_28.set_meta("factory_world_space_uniform", operands[692])
	material_28.set_meta("factory_recorded_source_space_frozen", operands[693])
	material_28.set_meta("factory_clock_names", operands[694])
	material_28.set_meta("factory_clock_pool_required", operands[695])
	var material_29 := ShaderMaterial.new()
	material_29.shader = operands[696]
	material_29.set_shader_parameter("factory_world_to_source", operands[697])
	material_29.set_shader_parameter("wall_clock", operands[698])
	material_29.set_shader_parameter("opacity", operands[699])
	material_29.set_shader_parameter("fracture", operands[700])
	material_29.set_shader_parameter("actor_ground", operands[701])
	material_29.set_shader_parameter("camera_ground", operands[702])
	material_29.set_shader_parameter("foreground", operands[703])
	material_29.set_shader_parameter("fresnelpower", operands[704])
	material_29.set_shader_parameter("AddTexture", operands[705])
	material_29.set_shader_parameter("BreakFactorGlobal", operands[706])
	material_29.set_shader_parameter("Texture_add2_offset", operands[707])
	material_29.set_shader_parameter("AddTexture2", operands[708])
	material_29.set_shader_parameter("Details_scale", operands[709])
	material_29.set_shader_parameter("Details_speed", operands[710])
	material_29.set_shader_parameter("DetailsTexture", operands[711])
	material_29.set_shader_parameter("Color1DGradient", operands[712])
	material_29.set_shader_parameter("ColorIntensity", operands[713])
	material_29.set_meta("factory_prepared_shader", operands[714])
	material_29.set_meta("factory_opacity_prepared_shader", operands[715])
	material_29.set_meta("factory_world_space_uniform", operands[716])
	material_29.set_meta("factory_recorded_source_space_frozen", operands[717])
	material_29.set_meta("factory_clock_names", operands[718])
	material_29.set_meta("factory_clock_pool_required", operands[719])
	var material_30 := ShaderMaterial.new()
	material_30.shader = operands[720]
	material_30.set_shader_parameter("factory_world_to_source", operands[721])
	material_30.set_shader_parameter("cold_noise", operands[722])
	material_30.set_shader_parameter("wall_clock", operands[723])
	material_30.set_shader_parameter("opacity", operands[724])
	material_30.set_shader_parameter("actor_ground", operands[725])
	material_30.set_shader_parameter("camera_ground", operands[726])
	material_30.set_shader_parameter("foreground", operands[727])
	material_30.set_shader_parameter("centre", operands[728])
	material_30.set_shader_parameter("half_extent", operands[729])
	material_30.set_meta("factory_prepared_shader", operands[730])
	material_30.set_meta("factory_opacity_prepared_shader", operands[731])
	material_30.set_meta("factory_world_space_uniform", operands[732])
	material_30.set_meta("factory_recorded_source_space_frozen", operands[733])
	material_30.set_meta("factory_clock_names", operands[734])
	material_30.set_meta("factory_clock_pool_required", operands[735])
	var material_31 := ShaderMaterial.new()
	material_31.shader = operands[736]
	material_31.set_shader_parameter("factory_world_to_source", operands[737])
	material_31.set_shader_parameter("opacity", operands[738])
	material_31.set_shader_parameter("actor_ground", operands[739])
	material_31.set_shader_parameter("camera_ground", operands[740])
	material_31.set_shader_parameter("foreground", operands[741])
	material_31.set_meta("factory_prepared_shader", operands[742])
	material_31.set_meta("factory_opacity_prepared_shader", operands[743])
	material_31.set_meta("factory_world_space_uniform", operands[744])
	material_31.set_meta("factory_recorded_source_space_frozen", operands[745])
	material_31.set_meta("factory_clock_names", operands[746])
	material_31.set_meta("factory_clock_pool_required", operands[747])
	var material_32 := ShaderMaterial.new()
	material_32.shader = operands[748]
	material_32.set_shader_parameter("factory_world_to_source", operands[749])
	material_32.set_shader_parameter("opacity", operands[750])
	material_32.set_shader_parameter("actor_ground", operands[751])
	material_32.set_shader_parameter("camera_ground", operands[752])
	material_32.set_shader_parameter("foreground", operands[753])
	material_32.set_meta("factory_prepared_shader", operands[754])
	material_32.set_meta("factory_opacity_prepared_shader", operands[755])
	material_32.set_meta("factory_world_space_uniform", operands[756])
	material_32.set_meta("factory_recorded_source_space_frozen", operands[757])
	material_32.set_meta("factory_clock_names", operands[758])
	material_32.set_meta("factory_clock_pool_required", operands[759])
	var material_33 := ShaderMaterial.new()
	material_33.shader = operands[760]
	material_33.set_shader_parameter("factory_world_to_source", operands[761])
	material_33.set_shader_parameter("opacity", operands[762])
	material_33.set_shader_parameter("actor_ground", operands[763])
	material_33.set_shader_parameter("camera_ground", operands[764])
	material_33.set_shader_parameter("foreground", operands[765])
	material_33.set_meta("factory_prepared_shader", operands[766])
	material_33.set_meta("factory_opacity_prepared_shader", operands[767])
	material_33.set_meta("factory_world_space_uniform", operands[768])
	material_33.set_meta("factory_recorded_source_space_frozen", operands[769])
	material_33.set_meta("factory_clock_names", operands[770])
	material_33.set_meta("factory_clock_pool_required", operands[771])
	var material_34 := ShaderMaterial.new()
	material_34.shader = operands[772]
	material_34.set_shader_parameter("factory_world_to_source", operands[773])
	material_34.set_shader_parameter("opacity", operands[774])
	material_34.set_shader_parameter("actor_ground", operands[775])
	material_34.set_shader_parameter("camera_ground", operands[776])
	material_34.set_shader_parameter("foreground", operands[777])
	material_34.set_meta("factory_prepared_shader", operands[778])
	material_34.set_meta("factory_opacity_prepared_shader", operands[779])
	material_34.set_meta("factory_world_space_uniform", operands[780])
	material_34.set_meta("factory_recorded_source_space_frozen", operands[781])
	material_34.set_meta("factory_clock_names", operands[782])
	material_34.set_meta("factory_clock_pool_required", operands[783])
	var material_35 := ShaderMaterial.new()
	material_35.shader = operands[784]
	material_35.set_shader_parameter("factory_world_to_source", operands[785])
	material_35.set_shader_parameter("opacity", operands[786])
	material_35.set_shader_parameter("actor_ground", operands[787])
	material_35.set_shader_parameter("camera_ground", operands[788])
	material_35.set_shader_parameter("foreground", operands[789])
	material_35.set_meta("factory_prepared_shader", operands[790])
	material_35.set_meta("factory_opacity_prepared_shader", operands[791])
	material_35.set_meta("factory_world_space_uniform", operands[792])
	material_35.set_meta("factory_recorded_source_space_frozen", operands[793])
	material_35.set_meta("factory_clock_names", operands[794])
	material_35.set_meta("factory_clock_pool_required", operands[795])
	var material_36 := ShaderMaterial.new()
	material_36.shader = operands[796]
	material_36.set_shader_parameter("factory_world_to_source", operands[797])
	material_36.set_shader_parameter("opacity", operands[798])
	material_36.set_shader_parameter("actor_ground", operands[799])
	material_36.set_shader_parameter("camera_ground", operands[800])
	material_36.set_shader_parameter("foreground", operands[801])
	material_36.set_meta("factory_prepared_shader", operands[802])
	material_36.set_meta("factory_opacity_prepared_shader", operands[803])
	material_36.set_meta("factory_world_space_uniform", operands[804])
	material_36.set_meta("factory_recorded_source_space_frozen", operands[805])
	material_36.set_meta("factory_clock_names", operands[806])
	material_36.set_meta("factory_clock_pool_required", operands[807])
	var material_37 := ShaderMaterial.new()
	material_37.shader = operands[808]
	material_37.set_shader_parameter("factory_world_to_source", operands[809])
	material_37.set_shader_parameter("opacity", operands[810])
	material_37.set_shader_parameter("actor_ground", operands[811])
	material_37.set_shader_parameter("camera_ground", operands[812])
	material_37.set_shader_parameter("foreground", operands[813])
	material_37.set_meta("factory_prepared_shader", operands[814])
	material_37.set_meta("factory_opacity_prepared_shader", operands[815])
	material_37.set_meta("factory_world_space_uniform", operands[816])
	material_37.set_meta("factory_recorded_source_space_frozen", operands[817])
	material_37.set_meta("factory_clock_names", operands[818])
	material_37.set_meta("factory_clock_pool_required", operands[819])
	var material_38 := ShaderMaterial.new()
	material_38.shader = operands[820]
	material_38.set_shader_parameter("factory_world_to_source", operands[821])
	material_38.set_shader_parameter("opacity", operands[822])
	material_38.set_shader_parameter("actor_ground", operands[823])
	material_38.set_shader_parameter("camera_ground", operands[824])
	material_38.set_shader_parameter("foreground", operands[825])
	material_38.set_meta("factory_prepared_shader", operands[826])
	material_38.set_meta("factory_opacity_prepared_shader", operands[827])
	material_38.set_meta("factory_world_space_uniform", operands[828])
	material_38.set_meta("factory_recorded_source_space_frozen", operands[829])
	material_38.set_meta("factory_clock_names", operands[830])
	material_38.set_meta("factory_clock_pool_required", operands[831])
	var material_39 := ShaderMaterial.new()
	material_39.shader = operands[832]
	material_39.set_shader_parameter("factory_world_to_source", operands[833])
	material_39.set_shader_parameter("opacity", operands[834])
	material_39.set_shader_parameter("actor_ground", operands[835])
	material_39.set_shader_parameter("camera_ground", operands[836])
	material_39.set_shader_parameter("foreground", operands[837])
	material_39.set_meta("factory_prepared_shader", operands[838])
	material_39.set_meta("factory_opacity_prepared_shader", operands[839])
	material_39.set_meta("factory_world_space_uniform", operands[840])
	material_39.set_meta("factory_recorded_source_space_frozen", operands[841])
	material_39.set_meta("factory_clock_names", operands[842])
	material_39.set_meta("factory_clock_pool_required", operands[843])
	var material_40 := ShaderMaterial.new()
	material_40.shader = operands[844]
	material_40.set_shader_parameter("factory_world_to_source", operands[845])
	material_40.set_shader_parameter("opacity", operands[846])
	material_40.set_shader_parameter("actor_ground", operands[847])
	material_40.set_shader_parameter("camera_ground", operands[848])
	material_40.set_shader_parameter("foreground", operands[849])
	material_40.set_meta("factory_prepared_shader", operands[850])
	material_40.set_meta("factory_opacity_prepared_shader", operands[851])
	material_40.set_meta("factory_world_space_uniform", operands[852])
	material_40.set_meta("factory_recorded_source_space_frozen", operands[853])
	material_40.set_meta("factory_clock_names", operands[854])
	material_40.set_meta("factory_clock_pool_required", operands[855])
	var material_41 := ShaderMaterial.new()
	material_41.shader = operands[856]
	material_41.set_shader_parameter("factory_world_to_source", operands[857])
	material_41.set_shader_parameter("opacity", operands[858])
	material_41.set_shader_parameter("actor_ground", operands[859])
	material_41.set_shader_parameter("camera_ground", operands[860])
	material_41.set_shader_parameter("foreground", operands[861])
	material_41.set_meta("factory_prepared_shader", operands[862])
	material_41.set_meta("factory_opacity_prepared_shader", operands[863])
	material_41.set_meta("factory_world_space_uniform", operands[864])
	material_41.set_meta("factory_recorded_source_space_frozen", operands[865])
	material_41.set_meta("factory_clock_names", operands[866])
	material_41.set_meta("factory_clock_pool_required", operands[867])
	var material_42 := ShaderMaterial.new()
	material_42.shader = operands[868]
	material_42.set_shader_parameter("factory_world_to_source", operands[869])
	material_42.set_shader_parameter("opacity", operands[870])
	material_42.set_shader_parameter("actor_ground", operands[871])
	material_42.set_shader_parameter("camera_ground", operands[872])
	material_42.set_shader_parameter("foreground", operands[873])
	material_42.set_meta("factory_prepared_shader", operands[874])
	material_42.set_meta("factory_opacity_prepared_shader", operands[875])
	material_42.set_meta("factory_world_space_uniform", operands[876])
	material_42.set_meta("factory_recorded_source_space_frozen", operands[877])
	material_42.set_meta("factory_clock_names", operands[878])
	material_42.set_meta("factory_clock_pool_required", operands[879])
	var material_43 := ShaderMaterial.new()
	material_43.shader = operands[880]
	material_43.set_shader_parameter("factory_world_to_source", operands[881])
	material_43.set_shader_parameter("opacity", operands[882])
	material_43.set_shader_parameter("actor_ground", operands[883])
	material_43.set_shader_parameter("camera_ground", operands[884])
	material_43.set_shader_parameter("foreground", operands[885])
	material_43.set_meta("factory_prepared_shader", operands[886])
	material_43.set_meta("factory_opacity_prepared_shader", operands[887])
	material_43.set_meta("factory_world_space_uniform", operands[888])
	material_43.set_meta("factory_recorded_source_space_frozen", operands[889])
	material_43.set_meta("factory_clock_names", operands[890])
	material_43.set_meta("factory_clock_pool_required", operands[891])
	var material_44 := ShaderMaterial.new()
	material_44.shader = operands[892]
	material_44.set_shader_parameter("factory_world_to_source", operands[893])
	material_44.set_shader_parameter("opacity", operands[894])
	material_44.set_shader_parameter("actor_ground", operands[895])
	material_44.set_shader_parameter("camera_ground", operands[896])
	material_44.set_shader_parameter("foreground", operands[897])
	material_44.set_meta("factory_prepared_shader", operands[898])
	material_44.set_meta("factory_opacity_prepared_shader", operands[899])
	material_44.set_meta("factory_world_space_uniform", operands[900])
	material_44.set_meta("factory_recorded_source_space_frozen", operands[901])
	material_44.set_meta("factory_clock_names", operands[902])
	material_44.set_meta("factory_clock_pool_required", operands[903])
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "Recorded"
	node_0.set("metadata/factory_native_gpu_emitters", operands[904])
	var node_1 := Node3D.new()
	node_1.name = "assembly"
	node_0.add_child(node_1)
	var node_2 := Node3D.new()
	node_2.name = "effect"
	node_1.add_child(node_2)
	var node_3 := Node3D.new()
	node_3.name = "Donor"
	node_3.set("metadata/_edit_group_", operands[905])
	node_2.add_child(node_3)
	var node_4 := Node3D.new()
	node_4.name = "FactoryGenerated_0000_Node3D"
	node_4.transform = operands[906]
	node_3.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "FactoryGenerated_0000_MeshInstance3D"
	node_5.transform = operands[907]
	node_5.layers = operands[908]
	node_5.material_override = material_0
	node_5.custom_aabb = operands[909]
	node_5.mesh = operands[910]
	node_4.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "FactoryGenerated_0001_MeshInstance3D"
	node_6.transform = operands[911]
	node_6.layers = operands[912]
	node_6.material_override = material_1
	node_6.mesh = operands[913]
	node_4.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "FactoryGenerated_0002_MeshInstance3D"
	node_7.transform = operands[914]
	node_7.layers = operands[915]
	node_7.material_override = material_2
	node_7.mesh = operands[916]
	node_4.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "FactoryGenerated_0003_MeshInstance3D"
	node_8.transform = operands[917]
	node_8.layers = operands[918]
	node_8.material_override = material_3
	node_8.mesh = operands[919]
	node_4.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "FactoryGenerated_0004_MeshInstance3D"
	node_9.transform = operands[920]
	node_9.layers = operands[921]
	node_9.material_override = material_4
	node_9.mesh = operands[922]
	node_4.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "FactoryGenerated_0005_MeshInstance3D"
	node_10.transform = operands[923]
	node_10.layers = operands[924]
	node_10.material_override = material_5
	node_10.mesh = operands[925]
	node_4.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "FactoryGenerated_0006_MeshInstance3D"
	node_11.transform = operands[926]
	node_11.layers = operands[927]
	node_11.material_override = material_6
	node_11.mesh = operands[928]
	node_4.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "FactoryGenerated_0007_MeshInstance3D"
	node_12.transform = operands[929]
	node_12.layers = operands[930]
	node_12.material_override = material_7
	node_12.mesh = operands[931]
	node_4.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "FactoryGenerated_0008_MeshInstance3D"
	node_13.transform = operands[932]
	node_13.layers = operands[933]
	node_13.material_override = material_8
	node_13.mesh = operands[934]
	node_4.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "FactoryGenerated_0009_MeshInstance3D"
	node_14.transform = operands[935]
	node_14.layers = operands[936]
	node_14.material_override = material_9
	node_14.mesh = operands[937]
	node_4.add_child(node_14)
	var node_15 := Node3D.new()
	node_15.name = "FactoryGenerated_0001_Node3D"
	node_15.transform = operands[938]
	node_3.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "FactoryGenerated_0000_MeshInstance3D"
	node_16.transform = operands[939]
	node_16.layers = operands[940]
	node_16.material_override = material_10
	node_16.custom_aabb = operands[941]
	node_16.mesh = operands[942]
	node_15.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "FactoryGenerated_0001_MeshInstance3D"
	node_17.transform = operands[943]
	node_17.layers = operands[944]
	node_17.material_override = material_11
	node_17.mesh = operands[945]
	node_15.add_child(node_17)
	var node_18 := MeshInstance3D.new()
	node_18.name = "FactoryGenerated_0002_MeshInstance3D"
	node_18.transform = operands[946]
	node_18.layers = operands[947]
	node_18.material_override = material_12
	node_18.mesh = operands[948]
	node_15.add_child(node_18)
	var node_19 := MeshInstance3D.new()
	node_19.name = "FactoryGenerated_0003_MeshInstance3D"
	node_19.transform = operands[949]
	node_19.layers = operands[950]
	node_19.material_override = material_13
	node_19.mesh = operands[951]
	node_15.add_child(node_19)
	var node_20 := MeshInstance3D.new()
	node_20.name = "FactoryGenerated_0004_MeshInstance3D"
	node_20.transform = operands[952]
	node_20.layers = operands[953]
	node_20.material_override = material_14
	node_20.mesh = operands[954]
	node_15.add_child(node_20)
	var node_21 := MeshInstance3D.new()
	node_21.name = "FactoryGenerated_0005_MeshInstance3D"
	node_21.transform = operands[955]
	node_21.layers = operands[956]
	node_21.material_override = material_15
	node_21.mesh = operands[957]
	node_15.add_child(node_21)
	var node_22 := MeshInstance3D.new()
	node_22.name = "FactoryGenerated_0006_MeshInstance3D"
	node_22.transform = operands[958]
	node_22.layers = operands[959]
	node_22.material_override = material_16
	node_22.mesh = operands[960]
	node_15.add_child(node_22)
	var node_23 := MeshInstance3D.new()
	node_23.name = "FactoryGenerated_0007_MeshInstance3D"
	node_23.transform = operands[961]
	node_23.layers = operands[962]
	node_23.material_override = material_17
	node_23.mesh = operands[963]
	node_15.add_child(node_23)
	var node_24 := MeshInstance3D.new()
	node_24.name = "FactoryGenerated_0008_MeshInstance3D"
	node_24.transform = operands[964]
	node_24.layers = operands[965]
	node_24.material_override = material_18
	node_24.mesh = operands[966]
	node_15.add_child(node_24)
	var node_25 := MeshInstance3D.new()
	node_25.name = "FactoryGenerated_0009_MeshInstance3D"
	node_25.transform = operands[967]
	node_25.layers = operands[968]
	node_25.material_override = material_19
	node_25.mesh = operands[969]
	node_15.add_child(node_25)
	var node_26 := Node3D.new()
	node_26.name = "FactoryGenerated_0002_Node3D"
	node_26.transform = operands[970]
	node_3.add_child(node_26)
	var node_27 := MeshInstance3D.new()
	node_27.name = "FactoryGenerated_0000_MeshInstance3D"
	node_27.transform = operands[971]
	node_27.layers = operands[972]
	node_27.material_override = material_20
	node_27.custom_aabb = operands[973]
	node_27.mesh = operands[974]
	node_26.add_child(node_27)
	var node_28 := MeshInstance3D.new()
	node_28.name = "FactoryGenerated_0001_MeshInstance3D"
	node_28.transform = operands[975]
	node_28.layers = operands[976]
	node_28.material_override = material_21
	node_28.mesh = operands[977]
	node_26.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "FactoryGenerated_0002_MeshInstance3D"
	node_29.transform = operands[978]
	node_29.layers = operands[979]
	node_29.material_override = material_22
	node_29.mesh = operands[980]
	node_26.add_child(node_29)
	var node_30 := MeshInstance3D.new()
	node_30.name = "FactoryGenerated_0003_MeshInstance3D"
	node_30.transform = operands[981]
	node_30.layers = operands[982]
	node_30.material_override = material_23
	node_30.mesh = operands[983]
	node_26.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "FactoryGenerated_0004_MeshInstance3D"
	node_31.transform = operands[984]
	node_31.layers = operands[985]
	node_31.material_override = material_24
	node_31.mesh = operands[986]
	node_26.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "FactoryGenerated_0005_MeshInstance3D"
	node_32.transform = operands[987]
	node_32.layers = operands[988]
	node_32.material_override = material_25
	node_32.mesh = operands[989]
	node_26.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "FactoryGenerated_0006_MeshInstance3D"
	node_33.transform = operands[990]
	node_33.layers = operands[991]
	node_33.material_override = material_26
	node_33.mesh = operands[992]
	node_26.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "FactoryGenerated_0007_MeshInstance3D"
	node_34.transform = operands[993]
	node_34.layers = operands[994]
	node_34.material_override = material_27
	node_34.mesh = operands[995]
	node_26.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "FactoryGenerated_0008_MeshInstance3D"
	node_35.transform = operands[996]
	node_35.layers = operands[997]
	node_35.material_override = material_28
	node_35.mesh = operands[998]
	node_26.add_child(node_35)
	var node_36 := MeshInstance3D.new()
	node_36.name = "FactoryGenerated_0009_MeshInstance3D"
	node_36.transform = operands[999]
	node_36.layers = operands[1000]
	node_36.material_override = material_29
	node_36.mesh = operands[1001]
	node_26.add_child(node_36)
	var node_37 := StaticBody3D.new()
	node_37.name = "FactoryGenerated_0003_StaticBody3D"
	node_37.transform = operands[1002]
	node_37.collision_layer = operands[1003]
	node_37.collision_mask = operands[1004]
	node_3.add_child(node_37)
	var node_38 := CollisionShape3D.new()
	node_38.name = "FactoryGenerated_0000_CollisionShape3D"
	node_38.shape = operands[1005]
	node_37.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "FactoryGenerated_0004_MeshInstance3D"
	node_39.transform = operands[1006]
	node_39.layers = operands[1007]
	node_39.material_override = material_30
	node_39.mesh = operands[1008]
	node_3.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "FactoryGenerated_0005_MeshInstance3D"
	node_40.layers = operands[1009]
	node_40.material_override = material_31
	node_40.mesh = operands[1010]
	node_3.add_child(node_40)
	var node_41 := MeshInstance3D.new()
	node_41.name = "FactoryGenerated_0006_MeshInstance3D"
	node_41.layers = operands[1011]
	node_41.material_override = material_32
	node_41.mesh = operands[1012]
	node_3.add_child(node_41)
	var node_42 := MeshInstance3D.new()
	node_42.name = "FactoryGenerated_0007_MeshInstance3D"
	node_42.layers = operands[1013]
	node_42.material_override = material_33
	node_42.mesh = operands[1014]
	node_3.add_child(node_42)
	var node_43 := MeshInstance3D.new()
	node_43.name = "FactoryGenerated_0008_MeshInstance3D"
	node_43.layers = operands[1015]
	node_43.material_override = material_34
	node_43.mesh = operands[1016]
	node_3.add_child(node_43)
	var node_44 := MeshInstance3D.new()
	node_44.name = "FactoryGenerated_0009_MeshInstance3D"
	node_44.layers = operands[1017]
	node_44.material_override = material_35
	node_44.mesh = operands[1018]
	node_3.add_child(node_44)
	var node_45 := MeshInstance3D.new()
	node_45.name = "FactoryGenerated_0010_MeshInstance3D"
	node_45.layers = operands[1019]
	node_45.material_override = material_36
	node_45.mesh = operands[1020]
	node_3.add_child(node_45)
	var node_46 := MeshInstance3D.new()
	node_46.name = "FactoryGenerated_0011_MeshInstance3D"
	node_46.layers = operands[1021]
	node_46.material_override = material_37
	node_46.mesh = operands[1022]
	node_3.add_child(node_46)
	var node_47 := MeshInstance3D.new()
	node_47.name = "FactoryGenerated_0012_MeshInstance3D"
	node_47.layers = operands[1023]
	node_47.material_override = material_38
	node_47.mesh = operands[1024]
	node_3.add_child(node_47)
	var node_48 := MeshInstance3D.new()
	node_48.name = "FactoryGenerated_0013_MeshInstance3D"
	node_48.layers = operands[1025]
	node_48.material_override = material_39
	node_48.mesh = operands[1026]
	node_3.add_child(node_48)
	var node_49 := MeshInstance3D.new()
	node_49.name = "FactoryGenerated_0014_MeshInstance3D"
	node_49.layers = operands[1027]
	node_49.material_override = material_40
	node_49.mesh = operands[1028]
	node_3.add_child(node_49)
	var node_50 := MeshInstance3D.new()
	node_50.name = "FactoryGenerated_0015_MeshInstance3D"
	node_50.layers = operands[1029]
	node_50.material_override = material_41
	node_50.mesh = operands[1030]
	node_3.add_child(node_50)
	var node_51 := MeshInstance3D.new()
	node_51.name = "FactoryGenerated_0016_MeshInstance3D"
	node_51.layers = operands[1031]
	node_51.material_override = material_42
	node_51.mesh = operands[1032]
	node_3.add_child(node_51)
	var node_52 := MeshInstance3D.new()
	node_52.name = "FactoryGenerated_0017_MeshInstance3D"
	node_52.layers = operands[1033]
	node_52.material_override = material_43
	node_52.mesh = operands[1034]
	node_3.add_child(node_52)
	var node_53 := MeshInstance3D.new()
	node_53.name = "FactoryGenerated_0018_MeshInstance3D"
	node_53.layers = operands[1035]
	node_53.material_override = material_44
	node_53.mesh = operands[1036]
	node_3.add_child(node_53)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"root": node_0, "geometry": [node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_39, node_40, node_41, node_42, node_43, node_44, node_45, node_46, node_47, node_48, node_49, node_50, node_51, node_52, node_53, node_4, node_15, node_26], "materials": [node_5.material_override, node_6.material_override, node_7.material_override, node_8.material_override, node_9.material_override, node_10.material_override, node_11.material_override, node_12.material_override, node_13.material_override, node_14.material_override, node_16.material_override, node_17.material_override, node_18.material_override, node_19.material_override, node_20.material_override, node_21.material_override, node_22.material_override, node_23.material_override, node_24.material_override, node_25.material_override, node_27.material_override, node_28.material_override, node_29.material_override, node_30.material_override, node_31.material_override, node_32.material_override, node_33.material_override, node_34.material_override, node_35.material_override, node_36.material_override, node_39.material_override, node_40.material_override, node_41.material_override, node_42.material_override, node_43.material_override, node_44.material_override, node_45.material_override, node_46.material_override, node_47.material_override, node_48.material_override, node_49.material_override, node_50.material_override, node_51.material_override, node_52.material_override, node_53.material_override], "cohorts": []}
