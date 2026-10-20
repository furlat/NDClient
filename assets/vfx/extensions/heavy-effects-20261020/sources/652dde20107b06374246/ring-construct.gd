extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("factory_world_to_source", operands[1])
	material_0.set_shader_parameter("source_tex", operands[2])
	material_0.set_meta("factory_occurrence_alpha", operands[3])
	material_0.set_meta("factory_prepared_shader", operands[4])
	material_0.set_meta("factory_opacity_prepared_shader", operands[5])
	material_0.set_meta("factory_clock_names", operands[6])
	material_0.set_meta("factory_clock_pool_required", operands[7])
	var material_1 := ShaderMaterial.new()
	material_1.shader = operands[8]
	material_1.set_shader_parameter("direction", operands[9])
	material_1.set_shader_parameter("spread", operands[10])
	material_1.set_shader_parameter("initial_linear_velocity_min", operands[11])
	material_1.set_shader_parameter("initial_linear_velocity_max", operands[12])
	material_1.set_shader_parameter("directional_velocity_min", operands[13])
	material_1.set_shader_parameter("directional_velocity_max", operands[14])
	material_1.set_shader_parameter("radial_velocity_min", operands[15])
	material_1.set_shader_parameter("radial_velocity_max", operands[16])
	material_1.set_shader_parameter("initial_angle_min", operands[17])
	material_1.set_shader_parameter("initial_angle_max", operands[18])
	material_1.set_shader_parameter("scale_min", operands[19])
	material_1.set_shader_parameter("scale_max", operands[20])
	material_1.set_shader_parameter("hue_variation_min", operands[21])
	material_1.set_shader_parameter("hue_variation_max", operands[22])
	material_1.set_shader_parameter("anim_speed_min", operands[23])
	material_1.set_shader_parameter("anim_speed_max", operands[24])
	material_1.set_shader_parameter("emission_ring_axis", operands[25])
	material_1.set_shader_parameter("emission_ring_radius", operands[26])
	material_1.set_shader_parameter("emission_ring_cone_angle", operands[27])
	material_1.set_shader_parameter("color_value", operands[28])
	material_1.set_shader_parameter("gravity", operands[29])
	material_1.set_shader_parameter("color_ramp", operands[30])
	material_1.set_shader_parameter("scale_curve", operands[31])
	material_1.set_meta("factory_prepared_shader", operands[32])
	material_1.set_meta("factory_clock_names", operands[33])
	material_1.set_meta("factory_opacity_prepared_shader", operands[34])
	material_1.set_meta("factory_native_process_source", operands[35])
	material_1.set_meta("factory_clock_pool_required", operands[36])
	material_1.set_meta("factory_zero_gravity_native_operand", operands[37])
	material_1.set_meta("factory_fire_wall_world_units", operands[38])
	var material_2 := ShaderMaterial.new()
	material_2.shader = operands[39]
	material_2.set_shader_parameter("factory_world_to_source", operands[40])
	material_2.set_shader_parameter("sprite_sheet", operands[41])
	material_2.set_shader_parameter("gradient_1d_texture", operands[42])
	material_2.set_shader_parameter("frame_count", operands[43])
	material_2.set_shader_parameter("is_loop", operands[44])
	material_2.set_shader_parameter("uv_offset", operands[45])
	material_2.set_meta("factory_occurrence_alpha", operands[46])
	material_2.set_meta("factory_prepared_shader", operands[47])
	material_2.set_meta("factory_opacity_prepared_shader", operands[48])
	material_2.set_meta("factory_clock_names", operands[49])
	material_2.set_meta("factory_clock_pool_required", operands[50])
	var material_3 := ShaderMaterial.new()
	material_3.shader = operands[51]
	material_3.set_shader_parameter("direction", operands[52])
	material_3.set_shader_parameter("spread", operands[53])
	material_3.set_shader_parameter("directional_velocity_min", operands[54])
	material_3.set_shader_parameter("directional_velocity_max", operands[55])
	material_3.set_shader_parameter("initial_angle_min", operands[56])
	material_3.set_shader_parameter("initial_angle_max", operands[57])
	material_3.set_shader_parameter("scale_min", operands[58])
	material_3.set_shader_parameter("scale_max", operands[59])
	material_3.set_shader_parameter("emission_ring_axis", operands[60])
	material_3.set_shader_parameter("emission_ring_radius", operands[61])
	material_3.set_shader_parameter("emission_ring_cone_angle", operands[62])
	material_3.set_shader_parameter("color_value", operands[63])
	material_3.set_shader_parameter("gravity", operands[64])
	material_3.set_shader_parameter("color_ramp", operands[65])
	material_3.set_shader_parameter("alpha_curve", operands[66])
	material_3.set_shader_parameter("scale_curve", operands[67])
	material_3.set_meta("factory_prepared_shader", operands[68])
	material_3.set_meta("factory_clock_names", operands[69])
	material_3.set_meta("factory_opacity_prepared_shader", operands[70])
	material_3.set_meta("factory_native_process_source", operands[71])
	material_3.set_meta("factory_clock_pool_required", operands[72])
	material_3.set_meta("factory_zero_gravity_native_operand", operands[73])
	material_3.set_meta("factory_fire_wall_world_units", operands[74])
	var material_4 := ShaderMaterial.new()
	material_4.shader = operands[75]
	material_4.set_shader_parameter("factory_world_to_source", operands[76])
	material_4.set_shader_parameter("source_tex", operands[77])
	material_4.set_meta("factory_occurrence_alpha", operands[78])
	material_4.set_meta("factory_prepared_shader", operands[79])
	material_4.set_meta("factory_opacity_prepared_shader", operands[80])
	material_4.set_meta("factory_clock_names", operands[81])
	material_4.set_meta("factory_clock_pool_required", operands[82])
	var material_5 := ShaderMaterial.new()
	material_5.shader = operands[83]
	material_5.set_shader_parameter("direction", operands[84])
	material_5.set_shader_parameter("spread", operands[85])
	material_5.set_shader_parameter("initial_linear_velocity_min", operands[86])
	material_5.set_shader_parameter("initial_linear_velocity_max", operands[87])
	material_5.set_shader_parameter("directional_velocity_min", operands[88])
	material_5.set_shader_parameter("directional_velocity_max", operands[89])
	material_5.set_shader_parameter("radial_velocity_min", operands[90])
	material_5.set_shader_parameter("radial_velocity_max", operands[91])
	material_5.set_shader_parameter("initial_angle_min", operands[92])
	material_5.set_shader_parameter("initial_angle_max", operands[93])
	material_5.set_shader_parameter("scale_min", operands[94])
	material_5.set_shader_parameter("scale_max", operands[95])
	material_5.set_shader_parameter("lifetime_randomness", operands[96])
	material_5.set_shader_parameter("emission_sphere_radius", operands[97])
	material_5.set_shader_parameter("color_value", operands[98])
	material_5.set_shader_parameter("gravity", operands[99])
	material_5.set_shader_parameter("color_ramp", operands[100])
	material_5.set_shader_parameter("alpha_curve", operands[101])
	material_5.set_shader_parameter("scale_curve", operands[102])
	material_5.set_meta("factory_prepared_shader", operands[103])
	material_5.set_meta("factory_clock_names", operands[104])
	material_5.set_meta("factory_opacity_prepared_shader", operands[105])
	material_5.set_meta("factory_native_process_source", operands[106])
	material_5.set_meta("factory_clock_pool_required", operands[107])
	material_5.set_meta("factory_fire_wall_world_units", operands[108])
	var material_6 := ShaderMaterial.new()
	material_6.shader = operands[109]
	material_6.set_shader_parameter("factory_world_to_source", operands[110])
	material_6.set_shader_parameter("source_tex", operands[111])
	material_6.set_meta("factory_occurrence_alpha", operands[112])
	material_6.set_meta("factory_prepared_shader", operands[113])
	material_6.set_meta("factory_opacity_prepared_shader", operands[114])
	material_6.set_meta("factory_clock_names", operands[115])
	material_6.set_meta("factory_clock_pool_required", operands[116])
	var material_7 := ShaderMaterial.new()
	material_7.shader = operands[117]
	material_7.set_shader_parameter("factory_world_to_source", operands[118])
	material_7.set_shader_parameter("sprite_sheet", operands[119])
	material_7.set_shader_parameter("gradient_1d_texture", operands[120])
	material_7.set_shader_parameter("frame_count", operands[121])
	material_7.set_shader_parameter("is_loop", operands[122])
	material_7.set_shader_parameter("uv_offset", operands[123])
	material_7.set_meta("factory_occurrence_alpha", operands[124])
	material_7.set_meta("factory_prepared_shader", operands[125])
	material_7.set_meta("factory_opacity_prepared_shader", operands[126])
	material_7.set_meta("factory_clock_names", operands[127])
	material_7.set_meta("factory_clock_pool_required", operands[128])
	var material_8 := ShaderMaterial.new()
	material_8.shader = operands[129]
	material_8.set_shader_parameter("factory_world_to_source", operands[130])
	material_8.set_shader_parameter("source_tex", operands[131])
	material_8.set_meta("factory_occurrence_alpha", operands[132])
	material_8.set_meta("factory_prepared_shader", operands[133])
	material_8.set_meta("factory_opacity_prepared_shader", operands[134])
	material_8.set_meta("factory_clock_names", operands[135])
	material_8.set_meta("factory_clock_pool_required", operands[136])
	var material_9 := ShaderMaterial.new()
	material_9.shader = operands[137]
	material_9.set_shader_parameter("factory_world_to_source", operands[138])
	material_9.set_shader_parameter("source_tex", operands[139])
	material_9.set_meta("factory_occurrence_alpha", operands[140])
	material_9.set_meta("factory_prepared_shader", operands[141])
	material_9.set_meta("factory_opacity_prepared_shader", operands[142])
	material_9.set_meta("factory_clock_names", operands[143])
	material_9.set_meta("factory_clock_pool_required", operands[144])
	var material_10 := ShaderMaterial.new()
	material_10.shader = operands[145]
	material_10.set_shader_parameter("factory_world_to_source", operands[146])
	material_10.set_shader_parameter("sprite_sheet", operands[147])
	material_10.set_shader_parameter("gradient_1d_texture", operands[148])
	material_10.set_shader_parameter("frame_count", operands[149])
	material_10.set_shader_parameter("is_loop", operands[150])
	material_10.set_shader_parameter("uv_offset", operands[151])
	material_10.set_meta("factory_occurrence_alpha", operands[152])
	material_10.set_meta("factory_prepared_shader", operands[153])
	material_10.set_meta("factory_opacity_prepared_shader", operands[154])
	material_10.set_meta("factory_clock_names", operands[155])
	material_10.set_meta("factory_clock_pool_required", operands[156])
	var material_11 := ShaderMaterial.new()
	material_11.shader = operands[157]
	material_11.set_shader_parameter("factory_world_to_source", operands[158])
	material_11.set_shader_parameter("source_tex", operands[159])
	material_11.set_meta("factory_occurrence_alpha", operands[160])
	material_11.set_meta("factory_prepared_shader", operands[161])
	material_11.set_meta("factory_opacity_prepared_shader", operands[162])
	material_11.set_meta("factory_clock_names", operands[163])
	material_11.set_meta("factory_clock_pool_required", operands[164])
	var material_12 := ShaderMaterial.new()
	material_12.shader = operands[165]
	material_12.set_shader_parameter("factory_world_to_source", operands[166])
	material_12.set_shader_parameter("source_tex", operands[167])
	material_12.set_meta("factory_occurrence_alpha", operands[168])
	material_12.set_meta("factory_prepared_shader", operands[169])
	material_12.set_meta("factory_opacity_prepared_shader", operands[170])
	material_12.set_meta("factory_clock_names", operands[171])
	material_12.set_meta("factory_clock_pool_required", operands[172])
	var material_13 := ShaderMaterial.new()
	material_13.shader = operands[173]
	material_13.set_shader_parameter("factory_world_to_source", operands[174])
	material_13.set_shader_parameter("sprite_sheet", operands[175])
	material_13.set_shader_parameter("gradient_1d_texture", operands[176])
	material_13.set_shader_parameter("frame_count", operands[177])
	material_13.set_shader_parameter("is_loop", operands[178])
	material_13.set_shader_parameter("uv_offset", operands[179])
	material_13.set_meta("factory_occurrence_alpha", operands[180])
	material_13.set_meta("factory_prepared_shader", operands[181])
	material_13.set_meta("factory_opacity_prepared_shader", operands[182])
	material_13.set_meta("factory_clock_names", operands[183])
	material_13.set_meta("factory_clock_pool_required", operands[184])
	var material_14 := ShaderMaterial.new()
	material_14.shader = operands[185]
	material_14.set_shader_parameter("factory_world_to_source", operands[186])
	material_14.set_shader_parameter("source_tex", operands[187])
	material_14.set_meta("factory_occurrence_alpha", operands[188])
	material_14.set_meta("factory_prepared_shader", operands[189])
	material_14.set_meta("factory_opacity_prepared_shader", operands[190])
	material_14.set_meta("factory_clock_names", operands[191])
	material_14.set_meta("factory_clock_pool_required", operands[192])
	var material_15 := ShaderMaterial.new()
	material_15.shader = operands[193]
	material_15.set_shader_parameter("factory_world_to_source", operands[194])
	material_15.set_shader_parameter("source_tex", operands[195])
	material_15.set_meta("factory_occurrence_alpha", operands[196])
	material_15.set_meta("factory_prepared_shader", operands[197])
	material_15.set_meta("factory_opacity_prepared_shader", operands[198])
	material_15.set_meta("factory_clock_names", operands[199])
	material_15.set_meta("factory_clock_pool_required", operands[200])
	var material_16 := ShaderMaterial.new()
	material_16.shader = operands[201]
	material_16.set_shader_parameter("factory_world_to_source", operands[202])
	material_16.set_shader_parameter("sprite_sheet", operands[203])
	material_16.set_shader_parameter("gradient_1d_texture", operands[204])
	material_16.set_shader_parameter("frame_count", operands[205])
	material_16.set_shader_parameter("is_loop", operands[206])
	material_16.set_shader_parameter("uv_offset", operands[207])
	material_16.set_meta("factory_occurrence_alpha", operands[208])
	material_16.set_meta("factory_prepared_shader", operands[209])
	material_16.set_meta("factory_opacity_prepared_shader", operands[210])
	material_16.set_meta("factory_clock_names", operands[211])
	material_16.set_meta("factory_clock_pool_required", operands[212])
	var material_17 := ShaderMaterial.new()
	material_17.shader = operands[213]
	material_17.set_shader_parameter("factory_world_to_source", operands[214])
	material_17.set_shader_parameter("source_tex", operands[215])
	material_17.set_meta("factory_occurrence_alpha", operands[216])
	material_17.set_meta("factory_prepared_shader", operands[217])
	material_17.set_meta("factory_opacity_prepared_shader", operands[218])
	material_17.set_meta("factory_clock_names", operands[219])
	material_17.set_meta("factory_clock_pool_required", operands[220])
	var material_18 := ShaderMaterial.new()
	material_18.shader = operands[221]
	material_18.set_shader_parameter("factory_world_to_source", operands[222])
	material_18.set_shader_parameter("source_tex", operands[223])
	material_18.set_meta("factory_occurrence_alpha", operands[224])
	material_18.set_meta("factory_prepared_shader", operands[225])
	material_18.set_meta("factory_opacity_prepared_shader", operands[226])
	material_18.set_meta("factory_clock_names", operands[227])
	material_18.set_meta("factory_clock_pool_required", operands[228])
	var material_19 := ShaderMaterial.new()
	material_19.shader = operands[229]
	material_19.set_shader_parameter("factory_world_to_source", operands[230])
	material_19.set_shader_parameter("sprite_sheet", operands[231])
	material_19.set_shader_parameter("gradient_1d_texture", operands[232])
	material_19.set_shader_parameter("frame_count", operands[233])
	material_19.set_shader_parameter("is_loop", operands[234])
	material_19.set_shader_parameter("uv_offset", operands[235])
	material_19.set_meta("factory_occurrence_alpha", operands[236])
	material_19.set_meta("factory_prepared_shader", operands[237])
	material_19.set_meta("factory_opacity_prepared_shader", operands[238])
	material_19.set_meta("factory_clock_names", operands[239])
	material_19.set_meta("factory_clock_pool_required", operands[240])
	var material_20 := ShaderMaterial.new()
	material_20.shader = operands[241]
	material_20.set_shader_parameter("factory_world_to_source", operands[242])
	material_20.set_shader_parameter("source_tex", operands[243])
	material_20.set_meta("factory_occurrence_alpha", operands[244])
	material_20.set_meta("factory_prepared_shader", operands[245])
	material_20.set_meta("factory_opacity_prepared_shader", operands[246])
	material_20.set_meta("factory_clock_names", operands[247])
	material_20.set_meta("factory_clock_pool_required", operands[248])
	var material_21 := ShaderMaterial.new()
	material_21.shader = operands[249]
	material_21.set_shader_parameter("factory_world_to_source", operands[250])
	material_21.set_shader_parameter("source_tex", operands[251])
	material_21.set_meta("factory_occurrence_alpha", operands[252])
	material_21.set_meta("factory_prepared_shader", operands[253])
	material_21.set_meta("factory_opacity_prepared_shader", operands[254])
	material_21.set_meta("factory_clock_names", operands[255])
	material_21.set_meta("factory_clock_pool_required", operands[256])
	var material_22 := ShaderMaterial.new()
	material_22.shader = operands[257]
	material_22.set_shader_parameter("factory_world_to_source", operands[258])
	material_22.set_shader_parameter("sprite_sheet", operands[259])
	material_22.set_shader_parameter("gradient_1d_texture", operands[260])
	material_22.set_shader_parameter("frame_count", operands[261])
	material_22.set_shader_parameter("is_loop", operands[262])
	material_22.set_shader_parameter("uv_offset", operands[263])
	material_22.set_meta("factory_occurrence_alpha", operands[264])
	material_22.set_meta("factory_prepared_shader", operands[265])
	material_22.set_meta("factory_opacity_prepared_shader", operands[266])
	material_22.set_meta("factory_clock_names", operands[267])
	material_22.set_meta("factory_clock_pool_required", operands[268])
	var material_23 := ShaderMaterial.new()
	material_23.shader = operands[269]
	material_23.set_shader_parameter("factory_world_to_source", operands[270])
	material_23.set_shader_parameter("source_tex", operands[271])
	material_23.set_meta("factory_occurrence_alpha", operands[272])
	material_23.set_meta("factory_prepared_shader", operands[273])
	material_23.set_meta("factory_opacity_prepared_shader", operands[274])
	material_23.set_meta("factory_clock_names", operands[275])
	material_23.set_meta("factory_clock_pool_required", operands[276])
	var material_24 := ShaderMaterial.new()
	material_24.shader = operands[277]
	material_24.set_shader_parameter("factory_world_to_source", operands[278])
	material_24.set_shader_parameter("source_tex", operands[279])
	material_24.set_meta("factory_occurrence_alpha", operands[280])
	material_24.set_meta("factory_prepared_shader", operands[281])
	material_24.set_meta("factory_opacity_prepared_shader", operands[282])
	material_24.set_meta("factory_clock_names", operands[283])
	material_24.set_meta("factory_clock_pool_required", operands[284])
	var material_25 := ShaderMaterial.new()
	material_25.shader = operands[285]
	material_25.set_shader_parameter("factory_world_to_source", operands[286])
	material_25.set_shader_parameter("sprite_sheet", operands[287])
	material_25.set_shader_parameter("gradient_1d_texture", operands[288])
	material_25.set_shader_parameter("frame_count", operands[289])
	material_25.set_shader_parameter("is_loop", operands[290])
	material_25.set_shader_parameter("uv_offset", operands[291])
	material_25.set_meta("factory_occurrence_alpha", operands[292])
	material_25.set_meta("factory_prepared_shader", operands[293])
	material_25.set_meta("factory_opacity_prepared_shader", operands[294])
	material_25.set_meta("factory_clock_names", operands[295])
	material_25.set_meta("factory_clock_pool_required", operands[296])
	var material_26 := ShaderMaterial.new()
	material_26.shader = operands[297]
	material_26.set_shader_parameter("factory_world_to_source", operands[298])
	material_26.set_shader_parameter("source_tex", operands[299])
	material_26.set_meta("factory_occurrence_alpha", operands[300])
	material_26.set_meta("factory_prepared_shader", operands[301])
	material_26.set_meta("factory_opacity_prepared_shader", operands[302])
	material_26.set_meta("factory_clock_names", operands[303])
	material_26.set_meta("factory_clock_pool_required", operands[304])
	var material_27 := ShaderMaterial.new()
	material_27.shader = operands[305]
	material_27.set_shader_parameter("factory_world_to_source", operands[306])
	material_27.set_shader_parameter("source_tex", operands[307])
	material_27.set_meta("factory_occurrence_alpha", operands[308])
	material_27.set_meta("factory_prepared_shader", operands[309])
	material_27.set_meta("factory_opacity_prepared_shader", operands[310])
	material_27.set_meta("factory_clock_names", operands[311])
	material_27.set_meta("factory_clock_pool_required", operands[312])
	var material_28 := ShaderMaterial.new()
	material_28.shader = operands[313]
	material_28.set_shader_parameter("factory_world_to_source", operands[314])
	material_28.set_shader_parameter("sprite_sheet", operands[315])
	material_28.set_shader_parameter("gradient_1d_texture", operands[316])
	material_28.set_shader_parameter("frame_count", operands[317])
	material_28.set_shader_parameter("is_loop", operands[318])
	material_28.set_shader_parameter("uv_offset", operands[319])
	material_28.set_meta("factory_occurrence_alpha", operands[320])
	material_28.set_meta("factory_prepared_shader", operands[321])
	material_28.set_meta("factory_opacity_prepared_shader", operands[322])
	material_28.set_meta("factory_clock_names", operands[323])
	material_28.set_meta("factory_clock_pool_required", operands[324])
	var material_29 := ShaderMaterial.new()
	material_29.shader = operands[325]
	material_29.set_shader_parameter("factory_world_to_source", operands[326])
	material_29.set_shader_parameter("source_tex", operands[327])
	material_29.set_meta("factory_occurrence_alpha", operands[328])
	material_29.set_meta("factory_prepared_shader", operands[329])
	material_29.set_meta("factory_opacity_prepared_shader", operands[330])
	material_29.set_meta("factory_clock_names", operands[331])
	material_29.set_meta("factory_clock_pool_required", operands[332])
	var material_30 := ShaderMaterial.new()
	material_30.shader = operands[333]
	material_30.set_shader_parameter("factory_world_to_source", operands[334])
	material_30.set_shader_parameter("source_tex", operands[335])
	material_30.set_meta("factory_occurrence_alpha", operands[336])
	material_30.set_meta("factory_prepared_shader", operands[337])
	material_30.set_meta("factory_opacity_prepared_shader", operands[338])
	material_30.set_meta("factory_clock_names", operands[339])
	material_30.set_meta("factory_clock_pool_required", operands[340])
	var material_31 := ShaderMaterial.new()
	material_31.shader = operands[341]
	material_31.set_shader_parameter("factory_world_to_source", operands[342])
	material_31.set_shader_parameter("sprite_sheet", operands[343])
	material_31.set_shader_parameter("gradient_1d_texture", operands[344])
	material_31.set_shader_parameter("frame_count", operands[345])
	material_31.set_shader_parameter("is_loop", operands[346])
	material_31.set_shader_parameter("uv_offset", operands[347])
	material_31.set_meta("factory_occurrence_alpha", operands[348])
	material_31.set_meta("factory_prepared_shader", operands[349])
	material_31.set_meta("factory_opacity_prepared_shader", operands[350])
	material_31.set_meta("factory_clock_names", operands[351])
	material_31.set_meta("factory_clock_pool_required", operands[352])
	var material_32 := ShaderMaterial.new()
	material_32.shader = operands[353]
	material_32.set_shader_parameter("factory_world_to_source", operands[354])
	material_32.set_shader_parameter("source_tex", operands[355])
	material_32.set_meta("factory_occurrence_alpha", operands[356])
	material_32.set_meta("factory_prepared_shader", operands[357])
	material_32.set_meta("factory_opacity_prepared_shader", operands[358])
	material_32.set_meta("factory_clock_names", operands[359])
	material_32.set_meta("factory_clock_pool_required", operands[360])
	var material_33 := ShaderMaterial.new()
	material_33.shader = operands[361]
	material_33.set_shader_parameter("factory_world_to_source", operands[362])
	material_33.set_shader_parameter("source_tex", operands[363])
	material_33.set_meta("factory_occurrence_alpha", operands[364])
	material_33.set_meta("factory_prepared_shader", operands[365])
	material_33.set_meta("factory_opacity_prepared_shader", operands[366])
	material_33.set_meta("factory_clock_names", operands[367])
	material_33.set_meta("factory_clock_pool_required", operands[368])
	var material_34 := ShaderMaterial.new()
	material_34.shader = operands[369]
	material_34.set_shader_parameter("factory_world_to_source", operands[370])
	material_34.set_shader_parameter("sprite_sheet", operands[371])
	material_34.set_shader_parameter("gradient_1d_texture", operands[372])
	material_34.set_shader_parameter("frame_count", operands[373])
	material_34.set_shader_parameter("is_loop", operands[374])
	material_34.set_shader_parameter("uv_offset", operands[375])
	material_34.set_meta("factory_occurrence_alpha", operands[376])
	material_34.set_meta("factory_prepared_shader", operands[377])
	material_34.set_meta("factory_opacity_prepared_shader", operands[378])
	material_34.set_meta("factory_clock_names", operands[379])
	material_34.set_meta("factory_clock_pool_required", operands[380])
	var material_35 := ShaderMaterial.new()
	material_35.shader = operands[381]
	material_35.set_shader_parameter("factory_world_to_source", operands[382])
	material_35.set_shader_parameter("source_tex", operands[383])
	material_35.set_meta("factory_occurrence_alpha", operands[384])
	material_35.set_meta("factory_prepared_shader", operands[385])
	material_35.set_meta("factory_opacity_prepared_shader", operands[386])
	material_35.set_meta("factory_clock_names", operands[387])
	material_35.set_meta("factory_clock_pool_required", operands[388])
	var material_36 := ShaderMaterial.new()
	material_36.shader = operands[389]
	material_36.set_shader_parameter("factory_world_to_source", operands[390])
	material_36.set_shader_parameter("source_tex", operands[391])
	material_36.set_meta("factory_occurrence_alpha", operands[392])
	material_36.set_meta("factory_prepared_shader", operands[393])
	material_36.set_meta("factory_opacity_prepared_shader", operands[394])
	material_36.set_meta("factory_clock_names", operands[395])
	material_36.set_meta("factory_clock_pool_required", operands[396])
	var material_37 := ShaderMaterial.new()
	material_37.shader = operands[397]
	material_37.set_shader_parameter("factory_world_to_source", operands[398])
	material_37.set_shader_parameter("sprite_sheet", operands[399])
	material_37.set_shader_parameter("gradient_1d_texture", operands[400])
	material_37.set_shader_parameter("frame_count", operands[401])
	material_37.set_shader_parameter("is_loop", operands[402])
	material_37.set_shader_parameter("uv_offset", operands[403])
	material_37.set_meta("factory_occurrence_alpha", operands[404])
	material_37.set_meta("factory_prepared_shader", operands[405])
	material_37.set_meta("factory_opacity_prepared_shader", operands[406])
	material_37.set_meta("factory_clock_names", operands[407])
	material_37.set_meta("factory_clock_pool_required", operands[408])
	var material_38 := ShaderMaterial.new()
	material_38.shader = operands[409]
	material_38.set_shader_parameter("factory_world_to_source", operands[410])
	material_38.set_shader_parameter("source_tex", operands[411])
	material_38.set_meta("factory_occurrence_alpha", operands[412])
	material_38.set_meta("factory_prepared_shader", operands[413])
	material_38.set_meta("factory_opacity_prepared_shader", operands[414])
	material_38.set_meta("factory_clock_names", operands[415])
	material_38.set_meta("factory_clock_pool_required", operands[416])
	var material_39 := ShaderMaterial.new()
	material_39.shader = operands[417]
	material_39.set_shader_parameter("factory_world_to_source", operands[418])
	material_39.set_shader_parameter("source_tex", operands[419])
	material_39.set_meta("factory_occurrence_alpha", operands[420])
	material_39.set_meta("factory_prepared_shader", operands[421])
	material_39.set_meta("factory_opacity_prepared_shader", operands[422])
	material_39.set_meta("factory_clock_names", operands[423])
	material_39.set_meta("factory_clock_pool_required", operands[424])
	var material_40 := ShaderMaterial.new()
	material_40.shader = operands[425]
	material_40.set_shader_parameter("factory_world_to_source", operands[426])
	material_40.set_shader_parameter("sprite_sheet", operands[427])
	material_40.set_shader_parameter("gradient_1d_texture", operands[428])
	material_40.set_shader_parameter("frame_count", operands[429])
	material_40.set_shader_parameter("is_loop", operands[430])
	material_40.set_shader_parameter("uv_offset", operands[431])
	material_40.set_meta("factory_occurrence_alpha", operands[432])
	material_40.set_meta("factory_prepared_shader", operands[433])
	material_40.set_meta("factory_opacity_prepared_shader", operands[434])
	material_40.set_meta("factory_clock_names", operands[435])
	material_40.set_meta("factory_clock_pool_required", operands[436])
	var material_41 := ShaderMaterial.new()
	material_41.shader = operands[437]
	material_41.set_shader_parameter("factory_world_to_source", operands[438])
	material_41.set_shader_parameter("source_tex", operands[439])
	material_41.set_meta("factory_occurrence_alpha", operands[440])
	material_41.set_meta("factory_prepared_shader", operands[441])
	material_41.set_meta("factory_opacity_prepared_shader", operands[442])
	material_41.set_meta("factory_clock_names", operands[443])
	material_41.set_meta("factory_clock_pool_required", operands[444])
	var material_42 := ShaderMaterial.new()
	material_42.shader = operands[445]
	material_42.set_shader_parameter("factory_world_to_source", operands[446])
	material_42.set_shader_parameter("source_tex", operands[447])
	material_42.set_meta("factory_occurrence_alpha", operands[448])
	material_42.set_meta("factory_prepared_shader", operands[449])
	material_42.set_meta("factory_opacity_prepared_shader", operands[450])
	material_42.set_meta("factory_clock_names", operands[451])
	material_42.set_meta("factory_clock_pool_required", operands[452])
	var material_43 := ShaderMaterial.new()
	material_43.shader = operands[453]
	material_43.set_shader_parameter("factory_world_to_source", operands[454])
	material_43.set_shader_parameter("sprite_sheet", operands[455])
	material_43.set_shader_parameter("gradient_1d_texture", operands[456])
	material_43.set_shader_parameter("frame_count", operands[457])
	material_43.set_shader_parameter("is_loop", operands[458])
	material_43.set_shader_parameter("uv_offset", operands[459])
	material_43.set_meta("factory_occurrence_alpha", operands[460])
	material_43.set_meta("factory_prepared_shader", operands[461])
	material_43.set_meta("factory_opacity_prepared_shader", operands[462])
	material_43.set_meta("factory_clock_names", operands[463])
	material_43.set_meta("factory_clock_pool_required", operands[464])
	var material_44 := ShaderMaterial.new()
	material_44.shader = operands[465]
	material_44.set_shader_parameter("factory_world_to_source", operands[466])
	material_44.set_shader_parameter("source_tex", operands[467])
	material_44.set_meta("factory_occurrence_alpha", operands[468])
	material_44.set_meta("factory_prepared_shader", operands[469])
	material_44.set_meta("factory_opacity_prepared_shader", operands[470])
	material_44.set_meta("factory_clock_names", operands[471])
	material_44.set_meta("factory_clock_pool_required", operands[472])
	var material_45 := ShaderMaterial.new()
	material_45.shader = operands[473]
	material_45.set_shader_parameter("factory_world_to_source", operands[474])
	material_45.set_shader_parameter("source_tex", operands[475])
	material_45.set_meta("factory_occurrence_alpha", operands[476])
	material_45.set_meta("factory_prepared_shader", operands[477])
	material_45.set_meta("factory_opacity_prepared_shader", operands[478])
	material_45.set_meta("factory_clock_names", operands[479])
	material_45.set_meta("factory_clock_pool_required", operands[480])
	var material_46 := ShaderMaterial.new()
	material_46.shader = operands[481]
	material_46.set_shader_parameter("factory_world_to_source", operands[482])
	material_46.set_shader_parameter("sprite_sheet", operands[483])
	material_46.set_shader_parameter("gradient_1d_texture", operands[484])
	material_46.set_shader_parameter("frame_count", operands[485])
	material_46.set_shader_parameter("is_loop", operands[486])
	material_46.set_shader_parameter("uv_offset", operands[487])
	material_46.set_meta("factory_occurrence_alpha", operands[488])
	material_46.set_meta("factory_prepared_shader", operands[489])
	material_46.set_meta("factory_opacity_prepared_shader", operands[490])
	material_46.set_meta("factory_clock_names", operands[491])
	material_46.set_meta("factory_clock_pool_required", operands[492])
	var material_47 := ShaderMaterial.new()
	material_47.shader = operands[493]
	material_47.set_shader_parameter("factory_world_to_source", operands[494])
	material_47.set_shader_parameter("source_tex", operands[495])
	material_47.set_meta("factory_occurrence_alpha", operands[496])
	material_47.set_meta("factory_prepared_shader", operands[497])
	material_47.set_meta("factory_opacity_prepared_shader", operands[498])
	material_47.set_meta("factory_clock_names", operands[499])
	material_47.set_meta("factory_clock_pool_required", operands[500])
	var material_48 := ShaderMaterial.new()
	material_48.shader = operands[501]
	material_48.set_shader_parameter("factory_world_to_source", operands[502])
	material_48.set_shader_parameter("source_tex", operands[503])
	material_48.set_meta("factory_occurrence_alpha", operands[504])
	material_48.set_meta("factory_prepared_shader", operands[505])
	material_48.set_meta("factory_opacity_prepared_shader", operands[506])
	material_48.set_meta("factory_clock_names", operands[507])
	material_48.set_meta("factory_clock_pool_required", operands[508])
	var material_49 := ShaderMaterial.new()
	material_49.shader = operands[509]
	material_49.set_shader_parameter("factory_world_to_source", operands[510])
	material_49.set_shader_parameter("sprite_sheet", operands[511])
	material_49.set_shader_parameter("gradient_1d_texture", operands[512])
	material_49.set_shader_parameter("frame_count", operands[513])
	material_49.set_shader_parameter("is_loop", operands[514])
	material_49.set_shader_parameter("uv_offset", operands[515])
	material_49.set_meta("factory_occurrence_alpha", operands[516])
	material_49.set_meta("factory_prepared_shader", operands[517])
	material_49.set_meta("factory_opacity_prepared_shader", operands[518])
	material_49.set_meta("factory_clock_names", operands[519])
	material_49.set_meta("factory_clock_pool_required", operands[520])
	var material_50 := ShaderMaterial.new()
	material_50.shader = operands[521]
	material_50.set_shader_parameter("factory_world_to_source", operands[522])
	material_50.set_shader_parameter("source_tex", operands[523])
	material_50.set_meta("factory_occurrence_alpha", operands[524])
	material_50.set_meta("factory_prepared_shader", operands[525])
	material_50.set_meta("factory_opacity_prepared_shader", operands[526])
	material_50.set_meta("factory_clock_names", operands[527])
	material_50.set_meta("factory_clock_pool_required", operands[528])
	var material_51 := ShaderMaterial.new()
	material_51.shader = operands[529]
	material_51.set_shader_parameter("factory_world_to_source", operands[530])
	material_51.set_shader_parameter("source_tex", operands[531])
	material_51.set_meta("factory_occurrence_alpha", operands[532])
	material_51.set_meta("factory_prepared_shader", operands[533])
	material_51.set_meta("factory_opacity_prepared_shader", operands[534])
	material_51.set_meta("factory_clock_names", operands[535])
	material_51.set_meta("factory_clock_pool_required", operands[536])
	var material_52 := ShaderMaterial.new()
	material_52.shader = operands[537]
	material_52.set_shader_parameter("factory_world_to_source", operands[538])
	material_52.set_shader_parameter("sprite_sheet", operands[539])
	material_52.set_shader_parameter("gradient_1d_texture", operands[540])
	material_52.set_shader_parameter("frame_count", operands[541])
	material_52.set_shader_parameter("is_loop", operands[542])
	material_52.set_shader_parameter("uv_offset", operands[543])
	material_52.set_meta("factory_occurrence_alpha", operands[544])
	material_52.set_meta("factory_prepared_shader", operands[545])
	material_52.set_meta("factory_opacity_prepared_shader", operands[546])
	material_52.set_meta("factory_clock_names", operands[547])
	material_52.set_meta("factory_clock_pool_required", operands[548])
	var material_53 := ShaderMaterial.new()
	material_53.shader = operands[549]
	material_53.set_shader_parameter("factory_world_to_source", operands[550])
	material_53.set_shader_parameter("source_tex", operands[551])
	material_53.set_meta("factory_occurrence_alpha", operands[552])
	material_53.set_meta("factory_prepared_shader", operands[553])
	material_53.set_meta("factory_opacity_prepared_shader", operands[554])
	material_53.set_meta("factory_clock_names", operands[555])
	material_53.set_meta("factory_clock_pool_required", operands[556])
	var material_54 := ShaderMaterial.new()
	material_54.shader = operands[557]
	material_54.set_shader_parameter("factory_world_to_source", operands[558])
	material_54.set_shader_parameter("source_tex", operands[559])
	material_54.set_meta("factory_occurrence_alpha", operands[560])
	material_54.set_meta("factory_prepared_shader", operands[561])
	material_54.set_meta("factory_opacity_prepared_shader", operands[562])
	material_54.set_meta("factory_clock_names", operands[563])
	material_54.set_meta("factory_clock_pool_required", operands[564])
	var material_55 := ShaderMaterial.new()
	material_55.shader = operands[565]
	material_55.set_shader_parameter("factory_world_to_source", operands[566])
	material_55.set_shader_parameter("sprite_sheet", operands[567])
	material_55.set_shader_parameter("gradient_1d_texture", operands[568])
	material_55.set_shader_parameter("frame_count", operands[569])
	material_55.set_shader_parameter("is_loop", operands[570])
	material_55.set_shader_parameter("uv_offset", operands[571])
	material_55.set_meta("factory_occurrence_alpha", operands[572])
	material_55.set_meta("factory_prepared_shader", operands[573])
	material_55.set_meta("factory_opacity_prepared_shader", operands[574])
	material_55.set_meta("factory_clock_names", operands[575])
	material_55.set_meta("factory_clock_pool_required", operands[576])
	var material_56 := ShaderMaterial.new()
	material_56.shader = operands[577]
	material_56.set_shader_parameter("factory_world_to_source", operands[578])
	material_56.set_shader_parameter("source_tex", operands[579])
	material_56.set_meta("factory_occurrence_alpha", operands[580])
	material_56.set_meta("factory_prepared_shader", operands[581])
	material_56.set_meta("factory_opacity_prepared_shader", operands[582])
	material_56.set_meta("factory_clock_names", operands[583])
	material_56.set_meta("factory_clock_pool_required", operands[584])
	var material_57 := ShaderMaterial.new()
	material_57.shader = operands[585]
	material_57.set_shader_parameter("factory_world_to_source", operands[586])
	material_57.set_shader_parameter("source_tex", operands[587])
	material_57.set_meta("factory_occurrence_alpha", operands[588])
	material_57.set_meta("factory_prepared_shader", operands[589])
	material_57.set_meta("factory_opacity_prepared_shader", operands[590])
	material_57.set_meta("factory_clock_names", operands[591])
	material_57.set_meta("factory_clock_pool_required", operands[592])
	var material_58 := ShaderMaterial.new()
	material_58.shader = operands[593]
	material_58.set_shader_parameter("factory_world_to_source", operands[594])
	material_58.set_shader_parameter("sprite_sheet", operands[595])
	material_58.set_shader_parameter("gradient_1d_texture", operands[596])
	material_58.set_shader_parameter("frame_count", operands[597])
	material_58.set_shader_parameter("is_loop", operands[598])
	material_58.set_shader_parameter("uv_offset", operands[599])
	material_58.set_meta("factory_occurrence_alpha", operands[600])
	material_58.set_meta("factory_prepared_shader", operands[601])
	material_58.set_meta("factory_opacity_prepared_shader", operands[602])
	material_58.set_meta("factory_clock_names", operands[603])
	material_58.set_meta("factory_clock_pool_required", operands[604])
	var material_59 := ShaderMaterial.new()
	material_59.shader = operands[605]
	material_59.set_shader_parameter("factory_world_to_source", operands[606])
	material_59.set_shader_parameter("source_tex", operands[607])
	material_59.set_meta("factory_occurrence_alpha", operands[608])
	material_59.set_meta("factory_prepared_shader", operands[609])
	material_59.set_meta("factory_opacity_prepared_shader", operands[610])
	material_59.set_meta("factory_clock_names", operands[611])
	material_59.set_meta("factory_clock_pool_required", operands[612])
	var material_60 := ShaderMaterial.new()
	material_60.shader = operands[613]
	material_60.set_shader_parameter("factory_world_to_source", operands[614])
	material_60.set_shader_parameter("source_tex", operands[615])
	material_60.set_meta("factory_occurrence_alpha", operands[616])
	material_60.set_meta("factory_prepared_shader", operands[617])
	material_60.set_meta("factory_opacity_prepared_shader", operands[618])
	material_60.set_meta("factory_clock_names", operands[619])
	material_60.set_meta("factory_clock_pool_required", operands[620])
	var material_61 := ShaderMaterial.new()
	material_61.shader = operands[621]
	material_61.set_shader_parameter("factory_world_to_source", operands[622])
	material_61.set_shader_parameter("sprite_sheet", operands[623])
	material_61.set_shader_parameter("gradient_1d_texture", operands[624])
	material_61.set_shader_parameter("frame_count", operands[625])
	material_61.set_shader_parameter("is_loop", operands[626])
	material_61.set_shader_parameter("uv_offset", operands[627])
	material_61.set_meta("factory_occurrence_alpha", operands[628])
	material_61.set_meta("factory_prepared_shader", operands[629])
	material_61.set_meta("factory_opacity_prepared_shader", operands[630])
	material_61.set_meta("factory_clock_names", operands[631])
	material_61.set_meta("factory_clock_pool_required", operands[632])
	var material_62 := ShaderMaterial.new()
	material_62.shader = operands[633]
	material_62.set_shader_parameter("factory_world_to_source", operands[634])
	material_62.set_shader_parameter("source_tex", operands[635])
	material_62.set_meta("factory_occurrence_alpha", operands[636])
	material_62.set_meta("factory_prepared_shader", operands[637])
	material_62.set_meta("factory_opacity_prepared_shader", operands[638])
	material_62.set_meta("factory_clock_names", operands[639])
	material_62.set_meta("factory_clock_pool_required", operands[640])
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "FactoryGenerated_0000_Node3D"
	var node_1 := Node3D.new()
	node_1.name = "flame_0"
	node_1.transform = operands[641]
	node_0.add_child(node_1)
	var node_2 := Node3D.new()
	node_2.name = "effect"
	node_1.add_child(node_2)
	var node_3 := Node3D.new()
	node_3.name = "Donor"
	node_3.transform = operands[642]
	node_2.add_child(node_3)
	var node_4 := GPUParticles3D.new()
	node_4.name = "firepops"
	node_4.visible = operands[643]
	node_4.layers = operands[644]
	node_4.material_override = material_0
	node_4.cast_shadow = operands[645]
	node_4.amount = operands[646]
	node_4.lifetime = operands[647]
	node_4.use_fixed_seed = operands[648]
	node_4.seed = operands[649]
	node_4.fixed_fps = operands[650]
	node_4.process_material = material_1
	node_4.draw_pass_1 = operands[651]
	node_3.add_child(node_4)
	var node_5 := GPUParticles3D.new()
	node_5.name = "firebursts"
	node_5.material_override = material_2
	node_5.cast_shadow = operands[652]
	node_5.amount = operands[653]
	node_5.lifetime = operands[654]
	node_5.preprocess = operands[655]
	node_5.use_fixed_seed = operands[656]
	node_5.seed = operands[657]
	node_5.fixed_fps = operands[658]
	node_5.draw_order = operands[659]
	node_5.process_material = material_3
	node_5.draw_pass_1 = operands[660]
	node_3.add_child(node_5)
	var node_6 := GPUParticles3D.new()
	node_6.name = "UnequalRisingFlames"
	node_6.transform = operands[661]
	node_6.material_override = material_4
	node_6.cast_shadow = operands[662]
	node_6.amount = operands[663]
	node_6.preprocess = operands[664]
	node_6.use_fixed_seed = operands[665]
	node_6.seed = operands[666]
	node_6.fixed_fps = operands[667]
	node_6.visibility_aabb = operands[668]
	node_6.draw_order = operands[669]
	node_6.process_material = material_5
	node_6.draw_pass_1 = operands[670]
	node_3.add_child(node_6)
	var node_7 := Node3D.new()
	node_7.name = "flame_1"
	node_7.transform = operands[671]
	node_0.add_child(node_7)
	var node_8 := Node3D.new()
	node_8.name = "effect"
	node_7.add_child(node_8)
	var node_9 := Node3D.new()
	node_9.name = "Donor"
	node_9.transform = operands[672]
	node_8.add_child(node_9)
	var node_10 := GPUParticles3D.new()
	node_10.name = "firepops"
	node_10.visible = operands[673]
	node_10.layers = operands[674]
	node_10.material_override = material_6
	node_10.cast_shadow = operands[675]
	node_10.amount = operands[676]
	node_10.lifetime = operands[677]
	node_10.use_fixed_seed = operands[678]
	node_10.seed = operands[679]
	node_10.fixed_fps = operands[680]
	node_10.process_material = material_1
	node_10.draw_pass_1 = operands[681]
	node_9.add_child(node_10)
	var node_11 := GPUParticles3D.new()
	node_11.name = "firebursts"
	node_11.material_override = material_7
	node_11.cast_shadow = operands[682]
	node_11.amount = operands[683]
	node_11.lifetime = operands[684]
	node_11.preprocess = operands[685]
	node_11.use_fixed_seed = operands[686]
	node_11.seed = operands[687]
	node_11.fixed_fps = operands[688]
	node_11.draw_order = operands[689]
	node_11.process_material = material_3
	node_11.draw_pass_1 = operands[690]
	node_9.add_child(node_11)
	var node_12 := GPUParticles3D.new()
	node_12.name = "UnequalRisingFlames"
	node_12.transform = operands[691]
	node_12.material_override = material_8
	node_12.cast_shadow = operands[692]
	node_12.preprocess = operands[693]
	node_12.use_fixed_seed = operands[694]
	node_12.seed = operands[695]
	node_12.fixed_fps = operands[696]
	node_12.visibility_aabb = operands[697]
	node_12.draw_order = operands[698]
	node_12.process_material = material_5
	node_12.draw_pass_1 = operands[699]
	node_9.add_child(node_12)
	var node_13 := Node3D.new()
	node_13.name = "flame_2"
	node_13.transform = operands[700]
	node_0.add_child(node_13)
	var node_14 := Node3D.new()
	node_14.name = "effect"
	node_13.add_child(node_14)
	var node_15 := Node3D.new()
	node_15.name = "Donor"
	node_15.transform = operands[701]
	node_14.add_child(node_15)
	var node_16 := GPUParticles3D.new()
	node_16.name = "firepops"
	node_16.visible = operands[702]
	node_16.layers = operands[703]
	node_16.material_override = material_9
	node_16.cast_shadow = operands[704]
	node_16.amount = operands[705]
	node_16.lifetime = operands[706]
	node_16.use_fixed_seed = operands[707]
	node_16.seed = operands[708]
	node_16.fixed_fps = operands[709]
	node_16.process_material = material_1
	node_16.draw_pass_1 = operands[710]
	node_15.add_child(node_16)
	var node_17 := GPUParticles3D.new()
	node_17.name = "firebursts"
	node_17.material_override = material_10
	node_17.cast_shadow = operands[711]
	node_17.amount = operands[712]
	node_17.lifetime = operands[713]
	node_17.preprocess = operands[714]
	node_17.use_fixed_seed = operands[715]
	node_17.seed = operands[716]
	node_17.fixed_fps = operands[717]
	node_17.draw_order = operands[718]
	node_17.process_material = material_3
	node_17.draw_pass_1 = operands[719]
	node_15.add_child(node_17)
	var node_18 := GPUParticles3D.new()
	node_18.name = "UnequalRisingFlames"
	node_18.transform = operands[720]
	node_18.material_override = material_11
	node_18.cast_shadow = operands[721]
	node_18.amount = operands[722]
	node_18.preprocess = operands[723]
	node_18.use_fixed_seed = operands[724]
	node_18.seed = operands[725]
	node_18.fixed_fps = operands[726]
	node_18.visibility_aabb = operands[727]
	node_18.draw_order = operands[728]
	node_18.process_material = material_5
	node_18.draw_pass_1 = operands[729]
	node_15.add_child(node_18)
	var node_19 := Node3D.new()
	node_19.name = "flame_3"
	node_19.transform = operands[730]
	node_0.add_child(node_19)
	var node_20 := Node3D.new()
	node_20.name = "effect"
	node_19.add_child(node_20)
	var node_21 := Node3D.new()
	node_21.name = "Donor"
	node_21.transform = operands[731]
	node_20.add_child(node_21)
	var node_22 := GPUParticles3D.new()
	node_22.name = "firepops"
	node_22.visible = operands[732]
	node_22.layers = operands[733]
	node_22.material_override = material_12
	node_22.cast_shadow = operands[734]
	node_22.amount = operands[735]
	node_22.lifetime = operands[736]
	node_22.use_fixed_seed = operands[737]
	node_22.seed = operands[738]
	node_22.fixed_fps = operands[739]
	node_22.process_material = material_1
	node_22.draw_pass_1 = operands[740]
	node_21.add_child(node_22)
	var node_23 := GPUParticles3D.new()
	node_23.name = "firebursts"
	node_23.material_override = material_13
	node_23.cast_shadow = operands[741]
	node_23.amount = operands[742]
	node_23.lifetime = operands[743]
	node_23.preprocess = operands[744]
	node_23.use_fixed_seed = operands[745]
	node_23.seed = operands[746]
	node_23.fixed_fps = operands[747]
	node_23.draw_order = operands[748]
	node_23.process_material = material_3
	node_23.draw_pass_1 = operands[749]
	node_21.add_child(node_23)
	var node_24 := GPUParticles3D.new()
	node_24.name = "UnequalRisingFlames"
	node_24.transform = operands[750]
	node_24.material_override = material_14
	node_24.cast_shadow = operands[751]
	node_24.preprocess = operands[752]
	node_24.use_fixed_seed = operands[753]
	node_24.seed = operands[754]
	node_24.fixed_fps = operands[755]
	node_24.visibility_aabb = operands[756]
	node_24.draw_order = operands[757]
	node_24.process_material = material_5
	node_24.draw_pass_1 = operands[758]
	node_21.add_child(node_24)
	var node_25 := Node3D.new()
	node_25.name = "flame_4"
	node_25.transform = operands[759]
	node_0.add_child(node_25)
	var node_26 := Node3D.new()
	node_26.name = "effect"
	node_25.add_child(node_26)
	var node_27 := Node3D.new()
	node_27.name = "Donor"
	node_27.transform = operands[760]
	node_26.add_child(node_27)
	var node_28 := GPUParticles3D.new()
	node_28.name = "firepops"
	node_28.visible = operands[761]
	node_28.layers = operands[762]
	node_28.material_override = material_15
	node_28.cast_shadow = operands[763]
	node_28.amount = operands[764]
	node_28.lifetime = operands[765]
	node_28.use_fixed_seed = operands[766]
	node_28.seed = operands[767]
	node_28.fixed_fps = operands[768]
	node_28.process_material = material_1
	node_28.draw_pass_1 = operands[769]
	node_27.add_child(node_28)
	var node_29 := GPUParticles3D.new()
	node_29.name = "firebursts"
	node_29.material_override = material_16
	node_29.cast_shadow = operands[770]
	node_29.amount = operands[771]
	node_29.lifetime = operands[772]
	node_29.preprocess = operands[773]
	node_29.use_fixed_seed = operands[774]
	node_29.seed = operands[775]
	node_29.fixed_fps = operands[776]
	node_29.draw_order = operands[777]
	node_29.process_material = material_3
	node_29.draw_pass_1 = operands[778]
	node_27.add_child(node_29)
	var node_30 := GPUParticles3D.new()
	node_30.name = "UnequalRisingFlames"
	node_30.transform = operands[779]
	node_30.material_override = material_17
	node_30.cast_shadow = operands[780]
	node_30.amount = operands[781]
	node_30.preprocess = operands[782]
	node_30.use_fixed_seed = operands[783]
	node_30.seed = operands[784]
	node_30.fixed_fps = operands[785]
	node_30.visibility_aabb = operands[786]
	node_30.draw_order = operands[787]
	node_30.process_material = material_5
	node_30.draw_pass_1 = operands[788]
	node_27.add_child(node_30)
	var node_31 := Node3D.new()
	node_31.name = "flame_5"
	node_31.transform = operands[789]
	node_0.add_child(node_31)
	var node_32 := Node3D.new()
	node_32.name = "effect"
	node_31.add_child(node_32)
	var node_33 := Node3D.new()
	node_33.name = "Donor"
	node_33.transform = operands[790]
	node_32.add_child(node_33)
	var node_34 := GPUParticles3D.new()
	node_34.name = "firepops"
	node_34.visible = operands[791]
	node_34.layers = operands[792]
	node_34.material_override = material_18
	node_34.cast_shadow = operands[793]
	node_34.amount = operands[794]
	node_34.lifetime = operands[795]
	node_34.use_fixed_seed = operands[796]
	node_34.seed = operands[797]
	node_34.fixed_fps = operands[798]
	node_34.process_material = material_1
	node_34.draw_pass_1 = operands[799]
	node_33.add_child(node_34)
	var node_35 := GPUParticles3D.new()
	node_35.name = "firebursts"
	node_35.material_override = material_19
	node_35.cast_shadow = operands[800]
	node_35.amount = operands[801]
	node_35.lifetime = operands[802]
	node_35.preprocess = operands[803]
	node_35.use_fixed_seed = operands[804]
	node_35.seed = operands[805]
	node_35.fixed_fps = operands[806]
	node_35.draw_order = operands[807]
	node_35.process_material = material_3
	node_35.draw_pass_1 = operands[808]
	node_33.add_child(node_35)
	var node_36 := GPUParticles3D.new()
	node_36.name = "UnequalRisingFlames"
	node_36.transform = operands[809]
	node_36.material_override = material_20
	node_36.cast_shadow = operands[810]
	node_36.preprocess = operands[811]
	node_36.use_fixed_seed = operands[812]
	node_36.seed = operands[813]
	node_36.fixed_fps = operands[814]
	node_36.visibility_aabb = operands[815]
	node_36.draw_order = operands[816]
	node_36.process_material = material_5
	node_36.draw_pass_1 = operands[817]
	node_33.add_child(node_36)
	var node_37 := Node3D.new()
	node_37.name = "flame_6"
	node_37.transform = operands[818]
	node_0.add_child(node_37)
	var node_38 := Node3D.new()
	node_38.name = "effect"
	node_37.add_child(node_38)
	var node_39 := Node3D.new()
	node_39.name = "Donor"
	node_39.transform = operands[819]
	node_38.add_child(node_39)
	var node_40 := GPUParticles3D.new()
	node_40.name = "firepops"
	node_40.visible = operands[820]
	node_40.layers = operands[821]
	node_40.material_override = material_21
	node_40.cast_shadow = operands[822]
	node_40.amount = operands[823]
	node_40.lifetime = operands[824]
	node_40.use_fixed_seed = operands[825]
	node_40.seed = operands[826]
	node_40.fixed_fps = operands[827]
	node_40.process_material = material_1
	node_40.draw_pass_1 = operands[828]
	node_39.add_child(node_40)
	var node_41 := GPUParticles3D.new()
	node_41.name = "firebursts"
	node_41.material_override = material_22
	node_41.cast_shadow = operands[829]
	node_41.amount = operands[830]
	node_41.lifetime = operands[831]
	node_41.preprocess = operands[832]
	node_41.use_fixed_seed = operands[833]
	node_41.seed = operands[834]
	node_41.fixed_fps = operands[835]
	node_41.draw_order = operands[836]
	node_41.process_material = material_3
	node_41.draw_pass_1 = operands[837]
	node_39.add_child(node_41)
	var node_42 := GPUParticles3D.new()
	node_42.name = "UnequalRisingFlames"
	node_42.transform = operands[838]
	node_42.material_override = material_23
	node_42.cast_shadow = operands[839]
	node_42.amount = operands[840]
	node_42.preprocess = operands[841]
	node_42.use_fixed_seed = operands[842]
	node_42.seed = operands[843]
	node_42.fixed_fps = operands[844]
	node_42.visibility_aabb = operands[845]
	node_42.draw_order = operands[846]
	node_42.process_material = material_5
	node_42.draw_pass_1 = operands[847]
	node_39.add_child(node_42)
	var node_43 := Node3D.new()
	node_43.name = "flame_7"
	node_43.transform = operands[848]
	node_0.add_child(node_43)
	var node_44 := Node3D.new()
	node_44.name = "effect"
	node_43.add_child(node_44)
	var node_45 := Node3D.new()
	node_45.name = "Donor"
	node_45.transform = operands[849]
	node_44.add_child(node_45)
	var node_46 := GPUParticles3D.new()
	node_46.name = "firepops"
	node_46.visible = operands[850]
	node_46.layers = operands[851]
	node_46.material_override = material_24
	node_46.cast_shadow = operands[852]
	node_46.amount = operands[853]
	node_46.lifetime = operands[854]
	node_46.use_fixed_seed = operands[855]
	node_46.seed = operands[856]
	node_46.fixed_fps = operands[857]
	node_46.process_material = material_1
	node_46.draw_pass_1 = operands[858]
	node_45.add_child(node_46)
	var node_47 := GPUParticles3D.new()
	node_47.name = "firebursts"
	node_47.material_override = material_25
	node_47.cast_shadow = operands[859]
	node_47.amount = operands[860]
	node_47.lifetime = operands[861]
	node_47.preprocess = operands[862]
	node_47.use_fixed_seed = operands[863]
	node_47.seed = operands[864]
	node_47.fixed_fps = operands[865]
	node_47.draw_order = operands[866]
	node_47.process_material = material_3
	node_47.draw_pass_1 = operands[867]
	node_45.add_child(node_47)
	var node_48 := GPUParticles3D.new()
	node_48.name = "UnequalRisingFlames"
	node_48.transform = operands[868]
	node_48.material_override = material_26
	node_48.cast_shadow = operands[869]
	node_48.preprocess = operands[870]
	node_48.use_fixed_seed = operands[871]
	node_48.seed = operands[872]
	node_48.fixed_fps = operands[873]
	node_48.visibility_aabb = operands[874]
	node_48.draw_order = operands[875]
	node_48.process_material = material_5
	node_48.draw_pass_1 = operands[876]
	node_45.add_child(node_48)
	var node_49 := Node3D.new()
	node_49.name = "flame_8"
	node_49.transform = operands[877]
	node_0.add_child(node_49)
	var node_50 := Node3D.new()
	node_50.name = "effect"
	node_49.add_child(node_50)
	var node_51 := Node3D.new()
	node_51.name = "Donor"
	node_51.transform = operands[878]
	node_50.add_child(node_51)
	var node_52 := GPUParticles3D.new()
	node_52.name = "firepops"
	node_52.visible = operands[879]
	node_52.layers = operands[880]
	node_52.material_override = material_27
	node_52.cast_shadow = operands[881]
	node_52.amount = operands[882]
	node_52.lifetime = operands[883]
	node_52.use_fixed_seed = operands[884]
	node_52.seed = operands[885]
	node_52.fixed_fps = operands[886]
	node_52.process_material = material_1
	node_52.draw_pass_1 = operands[887]
	node_51.add_child(node_52)
	var node_53 := GPUParticles3D.new()
	node_53.name = "firebursts"
	node_53.material_override = material_28
	node_53.cast_shadow = operands[888]
	node_53.amount = operands[889]
	node_53.lifetime = operands[890]
	node_53.preprocess = operands[891]
	node_53.use_fixed_seed = operands[892]
	node_53.seed = operands[893]
	node_53.fixed_fps = operands[894]
	node_53.draw_order = operands[895]
	node_53.process_material = material_3
	node_53.draw_pass_1 = operands[896]
	node_51.add_child(node_53)
	var node_54 := GPUParticles3D.new()
	node_54.name = "UnequalRisingFlames"
	node_54.transform = operands[897]
	node_54.material_override = material_29
	node_54.cast_shadow = operands[898]
	node_54.amount = operands[899]
	node_54.preprocess = operands[900]
	node_54.use_fixed_seed = operands[901]
	node_54.seed = operands[902]
	node_54.fixed_fps = operands[903]
	node_54.visibility_aabb = operands[904]
	node_54.draw_order = operands[905]
	node_54.process_material = material_5
	node_54.draw_pass_1 = operands[906]
	node_51.add_child(node_54)
	var node_55 := Node3D.new()
	node_55.name = "flame_9"
	node_55.transform = operands[907]
	node_0.add_child(node_55)
	var node_56 := Node3D.new()
	node_56.name = "effect"
	node_55.add_child(node_56)
	var node_57 := Node3D.new()
	node_57.name = "Donor"
	node_57.transform = operands[908]
	node_56.add_child(node_57)
	var node_58 := GPUParticles3D.new()
	node_58.name = "firepops"
	node_58.visible = operands[909]
	node_58.layers = operands[910]
	node_58.material_override = material_30
	node_58.cast_shadow = operands[911]
	node_58.amount = operands[912]
	node_58.lifetime = operands[913]
	node_58.use_fixed_seed = operands[914]
	node_58.seed = operands[915]
	node_58.fixed_fps = operands[916]
	node_58.process_material = material_1
	node_58.draw_pass_1 = operands[917]
	node_57.add_child(node_58)
	var node_59 := GPUParticles3D.new()
	node_59.name = "firebursts"
	node_59.material_override = material_31
	node_59.cast_shadow = operands[918]
	node_59.amount = operands[919]
	node_59.lifetime = operands[920]
	node_59.preprocess = operands[921]
	node_59.use_fixed_seed = operands[922]
	node_59.seed = operands[923]
	node_59.fixed_fps = operands[924]
	node_59.draw_order = operands[925]
	node_59.process_material = material_3
	node_59.draw_pass_1 = operands[926]
	node_57.add_child(node_59)
	var node_60 := GPUParticles3D.new()
	node_60.name = "UnequalRisingFlames"
	node_60.transform = operands[927]
	node_60.material_override = material_32
	node_60.cast_shadow = operands[928]
	node_60.preprocess = operands[929]
	node_60.use_fixed_seed = operands[930]
	node_60.seed = operands[931]
	node_60.fixed_fps = operands[932]
	node_60.visibility_aabb = operands[933]
	node_60.draw_order = operands[934]
	node_60.process_material = material_5
	node_60.draw_pass_1 = operands[935]
	node_57.add_child(node_60)
	var node_61 := Node3D.new()
	node_61.name = "flame_10"
	node_61.transform = operands[936]
	node_0.add_child(node_61)
	var node_62 := Node3D.new()
	node_62.name = "effect"
	node_61.add_child(node_62)
	var node_63 := Node3D.new()
	node_63.name = "Donor"
	node_63.transform = operands[937]
	node_62.add_child(node_63)
	var node_64 := GPUParticles3D.new()
	node_64.name = "firepops"
	node_64.visible = operands[938]
	node_64.layers = operands[939]
	node_64.material_override = material_33
	node_64.cast_shadow = operands[940]
	node_64.amount = operands[941]
	node_64.lifetime = operands[942]
	node_64.use_fixed_seed = operands[943]
	node_64.seed = operands[944]
	node_64.fixed_fps = operands[945]
	node_64.process_material = material_1
	node_64.draw_pass_1 = operands[946]
	node_63.add_child(node_64)
	var node_65 := GPUParticles3D.new()
	node_65.name = "firebursts"
	node_65.material_override = material_34
	node_65.cast_shadow = operands[947]
	node_65.amount = operands[948]
	node_65.lifetime = operands[949]
	node_65.preprocess = operands[950]
	node_65.use_fixed_seed = operands[951]
	node_65.seed = operands[952]
	node_65.fixed_fps = operands[953]
	node_65.draw_order = operands[954]
	node_65.process_material = material_3
	node_65.draw_pass_1 = operands[955]
	node_63.add_child(node_65)
	var node_66 := GPUParticles3D.new()
	node_66.name = "UnequalRisingFlames"
	node_66.transform = operands[956]
	node_66.material_override = material_35
	node_66.cast_shadow = operands[957]
	node_66.amount = operands[958]
	node_66.preprocess = operands[959]
	node_66.use_fixed_seed = operands[960]
	node_66.seed = operands[961]
	node_66.fixed_fps = operands[962]
	node_66.visibility_aabb = operands[963]
	node_66.draw_order = operands[964]
	node_66.process_material = material_5
	node_66.draw_pass_1 = operands[965]
	node_63.add_child(node_66)
	var node_67 := Node3D.new()
	node_67.name = "flame_11"
	node_67.transform = operands[966]
	node_0.add_child(node_67)
	var node_68 := Node3D.new()
	node_68.name = "effect"
	node_67.add_child(node_68)
	var node_69 := Node3D.new()
	node_69.name = "Donor"
	node_69.transform = operands[967]
	node_68.add_child(node_69)
	var node_70 := GPUParticles3D.new()
	node_70.name = "firepops"
	node_70.visible = operands[968]
	node_70.layers = operands[969]
	node_70.material_override = material_36
	node_70.cast_shadow = operands[970]
	node_70.amount = operands[971]
	node_70.lifetime = operands[972]
	node_70.use_fixed_seed = operands[973]
	node_70.seed = operands[974]
	node_70.fixed_fps = operands[975]
	node_70.process_material = material_1
	node_70.draw_pass_1 = operands[976]
	node_69.add_child(node_70)
	var node_71 := GPUParticles3D.new()
	node_71.name = "firebursts"
	node_71.material_override = material_37
	node_71.cast_shadow = operands[977]
	node_71.amount = operands[978]
	node_71.lifetime = operands[979]
	node_71.preprocess = operands[980]
	node_71.use_fixed_seed = operands[981]
	node_71.seed = operands[982]
	node_71.fixed_fps = operands[983]
	node_71.draw_order = operands[984]
	node_71.process_material = material_3
	node_71.draw_pass_1 = operands[985]
	node_69.add_child(node_71)
	var node_72 := GPUParticles3D.new()
	node_72.name = "UnequalRisingFlames"
	node_72.transform = operands[986]
	node_72.material_override = material_38
	node_72.cast_shadow = operands[987]
	node_72.preprocess = operands[988]
	node_72.use_fixed_seed = operands[989]
	node_72.seed = operands[990]
	node_72.fixed_fps = operands[991]
	node_72.visibility_aabb = operands[992]
	node_72.draw_order = operands[993]
	node_72.process_material = material_5
	node_72.draw_pass_1 = operands[994]
	node_69.add_child(node_72)
	var node_73 := Node3D.new()
	node_73.name = "flame_12"
	node_73.transform = operands[995]
	node_0.add_child(node_73)
	var node_74 := Node3D.new()
	node_74.name = "effect"
	node_73.add_child(node_74)
	var node_75 := Node3D.new()
	node_75.name = "Donor"
	node_75.transform = operands[996]
	node_74.add_child(node_75)
	var node_76 := GPUParticles3D.new()
	node_76.name = "firepops"
	node_76.visible = operands[997]
	node_76.layers = operands[998]
	node_76.material_override = material_39
	node_76.cast_shadow = operands[999]
	node_76.amount = operands[1000]
	node_76.lifetime = operands[1001]
	node_76.use_fixed_seed = operands[1002]
	node_76.seed = operands[1003]
	node_76.fixed_fps = operands[1004]
	node_76.process_material = material_1
	node_76.draw_pass_1 = operands[1005]
	node_75.add_child(node_76)
	var node_77 := GPUParticles3D.new()
	node_77.name = "firebursts"
	node_77.material_override = material_40
	node_77.cast_shadow = operands[1006]
	node_77.amount = operands[1007]
	node_77.lifetime = operands[1008]
	node_77.preprocess = operands[1009]
	node_77.use_fixed_seed = operands[1010]
	node_77.seed = operands[1011]
	node_77.fixed_fps = operands[1012]
	node_77.draw_order = operands[1013]
	node_77.process_material = material_3
	node_77.draw_pass_1 = operands[1014]
	node_75.add_child(node_77)
	var node_78 := GPUParticles3D.new()
	node_78.name = "UnequalRisingFlames"
	node_78.transform = operands[1015]
	node_78.material_override = material_41
	node_78.cast_shadow = operands[1016]
	node_78.amount = operands[1017]
	node_78.preprocess = operands[1018]
	node_78.use_fixed_seed = operands[1019]
	node_78.seed = operands[1020]
	node_78.fixed_fps = operands[1021]
	node_78.visibility_aabb = operands[1022]
	node_78.draw_order = operands[1023]
	node_78.process_material = material_5
	node_78.draw_pass_1 = operands[1024]
	node_75.add_child(node_78)
	var node_79 := Node3D.new()
	node_79.name = "flame_13"
	node_79.transform = operands[1025]
	node_0.add_child(node_79)
	var node_80 := Node3D.new()
	node_80.name = "effect"
	node_79.add_child(node_80)
	var node_81 := Node3D.new()
	node_81.name = "Donor"
	node_81.transform = operands[1026]
	node_80.add_child(node_81)
	var node_82 := GPUParticles3D.new()
	node_82.name = "firepops"
	node_82.visible = operands[1027]
	node_82.layers = operands[1028]
	node_82.material_override = material_42
	node_82.cast_shadow = operands[1029]
	node_82.amount = operands[1030]
	node_82.lifetime = operands[1031]
	node_82.use_fixed_seed = operands[1032]
	node_82.seed = operands[1033]
	node_82.fixed_fps = operands[1034]
	node_82.process_material = material_1
	node_82.draw_pass_1 = operands[1035]
	node_81.add_child(node_82)
	var node_83 := GPUParticles3D.new()
	node_83.name = "firebursts"
	node_83.material_override = material_43
	node_83.cast_shadow = operands[1036]
	node_83.amount = operands[1037]
	node_83.lifetime = operands[1038]
	node_83.preprocess = operands[1039]
	node_83.use_fixed_seed = operands[1040]
	node_83.seed = operands[1041]
	node_83.fixed_fps = operands[1042]
	node_83.draw_order = operands[1043]
	node_83.process_material = material_3
	node_83.draw_pass_1 = operands[1044]
	node_81.add_child(node_83)
	var node_84 := GPUParticles3D.new()
	node_84.name = "UnequalRisingFlames"
	node_84.transform = operands[1045]
	node_84.material_override = material_44
	node_84.cast_shadow = operands[1046]
	node_84.preprocess = operands[1047]
	node_84.use_fixed_seed = operands[1048]
	node_84.seed = operands[1049]
	node_84.fixed_fps = operands[1050]
	node_84.visibility_aabb = operands[1051]
	node_84.draw_order = operands[1052]
	node_84.process_material = material_5
	node_84.draw_pass_1 = operands[1053]
	node_81.add_child(node_84)
	var node_85 := Node3D.new()
	node_85.name = "flame_14"
	node_85.transform = operands[1054]
	node_0.add_child(node_85)
	var node_86 := Node3D.new()
	node_86.name = "effect"
	node_85.add_child(node_86)
	var node_87 := Node3D.new()
	node_87.name = "Donor"
	node_87.transform = operands[1055]
	node_86.add_child(node_87)
	var node_88 := GPUParticles3D.new()
	node_88.name = "firepops"
	node_88.visible = operands[1056]
	node_88.layers = operands[1057]
	node_88.material_override = material_45
	node_88.cast_shadow = operands[1058]
	node_88.amount = operands[1059]
	node_88.lifetime = operands[1060]
	node_88.use_fixed_seed = operands[1061]
	node_88.seed = operands[1062]
	node_88.fixed_fps = operands[1063]
	node_88.process_material = material_1
	node_88.draw_pass_1 = operands[1064]
	node_87.add_child(node_88)
	var node_89 := GPUParticles3D.new()
	node_89.name = "firebursts"
	node_89.material_override = material_46
	node_89.cast_shadow = operands[1065]
	node_89.amount = operands[1066]
	node_89.lifetime = operands[1067]
	node_89.preprocess = operands[1068]
	node_89.use_fixed_seed = operands[1069]
	node_89.seed = operands[1070]
	node_89.fixed_fps = operands[1071]
	node_89.draw_order = operands[1072]
	node_89.process_material = material_3
	node_89.draw_pass_1 = operands[1073]
	node_87.add_child(node_89)
	var node_90 := GPUParticles3D.new()
	node_90.name = "UnequalRisingFlames"
	node_90.transform = operands[1074]
	node_90.material_override = material_47
	node_90.cast_shadow = operands[1075]
	node_90.amount = operands[1076]
	node_90.preprocess = operands[1077]
	node_90.use_fixed_seed = operands[1078]
	node_90.seed = operands[1079]
	node_90.fixed_fps = operands[1080]
	node_90.visibility_aabb = operands[1081]
	node_90.draw_order = operands[1082]
	node_90.process_material = material_5
	node_90.draw_pass_1 = operands[1083]
	node_87.add_child(node_90)
	var node_91 := Node3D.new()
	node_91.name = "flame_15"
	node_91.transform = operands[1084]
	node_0.add_child(node_91)
	var node_92 := Node3D.new()
	node_92.name = "effect"
	node_91.add_child(node_92)
	var node_93 := Node3D.new()
	node_93.name = "Donor"
	node_93.transform = operands[1085]
	node_92.add_child(node_93)
	var node_94 := GPUParticles3D.new()
	node_94.name = "firepops"
	node_94.visible = operands[1086]
	node_94.layers = operands[1087]
	node_94.material_override = material_48
	node_94.cast_shadow = operands[1088]
	node_94.amount = operands[1089]
	node_94.lifetime = operands[1090]
	node_94.use_fixed_seed = operands[1091]
	node_94.seed = operands[1092]
	node_94.fixed_fps = operands[1093]
	node_94.process_material = material_1
	node_94.draw_pass_1 = operands[1094]
	node_93.add_child(node_94)
	var node_95 := GPUParticles3D.new()
	node_95.name = "firebursts"
	node_95.material_override = material_49
	node_95.cast_shadow = operands[1095]
	node_95.amount = operands[1096]
	node_95.lifetime = operands[1097]
	node_95.preprocess = operands[1098]
	node_95.use_fixed_seed = operands[1099]
	node_95.seed = operands[1100]
	node_95.fixed_fps = operands[1101]
	node_95.draw_order = operands[1102]
	node_95.process_material = material_3
	node_95.draw_pass_1 = operands[1103]
	node_93.add_child(node_95)
	var node_96 := GPUParticles3D.new()
	node_96.name = "UnequalRisingFlames"
	node_96.transform = operands[1104]
	node_96.material_override = material_50
	node_96.cast_shadow = operands[1105]
	node_96.preprocess = operands[1106]
	node_96.use_fixed_seed = operands[1107]
	node_96.seed = operands[1108]
	node_96.fixed_fps = operands[1109]
	node_96.visibility_aabb = operands[1110]
	node_96.draw_order = operands[1111]
	node_96.process_material = material_5
	node_96.draw_pass_1 = operands[1112]
	node_93.add_child(node_96)
	var node_97 := Node3D.new()
	node_97.name = "flame_16"
	node_97.transform = operands[1113]
	node_0.add_child(node_97)
	var node_98 := Node3D.new()
	node_98.name = "effect"
	node_97.add_child(node_98)
	var node_99 := Node3D.new()
	node_99.name = "Donor"
	node_99.transform = operands[1114]
	node_98.add_child(node_99)
	var node_100 := GPUParticles3D.new()
	node_100.name = "firepops"
	node_100.visible = operands[1115]
	node_100.layers = operands[1116]
	node_100.material_override = material_51
	node_100.cast_shadow = operands[1117]
	node_100.amount = operands[1118]
	node_100.lifetime = operands[1119]
	node_100.use_fixed_seed = operands[1120]
	node_100.seed = operands[1121]
	node_100.fixed_fps = operands[1122]
	node_100.process_material = material_1
	node_100.draw_pass_1 = operands[1123]
	node_99.add_child(node_100)
	var node_101 := GPUParticles3D.new()
	node_101.name = "firebursts"
	node_101.material_override = material_52
	node_101.cast_shadow = operands[1124]
	node_101.amount = operands[1125]
	node_101.lifetime = operands[1126]
	node_101.preprocess = operands[1127]
	node_101.use_fixed_seed = operands[1128]
	node_101.seed = operands[1129]
	node_101.fixed_fps = operands[1130]
	node_101.draw_order = operands[1131]
	node_101.process_material = material_3
	node_101.draw_pass_1 = operands[1132]
	node_99.add_child(node_101)
	var node_102 := GPUParticles3D.new()
	node_102.name = "UnequalRisingFlames"
	node_102.transform = operands[1133]
	node_102.material_override = material_53
	node_102.cast_shadow = operands[1134]
	node_102.amount = operands[1135]
	node_102.preprocess = operands[1136]
	node_102.use_fixed_seed = operands[1137]
	node_102.seed = operands[1138]
	node_102.fixed_fps = operands[1139]
	node_102.visibility_aabb = operands[1140]
	node_102.draw_order = operands[1141]
	node_102.process_material = material_5
	node_102.draw_pass_1 = operands[1142]
	node_99.add_child(node_102)
	var node_103 := Node3D.new()
	node_103.name = "flame_17"
	node_103.transform = operands[1143]
	node_0.add_child(node_103)
	var node_104 := Node3D.new()
	node_104.name = "effect"
	node_103.add_child(node_104)
	var node_105 := Node3D.new()
	node_105.name = "Donor"
	node_105.transform = operands[1144]
	node_104.add_child(node_105)
	var node_106 := GPUParticles3D.new()
	node_106.name = "firepops"
	node_106.visible = operands[1145]
	node_106.layers = operands[1146]
	node_106.material_override = material_54
	node_106.cast_shadow = operands[1147]
	node_106.amount = operands[1148]
	node_106.lifetime = operands[1149]
	node_106.use_fixed_seed = operands[1150]
	node_106.seed = operands[1151]
	node_106.fixed_fps = operands[1152]
	node_106.process_material = material_1
	node_106.draw_pass_1 = operands[1153]
	node_105.add_child(node_106)
	var node_107 := GPUParticles3D.new()
	node_107.name = "firebursts"
	node_107.material_override = material_55
	node_107.cast_shadow = operands[1154]
	node_107.amount = operands[1155]
	node_107.lifetime = operands[1156]
	node_107.preprocess = operands[1157]
	node_107.use_fixed_seed = operands[1158]
	node_107.seed = operands[1159]
	node_107.fixed_fps = operands[1160]
	node_107.draw_order = operands[1161]
	node_107.process_material = material_3
	node_107.draw_pass_1 = operands[1162]
	node_105.add_child(node_107)
	var node_108 := GPUParticles3D.new()
	node_108.name = "UnequalRisingFlames"
	node_108.transform = operands[1163]
	node_108.material_override = material_56
	node_108.cast_shadow = operands[1164]
	node_108.preprocess = operands[1165]
	node_108.use_fixed_seed = operands[1166]
	node_108.seed = operands[1167]
	node_108.fixed_fps = operands[1168]
	node_108.visibility_aabb = operands[1169]
	node_108.draw_order = operands[1170]
	node_108.process_material = material_5
	node_108.draw_pass_1 = operands[1171]
	node_105.add_child(node_108)
	var node_109 := Node3D.new()
	node_109.name = "flame_18"
	node_109.transform = operands[1172]
	node_0.add_child(node_109)
	var node_110 := Node3D.new()
	node_110.name = "effect"
	node_109.add_child(node_110)
	var node_111 := Node3D.new()
	node_111.name = "Donor"
	node_111.transform = operands[1173]
	node_110.add_child(node_111)
	var node_112 := GPUParticles3D.new()
	node_112.name = "firepops"
	node_112.visible = operands[1174]
	node_112.layers = operands[1175]
	node_112.material_override = material_57
	node_112.cast_shadow = operands[1176]
	node_112.amount = operands[1177]
	node_112.lifetime = operands[1178]
	node_112.use_fixed_seed = operands[1179]
	node_112.seed = operands[1180]
	node_112.fixed_fps = operands[1181]
	node_112.process_material = material_1
	node_112.draw_pass_1 = operands[1182]
	node_111.add_child(node_112)
	var node_113 := GPUParticles3D.new()
	node_113.name = "firebursts"
	node_113.material_override = material_58
	node_113.cast_shadow = operands[1183]
	node_113.amount = operands[1184]
	node_113.lifetime = operands[1185]
	node_113.preprocess = operands[1186]
	node_113.use_fixed_seed = operands[1187]
	node_113.seed = operands[1188]
	node_113.fixed_fps = operands[1189]
	node_113.draw_order = operands[1190]
	node_113.process_material = material_3
	node_113.draw_pass_1 = operands[1191]
	node_111.add_child(node_113)
	var node_114 := GPUParticles3D.new()
	node_114.name = "UnequalRisingFlames"
	node_114.transform = operands[1192]
	node_114.material_override = material_59
	node_114.cast_shadow = operands[1193]
	node_114.amount = operands[1194]
	node_114.preprocess = operands[1195]
	node_114.use_fixed_seed = operands[1196]
	node_114.seed = operands[1197]
	node_114.fixed_fps = operands[1198]
	node_114.visibility_aabb = operands[1199]
	node_114.draw_order = operands[1200]
	node_114.process_material = material_5
	node_114.draw_pass_1 = operands[1201]
	node_111.add_child(node_114)
	var node_115 := Node3D.new()
	node_115.name = "flame_19"
	node_115.transform = operands[1202]
	node_0.add_child(node_115)
	var node_116 := Node3D.new()
	node_116.name = "effect"
	node_115.add_child(node_116)
	var node_117 := Node3D.new()
	node_117.name = "Donor"
	node_117.transform = operands[1203]
	node_116.add_child(node_117)
	var node_118 := GPUParticles3D.new()
	node_118.name = "firepops"
	node_118.visible = operands[1204]
	node_118.layers = operands[1205]
	node_118.material_override = material_60
	node_118.cast_shadow = operands[1206]
	node_118.amount = operands[1207]
	node_118.lifetime = operands[1208]
	node_118.use_fixed_seed = operands[1209]
	node_118.seed = operands[1210]
	node_118.fixed_fps = operands[1211]
	node_118.process_material = material_1
	node_118.draw_pass_1 = operands[1212]
	node_117.add_child(node_118)
	var node_119 := GPUParticles3D.new()
	node_119.name = "firebursts"
	node_119.material_override = material_61
	node_119.cast_shadow = operands[1213]
	node_119.amount = operands[1214]
	node_119.lifetime = operands[1215]
	node_119.preprocess = operands[1216]
	node_119.use_fixed_seed = operands[1217]
	node_119.seed = operands[1218]
	node_119.fixed_fps = operands[1219]
	node_119.draw_order = operands[1220]
	node_119.process_material = material_3
	node_119.draw_pass_1 = operands[1221]
	node_117.add_child(node_119)
	var node_120 := GPUParticles3D.new()
	node_120.name = "UnequalRisingFlames"
	node_120.transform = operands[1222]
	node_120.material_override = material_62
	node_120.cast_shadow = operands[1223]
	node_120.preprocess = operands[1224]
	node_120.use_fixed_seed = operands[1225]
	node_120.seed = operands[1226]
	node_120.fixed_fps = operands[1227]
	node_120.visibility_aabb = operands[1228]
	node_120.draw_order = operands[1229]
	node_120.process_material = material_5
	node_120.draw_pass_1 = operands[1230]
	node_117.add_child(node_120)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"all_materials": [material_0, material_1, material_2, material_3, material_4, material_5, material_6, material_7, material_8, material_9, material_10, material_11, material_12, material_13, material_14, material_15, material_16, material_17, material_18, material_19, material_20, material_21, material_22, material_23, material_24, material_25, material_26, material_27, material_28, material_29, material_30, material_31, material_32, material_33, material_34, material_35, material_36, material_37, material_38, material_39, material_40, material_41, material_42, material_43, material_44, material_45, material_46, material_47, material_48, material_49, material_50, material_51, material_52, material_53, material_54, material_55, material_56, material_57, material_58, material_59, material_60, material_61, material_62], "lights": [], "module_roots": [node_1, node_7, node_13, node_19, node_25, node_31, node_37, node_43, node_49, node_55, node_61, node_67, node_73, node_79, node_85, node_91, node_97, node_103, node_109, node_115], "emitters": [node_4, node_5, node_6, node_10, node_11, node_12, node_16, node_17, node_18, node_22, node_23, node_24, node_28, node_29, node_30, node_34, node_35, node_36, node_40, node_41, node_42, node_46, node_47, node_48, node_52, node_53, node_54, node_58, node_59, node_60, node_64, node_65, node_66, node_70, node_71, node_72, node_76, node_77, node_78, node_82, node_83, node_84, node_88, node_89, node_90, node_94, node_95, node_96, node_100, node_101, node_102, node_106, node_107, node_108, node_112, node_113, node_114, node_118, node_119, node_120], "age_materials": [material_0, material_2, material_4, material_6, material_7, material_8, material_9, material_10, material_11, material_12, material_13, material_14, material_15, material_16, material_17, material_18, material_19, material_20, material_21, material_22, material_23, material_24, material_25, material_26, material_27, material_28, material_29, material_30, material_31, material_32, material_33, material_34, material_35, material_36, material_37, material_38, material_39, material_40, material_41, material_42, material_43, material_44, material_45, material_46, material_47, material_48, material_49, material_50, material_51, material_52, material_53, material_54, material_55, material_56, material_57, material_58, material_59, material_60, material_61, material_62], "clock_materials": [material_2, material_7, material_10, material_13, material_16, material_19, material_22, material_25, material_28, material_31, material_34, material_37, material_40, material_43, material_46, material_49, material_52, material_55, material_58, material_61], "envelope_materials": [material_0, material_2, material_4, material_6, material_7, material_8, material_9, material_10, material_11, material_12, material_13, material_14, material_15, material_16, material_17, material_18, material_19, material_20, material_21, material_22, material_23, material_24, material_25, material_26, material_27, material_28, material_29, material_30, material_31, material_32, material_33, material_34, material_35, material_36, material_37, material_38, material_39, material_40, material_41, material_42, material_43, material_44, material_45, material_46, material_47, material_48, material_49, material_50, material_51, material_52, material_53, material_54, material_55, material_56, material_57, material_58, material_59, material_60, material_61, material_62], "world_process_materials": [{"material": material_1, "values": operands[1231]}, {"material": material_3, "values": operands[1232]}, {"material": material_5, "values": operands[1233]}], "root": node_0, "geometry": [node_4, node_5, node_6, node_10, node_11, node_12, node_16, node_17, node_18, node_22, node_23, node_24, node_28, node_29, node_30, node_34, node_35, node_36, node_40, node_41, node_42, node_46, node_47, node_48, node_52, node_53, node_54, node_58, node_59, node_60, node_64, node_65, node_66, node_70, node_71, node_72, node_76, node_77, node_78, node_82, node_83, node_84, node_88, node_89, node_90, node_94, node_95, node_96, node_100, node_101, node_102, node_106, node_107, node_108, node_112, node_113, node_114, node_118, node_119, node_120], "materials": [node_4.material_override, node_5.material_override, node_6.material_override, node_10.material_override, node_11.material_override, node_12.material_override, node_16.material_override, node_17.material_override, node_18.material_override, node_22.material_override, node_23.material_override, node_24.material_override, node_28.material_override, node_29.material_override, node_30.material_override, node_34.material_override, node_35.material_override, node_36.material_override, node_40.material_override, node_41.material_override, node_42.material_override, node_46.material_override, node_47.material_override, node_48.material_override, node_52.material_override, node_53.material_override, node_54.material_override, node_58.material_override, node_59.material_override, node_60.material_override, node_64.material_override, node_65.material_override, node_66.material_override, node_70.material_override, node_71.material_override, node_72.material_override, node_76.material_override, node_77.material_override, node_78.material_override, node_82.material_override, node_83.material_override, node_84.material_override, node_88.material_override, node_89.material_override, node_90.material_override, node_94.material_override, node_95.material_override, node_96.material_override, node_100.material_override, node_101.material_override, node_102.material_override, node_106.material_override, node_107.material_override, node_108.material_override, node_112.material_override, node_113.material_override, node_114.material_override, node_118.material_override, node_119.material_override, node_120.material_override], "cohorts": []}
