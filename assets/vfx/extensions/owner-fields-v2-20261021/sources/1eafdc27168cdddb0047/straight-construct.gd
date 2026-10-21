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
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "FactoryGenerated_0000_Node3D"
	var node_1 := Node3D.new()
	node_1.name = "flame_0"
	node_1.transform = operands[417]
	node_0.add_child(node_1)
	var node_2 := Node3D.new()
	node_2.name = "effect"
	node_1.add_child(node_2)
	var node_3 := Node3D.new()
	node_3.name = "Donor"
	node_3.transform = operands[418]
	node_2.add_child(node_3)
	var node_4 := GPUParticles3D.new()
	node_4.name = "firepops"
	node_4.visible = operands[419]
	node_4.layers = operands[420]
	node_4.material_override = material_0
	node_4.cast_shadow = operands[421]
	node_4.amount = operands[422]
	node_4.lifetime = operands[423]
	node_4.use_fixed_seed = operands[424]
	node_4.seed = operands[425]
	node_4.fixed_fps = operands[426]
	node_4.process_material = material_1
	node_4.draw_pass_1 = operands[427]
	node_3.add_child(node_4)
	var node_5 := GPUParticles3D.new()
	node_5.name = "firebursts"
	node_5.material_override = material_2
	node_5.cast_shadow = operands[428]
	node_5.amount = operands[429]
	node_5.lifetime = operands[430]
	node_5.preprocess = operands[431]
	node_5.use_fixed_seed = operands[432]
	node_5.seed = operands[433]
	node_5.fixed_fps = operands[434]
	node_5.draw_order = operands[435]
	node_5.process_material = material_3
	node_5.draw_pass_1 = operands[436]
	node_3.add_child(node_5)
	var node_6 := GPUParticles3D.new()
	node_6.name = "UnequalRisingFlames"
	node_6.transform = operands[437]
	node_6.material_override = material_4
	node_6.cast_shadow = operands[438]
	node_6.amount = operands[439]
	node_6.preprocess = operands[440]
	node_6.use_fixed_seed = operands[441]
	node_6.seed = operands[442]
	node_6.fixed_fps = operands[443]
	node_6.visibility_aabb = operands[444]
	node_6.draw_order = operands[445]
	node_6.process_material = material_5
	node_6.draw_pass_1 = operands[446]
	node_3.add_child(node_6)
	var node_7 := Node3D.new()
	node_7.name = "flame_1"
	node_7.transform = operands[447]
	node_0.add_child(node_7)
	var node_8 := Node3D.new()
	node_8.name = "effect"
	node_7.add_child(node_8)
	var node_9 := Node3D.new()
	node_9.name = "Donor"
	node_9.transform = operands[448]
	node_8.add_child(node_9)
	var node_10 := GPUParticles3D.new()
	node_10.name = "firepops"
	node_10.visible = operands[449]
	node_10.layers = operands[450]
	node_10.material_override = material_6
	node_10.cast_shadow = operands[451]
	node_10.amount = operands[452]
	node_10.lifetime = operands[453]
	node_10.use_fixed_seed = operands[454]
	node_10.seed = operands[455]
	node_10.fixed_fps = operands[456]
	node_10.process_material = material_1
	node_10.draw_pass_1 = operands[457]
	node_9.add_child(node_10)
	var node_11 := GPUParticles3D.new()
	node_11.name = "firebursts"
	node_11.material_override = material_7
	node_11.cast_shadow = operands[458]
	node_11.amount = operands[459]
	node_11.lifetime = operands[460]
	node_11.preprocess = operands[461]
	node_11.use_fixed_seed = operands[462]
	node_11.seed = operands[463]
	node_11.fixed_fps = operands[464]
	node_11.draw_order = operands[465]
	node_11.process_material = material_3
	node_11.draw_pass_1 = operands[466]
	node_9.add_child(node_11)
	var node_12 := GPUParticles3D.new()
	node_12.name = "UnequalRisingFlames"
	node_12.transform = operands[467]
	node_12.material_override = material_8
	node_12.cast_shadow = operands[468]
	node_12.preprocess = operands[469]
	node_12.use_fixed_seed = operands[470]
	node_12.seed = operands[471]
	node_12.fixed_fps = operands[472]
	node_12.visibility_aabb = operands[473]
	node_12.draw_order = operands[474]
	node_12.process_material = material_5
	node_12.draw_pass_1 = operands[475]
	node_9.add_child(node_12)
	var node_13 := Node3D.new()
	node_13.name = "flame_2"
	node_13.transform = operands[476]
	node_0.add_child(node_13)
	var node_14 := Node3D.new()
	node_14.name = "effect"
	node_13.add_child(node_14)
	var node_15 := Node3D.new()
	node_15.name = "Donor"
	node_15.transform = operands[477]
	node_14.add_child(node_15)
	var node_16 := GPUParticles3D.new()
	node_16.name = "firepops"
	node_16.visible = operands[478]
	node_16.layers = operands[479]
	node_16.material_override = material_9
	node_16.cast_shadow = operands[480]
	node_16.amount = operands[481]
	node_16.lifetime = operands[482]
	node_16.use_fixed_seed = operands[483]
	node_16.seed = operands[484]
	node_16.fixed_fps = operands[485]
	node_16.process_material = material_1
	node_16.draw_pass_1 = operands[486]
	node_15.add_child(node_16)
	var node_17 := GPUParticles3D.new()
	node_17.name = "firebursts"
	node_17.material_override = material_10
	node_17.cast_shadow = operands[487]
	node_17.amount = operands[488]
	node_17.lifetime = operands[489]
	node_17.preprocess = operands[490]
	node_17.use_fixed_seed = operands[491]
	node_17.seed = operands[492]
	node_17.fixed_fps = operands[493]
	node_17.draw_order = operands[494]
	node_17.process_material = material_3
	node_17.draw_pass_1 = operands[495]
	node_15.add_child(node_17)
	var node_18 := GPUParticles3D.new()
	node_18.name = "UnequalRisingFlames"
	node_18.transform = operands[496]
	node_18.material_override = material_11
	node_18.cast_shadow = operands[497]
	node_18.amount = operands[498]
	node_18.preprocess = operands[499]
	node_18.use_fixed_seed = operands[500]
	node_18.seed = operands[501]
	node_18.fixed_fps = operands[502]
	node_18.visibility_aabb = operands[503]
	node_18.draw_order = operands[504]
	node_18.process_material = material_5
	node_18.draw_pass_1 = operands[505]
	node_15.add_child(node_18)
	var node_19 := Node3D.new()
	node_19.name = "flame_3"
	node_19.transform = operands[506]
	node_0.add_child(node_19)
	var node_20 := Node3D.new()
	node_20.name = "effect"
	node_19.add_child(node_20)
	var node_21 := Node3D.new()
	node_21.name = "Donor"
	node_21.transform = operands[507]
	node_20.add_child(node_21)
	var node_22 := GPUParticles3D.new()
	node_22.name = "firepops"
	node_22.visible = operands[508]
	node_22.layers = operands[509]
	node_22.material_override = material_12
	node_22.cast_shadow = operands[510]
	node_22.amount = operands[511]
	node_22.lifetime = operands[512]
	node_22.use_fixed_seed = operands[513]
	node_22.seed = operands[514]
	node_22.fixed_fps = operands[515]
	node_22.process_material = material_1
	node_22.draw_pass_1 = operands[516]
	node_21.add_child(node_22)
	var node_23 := GPUParticles3D.new()
	node_23.name = "firebursts"
	node_23.material_override = material_13
	node_23.cast_shadow = operands[517]
	node_23.amount = operands[518]
	node_23.lifetime = operands[519]
	node_23.preprocess = operands[520]
	node_23.use_fixed_seed = operands[521]
	node_23.seed = operands[522]
	node_23.fixed_fps = operands[523]
	node_23.draw_order = operands[524]
	node_23.process_material = material_3
	node_23.draw_pass_1 = operands[525]
	node_21.add_child(node_23)
	var node_24 := GPUParticles3D.new()
	node_24.name = "UnequalRisingFlames"
	node_24.transform = operands[526]
	node_24.material_override = material_14
	node_24.cast_shadow = operands[527]
	node_24.preprocess = operands[528]
	node_24.use_fixed_seed = operands[529]
	node_24.seed = operands[530]
	node_24.fixed_fps = operands[531]
	node_24.visibility_aabb = operands[532]
	node_24.draw_order = operands[533]
	node_24.process_material = material_5
	node_24.draw_pass_1 = operands[534]
	node_21.add_child(node_24)
	var node_25 := Node3D.new()
	node_25.name = "flame_4"
	node_25.transform = operands[535]
	node_0.add_child(node_25)
	var node_26 := Node3D.new()
	node_26.name = "effect"
	node_25.add_child(node_26)
	var node_27 := Node3D.new()
	node_27.name = "Donor"
	node_27.transform = operands[536]
	node_26.add_child(node_27)
	var node_28 := GPUParticles3D.new()
	node_28.name = "firepops"
	node_28.visible = operands[537]
	node_28.layers = operands[538]
	node_28.material_override = material_15
	node_28.cast_shadow = operands[539]
	node_28.amount = operands[540]
	node_28.lifetime = operands[541]
	node_28.use_fixed_seed = operands[542]
	node_28.seed = operands[543]
	node_28.fixed_fps = operands[544]
	node_28.process_material = material_1
	node_28.draw_pass_1 = operands[545]
	node_27.add_child(node_28)
	var node_29 := GPUParticles3D.new()
	node_29.name = "firebursts"
	node_29.material_override = material_16
	node_29.cast_shadow = operands[546]
	node_29.amount = operands[547]
	node_29.lifetime = operands[548]
	node_29.preprocess = operands[549]
	node_29.use_fixed_seed = operands[550]
	node_29.seed = operands[551]
	node_29.fixed_fps = operands[552]
	node_29.draw_order = operands[553]
	node_29.process_material = material_3
	node_29.draw_pass_1 = operands[554]
	node_27.add_child(node_29)
	var node_30 := GPUParticles3D.new()
	node_30.name = "UnequalRisingFlames"
	node_30.transform = operands[555]
	node_30.material_override = material_17
	node_30.cast_shadow = operands[556]
	node_30.amount = operands[557]
	node_30.preprocess = operands[558]
	node_30.use_fixed_seed = operands[559]
	node_30.seed = operands[560]
	node_30.fixed_fps = operands[561]
	node_30.visibility_aabb = operands[562]
	node_30.draw_order = operands[563]
	node_30.process_material = material_5
	node_30.draw_pass_1 = operands[564]
	node_27.add_child(node_30)
	var node_31 := Node3D.new()
	node_31.name = "flame_5"
	node_31.transform = operands[565]
	node_0.add_child(node_31)
	var node_32 := Node3D.new()
	node_32.name = "effect"
	node_31.add_child(node_32)
	var node_33 := Node3D.new()
	node_33.name = "Donor"
	node_33.transform = operands[566]
	node_32.add_child(node_33)
	var node_34 := GPUParticles3D.new()
	node_34.name = "firepops"
	node_34.visible = operands[567]
	node_34.layers = operands[568]
	node_34.material_override = material_18
	node_34.cast_shadow = operands[569]
	node_34.amount = operands[570]
	node_34.lifetime = operands[571]
	node_34.use_fixed_seed = operands[572]
	node_34.seed = operands[573]
	node_34.fixed_fps = operands[574]
	node_34.process_material = material_1
	node_34.draw_pass_1 = operands[575]
	node_33.add_child(node_34)
	var node_35 := GPUParticles3D.new()
	node_35.name = "firebursts"
	node_35.material_override = material_19
	node_35.cast_shadow = operands[576]
	node_35.amount = operands[577]
	node_35.lifetime = operands[578]
	node_35.preprocess = operands[579]
	node_35.use_fixed_seed = operands[580]
	node_35.seed = operands[581]
	node_35.fixed_fps = operands[582]
	node_35.draw_order = operands[583]
	node_35.process_material = material_3
	node_35.draw_pass_1 = operands[584]
	node_33.add_child(node_35)
	var node_36 := GPUParticles3D.new()
	node_36.name = "UnequalRisingFlames"
	node_36.transform = operands[585]
	node_36.material_override = material_20
	node_36.cast_shadow = operands[586]
	node_36.preprocess = operands[587]
	node_36.use_fixed_seed = operands[588]
	node_36.seed = operands[589]
	node_36.fixed_fps = operands[590]
	node_36.visibility_aabb = operands[591]
	node_36.draw_order = operands[592]
	node_36.process_material = material_5
	node_36.draw_pass_1 = operands[593]
	node_33.add_child(node_36)
	var node_37 := Node3D.new()
	node_37.name = "flame_6"
	node_37.transform = operands[594]
	node_0.add_child(node_37)
	var node_38 := Node3D.new()
	node_38.name = "effect"
	node_37.add_child(node_38)
	var node_39 := Node3D.new()
	node_39.name = "Donor"
	node_39.transform = operands[595]
	node_38.add_child(node_39)
	var node_40 := GPUParticles3D.new()
	node_40.name = "firepops"
	node_40.visible = operands[596]
	node_40.layers = operands[597]
	node_40.material_override = material_21
	node_40.cast_shadow = operands[598]
	node_40.amount = operands[599]
	node_40.lifetime = operands[600]
	node_40.use_fixed_seed = operands[601]
	node_40.seed = operands[602]
	node_40.fixed_fps = operands[603]
	node_40.process_material = material_1
	node_40.draw_pass_1 = operands[604]
	node_39.add_child(node_40)
	var node_41 := GPUParticles3D.new()
	node_41.name = "firebursts"
	node_41.material_override = material_22
	node_41.cast_shadow = operands[605]
	node_41.amount = operands[606]
	node_41.lifetime = operands[607]
	node_41.preprocess = operands[608]
	node_41.use_fixed_seed = operands[609]
	node_41.seed = operands[610]
	node_41.fixed_fps = operands[611]
	node_41.draw_order = operands[612]
	node_41.process_material = material_3
	node_41.draw_pass_1 = operands[613]
	node_39.add_child(node_41)
	var node_42 := GPUParticles3D.new()
	node_42.name = "UnequalRisingFlames"
	node_42.transform = operands[614]
	node_42.material_override = material_23
	node_42.cast_shadow = operands[615]
	node_42.amount = operands[616]
	node_42.preprocess = operands[617]
	node_42.use_fixed_seed = operands[618]
	node_42.seed = operands[619]
	node_42.fixed_fps = operands[620]
	node_42.visibility_aabb = operands[621]
	node_42.draw_order = operands[622]
	node_42.process_material = material_5
	node_42.draw_pass_1 = operands[623]
	node_39.add_child(node_42)
	var node_43 := Node3D.new()
	node_43.name = "flame_7"
	node_43.transform = operands[624]
	node_0.add_child(node_43)
	var node_44 := Node3D.new()
	node_44.name = "effect"
	node_43.add_child(node_44)
	var node_45 := Node3D.new()
	node_45.name = "Donor"
	node_45.transform = operands[625]
	node_44.add_child(node_45)
	var node_46 := GPUParticles3D.new()
	node_46.name = "firepops"
	node_46.visible = operands[626]
	node_46.layers = operands[627]
	node_46.material_override = material_24
	node_46.cast_shadow = operands[628]
	node_46.amount = operands[629]
	node_46.lifetime = operands[630]
	node_46.use_fixed_seed = operands[631]
	node_46.seed = operands[632]
	node_46.fixed_fps = operands[633]
	node_46.process_material = material_1
	node_46.draw_pass_1 = operands[634]
	node_45.add_child(node_46)
	var node_47 := GPUParticles3D.new()
	node_47.name = "firebursts"
	node_47.material_override = material_25
	node_47.cast_shadow = operands[635]
	node_47.amount = operands[636]
	node_47.lifetime = operands[637]
	node_47.preprocess = operands[638]
	node_47.use_fixed_seed = operands[639]
	node_47.seed = operands[640]
	node_47.fixed_fps = operands[641]
	node_47.draw_order = operands[642]
	node_47.process_material = material_3
	node_47.draw_pass_1 = operands[643]
	node_45.add_child(node_47)
	var node_48 := GPUParticles3D.new()
	node_48.name = "UnequalRisingFlames"
	node_48.transform = operands[644]
	node_48.material_override = material_26
	node_48.cast_shadow = operands[645]
	node_48.preprocess = operands[646]
	node_48.use_fixed_seed = operands[647]
	node_48.seed = operands[648]
	node_48.fixed_fps = operands[649]
	node_48.visibility_aabb = operands[650]
	node_48.draw_order = operands[651]
	node_48.process_material = material_5
	node_48.draw_pass_1 = operands[652]
	node_45.add_child(node_48)
	var node_49 := Node3D.new()
	node_49.name = "flame_8"
	node_49.transform = operands[653]
	node_0.add_child(node_49)
	var node_50 := Node3D.new()
	node_50.name = "effect"
	node_49.add_child(node_50)
	var node_51 := Node3D.new()
	node_51.name = "Donor"
	node_51.transform = operands[654]
	node_50.add_child(node_51)
	var node_52 := GPUParticles3D.new()
	node_52.name = "firepops"
	node_52.visible = operands[655]
	node_52.layers = operands[656]
	node_52.material_override = material_27
	node_52.cast_shadow = operands[657]
	node_52.amount = operands[658]
	node_52.lifetime = operands[659]
	node_52.use_fixed_seed = operands[660]
	node_52.seed = operands[661]
	node_52.fixed_fps = operands[662]
	node_52.process_material = material_1
	node_52.draw_pass_1 = operands[663]
	node_51.add_child(node_52)
	var node_53 := GPUParticles3D.new()
	node_53.name = "firebursts"
	node_53.material_override = material_28
	node_53.cast_shadow = operands[664]
	node_53.amount = operands[665]
	node_53.lifetime = operands[666]
	node_53.preprocess = operands[667]
	node_53.use_fixed_seed = operands[668]
	node_53.seed = operands[669]
	node_53.fixed_fps = operands[670]
	node_53.draw_order = operands[671]
	node_53.process_material = material_3
	node_53.draw_pass_1 = operands[672]
	node_51.add_child(node_53)
	var node_54 := GPUParticles3D.new()
	node_54.name = "UnequalRisingFlames"
	node_54.transform = operands[673]
	node_54.material_override = material_29
	node_54.cast_shadow = operands[674]
	node_54.amount = operands[675]
	node_54.preprocess = operands[676]
	node_54.use_fixed_seed = operands[677]
	node_54.seed = operands[678]
	node_54.fixed_fps = operands[679]
	node_54.visibility_aabb = operands[680]
	node_54.draw_order = operands[681]
	node_54.process_material = material_5
	node_54.draw_pass_1 = operands[682]
	node_51.add_child(node_54)
	var node_55 := Node3D.new()
	node_55.name = "flame_9"
	node_55.transform = operands[683]
	node_0.add_child(node_55)
	var node_56 := Node3D.new()
	node_56.name = "effect"
	node_55.add_child(node_56)
	var node_57 := Node3D.new()
	node_57.name = "Donor"
	node_57.transform = operands[684]
	node_56.add_child(node_57)
	var node_58 := GPUParticles3D.new()
	node_58.name = "firepops"
	node_58.visible = operands[685]
	node_58.layers = operands[686]
	node_58.material_override = material_30
	node_58.cast_shadow = operands[687]
	node_58.amount = operands[688]
	node_58.lifetime = operands[689]
	node_58.use_fixed_seed = operands[690]
	node_58.seed = operands[691]
	node_58.fixed_fps = operands[692]
	node_58.process_material = material_1
	node_58.draw_pass_1 = operands[693]
	node_57.add_child(node_58)
	var node_59 := GPUParticles3D.new()
	node_59.name = "firebursts"
	node_59.material_override = material_31
	node_59.cast_shadow = operands[694]
	node_59.amount = operands[695]
	node_59.lifetime = operands[696]
	node_59.preprocess = operands[697]
	node_59.use_fixed_seed = operands[698]
	node_59.seed = operands[699]
	node_59.fixed_fps = operands[700]
	node_59.draw_order = operands[701]
	node_59.process_material = material_3
	node_59.draw_pass_1 = operands[702]
	node_57.add_child(node_59)
	var node_60 := GPUParticles3D.new()
	node_60.name = "UnequalRisingFlames"
	node_60.transform = operands[703]
	node_60.material_override = material_32
	node_60.cast_shadow = operands[704]
	node_60.preprocess = operands[705]
	node_60.use_fixed_seed = operands[706]
	node_60.seed = operands[707]
	node_60.fixed_fps = operands[708]
	node_60.visibility_aabb = operands[709]
	node_60.draw_order = operands[710]
	node_60.process_material = material_5
	node_60.draw_pass_1 = operands[711]
	node_57.add_child(node_60)
	var node_61 := Node3D.new()
	node_61.name = "flame_10"
	node_61.transform = operands[712]
	node_0.add_child(node_61)
	var node_62 := Node3D.new()
	node_62.name = "effect"
	node_61.add_child(node_62)
	var node_63 := Node3D.new()
	node_63.name = "Donor"
	node_63.transform = operands[713]
	node_62.add_child(node_63)
	var node_64 := GPUParticles3D.new()
	node_64.name = "firepops"
	node_64.visible = operands[714]
	node_64.layers = operands[715]
	node_64.material_override = material_33
	node_64.cast_shadow = operands[716]
	node_64.amount = operands[717]
	node_64.lifetime = operands[718]
	node_64.use_fixed_seed = operands[719]
	node_64.seed = operands[720]
	node_64.fixed_fps = operands[721]
	node_64.process_material = material_1
	node_64.draw_pass_1 = operands[722]
	node_63.add_child(node_64)
	var node_65 := GPUParticles3D.new()
	node_65.name = "firebursts"
	node_65.material_override = material_34
	node_65.cast_shadow = operands[723]
	node_65.amount = operands[724]
	node_65.lifetime = operands[725]
	node_65.preprocess = operands[726]
	node_65.use_fixed_seed = operands[727]
	node_65.seed = operands[728]
	node_65.fixed_fps = operands[729]
	node_65.draw_order = operands[730]
	node_65.process_material = material_3
	node_65.draw_pass_1 = operands[731]
	node_63.add_child(node_65)
	var node_66 := GPUParticles3D.new()
	node_66.name = "UnequalRisingFlames"
	node_66.transform = operands[732]
	node_66.material_override = material_35
	node_66.cast_shadow = operands[733]
	node_66.amount = operands[734]
	node_66.preprocess = operands[735]
	node_66.use_fixed_seed = operands[736]
	node_66.seed = operands[737]
	node_66.fixed_fps = operands[738]
	node_66.visibility_aabb = operands[739]
	node_66.draw_order = operands[740]
	node_66.process_material = material_5
	node_66.draw_pass_1 = operands[741]
	node_63.add_child(node_66)
	var node_67 := Node3D.new()
	node_67.name = "flame_11"
	node_67.transform = operands[742]
	node_0.add_child(node_67)
	var node_68 := Node3D.new()
	node_68.name = "effect"
	node_67.add_child(node_68)
	var node_69 := Node3D.new()
	node_69.name = "Donor"
	node_69.transform = operands[743]
	node_68.add_child(node_69)
	var node_70 := GPUParticles3D.new()
	node_70.name = "firepops"
	node_70.visible = operands[744]
	node_70.layers = operands[745]
	node_70.material_override = material_36
	node_70.cast_shadow = operands[746]
	node_70.amount = operands[747]
	node_70.lifetime = operands[748]
	node_70.use_fixed_seed = operands[749]
	node_70.seed = operands[750]
	node_70.fixed_fps = operands[751]
	node_70.process_material = material_1
	node_70.draw_pass_1 = operands[752]
	node_69.add_child(node_70)
	var node_71 := GPUParticles3D.new()
	node_71.name = "firebursts"
	node_71.material_override = material_37
	node_71.cast_shadow = operands[753]
	node_71.amount = operands[754]
	node_71.lifetime = operands[755]
	node_71.preprocess = operands[756]
	node_71.use_fixed_seed = operands[757]
	node_71.seed = operands[758]
	node_71.fixed_fps = operands[759]
	node_71.draw_order = operands[760]
	node_71.process_material = material_3
	node_71.draw_pass_1 = operands[761]
	node_69.add_child(node_71)
	var node_72 := GPUParticles3D.new()
	node_72.name = "UnequalRisingFlames"
	node_72.transform = operands[762]
	node_72.material_override = material_38
	node_72.cast_shadow = operands[763]
	node_72.preprocess = operands[764]
	node_72.use_fixed_seed = operands[765]
	node_72.seed = operands[766]
	node_72.fixed_fps = operands[767]
	node_72.visibility_aabb = operands[768]
	node_72.draw_order = operands[769]
	node_72.process_material = material_5
	node_72.draw_pass_1 = operands[770]
	node_69.add_child(node_72)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"all_materials": [material_0, material_1, material_2, material_3, material_4, material_5, material_6, material_7, material_8, material_9, material_10, material_11, material_12, material_13, material_14, material_15, material_16, material_17, material_18, material_19, material_20, material_21, material_22, material_23, material_24, material_25, material_26, material_27, material_28, material_29, material_30, material_31, material_32, material_33, material_34, material_35, material_36, material_37, material_38], "lights": [], "module_roots": [node_1, node_7, node_13, node_19, node_25, node_31, node_37, node_43, node_49, node_55, node_61, node_67], "emitters": [node_4, node_5, node_6, node_10, node_11, node_12, node_16, node_17, node_18, node_22, node_23, node_24, node_28, node_29, node_30, node_34, node_35, node_36, node_40, node_41, node_42, node_46, node_47, node_48, node_52, node_53, node_54, node_58, node_59, node_60, node_64, node_65, node_66, node_70, node_71, node_72], "age_materials": [material_0, material_2, material_4, material_6, material_7, material_8, material_9, material_10, material_11, material_12, material_13, material_14, material_15, material_16, material_17, material_18, material_19, material_20, material_21, material_22, material_23, material_24, material_25, material_26, material_27, material_28, material_29, material_30, material_31, material_32, material_33, material_34, material_35, material_36, material_37, material_38], "clock_materials": [material_2, material_7, material_10, material_13, material_16, material_19, material_22, material_25, material_28, material_31, material_34, material_37], "envelope_materials": [material_0, material_2, material_4, material_6, material_7, material_8, material_9, material_10, material_11, material_12, material_13, material_14, material_15, material_16, material_17, material_18, material_19, material_20, material_21, material_22, material_23, material_24, material_25, material_26, material_27, material_28, material_29, material_30, material_31, material_32, material_33, material_34, material_35, material_36, material_37, material_38], "world_process_materials": [{"material": material_1, "values": operands[771]}, {"material": material_3, "values": operands[772]}, {"material": material_5, "values": operands[773]}], "root": node_0, "geometry": [node_4, node_5, node_6, node_10, node_11, node_12, node_16, node_17, node_18, node_22, node_23, node_24, node_28, node_29, node_30, node_34, node_35, node_36, node_40, node_41, node_42, node_46, node_47, node_48, node_52, node_53, node_54, node_58, node_59, node_60, node_64, node_65, node_66, node_70, node_71, node_72], "materials": [node_4.material_override, node_5.material_override, node_6.material_override, node_10.material_override, node_11.material_override, node_12.material_override, node_16.material_override, node_17.material_override, node_18.material_override, node_22.material_override, node_23.material_override, node_24.material_override, node_28.material_override, node_29.material_override, node_30.material_override, node_34.material_override, node_35.material_override, node_36.material_override, node_40.material_override, node_41.material_override, node_42.material_override, node_46.material_override, node_47.material_override, node_48.material_override, node_52.material_override, node_53.material_override, node_54.material_override, node_58.material_override, node_59.material_override, node_60.material_override, node_64.material_override, node_65.material_override, node_66.material_override, node_70.material_override, node_71.material_override, node_72.material_override], "cohorts": []}
