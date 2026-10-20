extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("mask1_texture", operands[1])
	material_0.set_shader_parameter("mask1_scroll", operands[2])
	material_0.set_shader_parameter("use_mask2", operands[3])
	material_0.set_shader_parameter("mask2_texture", operands[4])
	material_0.set_shader_parameter("mask2_scroll", operands[5])
	material_0.set_shader_parameter("mask2_strength", operands[6])
	material_0.set_shader_parameter("mask2_blend_mode", operands[7])
	material_0.set_shader_parameter("use_mask3", operands[8])
	material_0.set_shader_parameter("mask3_texture", operands[9])
	material_0.set_shader_parameter("mask3_strength", operands[10])
	material_0.set_shader_parameter("mask3_blend_mode", operands[11])
	material_0.set_shader_parameter("primary_color", operands[12])
	material_0.set_shader_parameter("secondary_color", operands[13])
	material_0.set_shader_parameter("tertiary_color", operands[14])
	material_0.set_shader_parameter("use_tertiary", operands[15])
	material_0.set_shader_parameter("color_smoothness", operands[16])
	material_0.set_shader_parameter("emission_strength", operands[17])
	material_0.set_shader_parameter("alpha_smoothness", operands[18])
	material_0.set_shader_parameter("alpha_multiplier", operands[19])
	material_0.set_shader_parameter("alpha_cutoff", operands[20])
	material_0.set_meta("factory_occurrence_alpha", operands[21])
	var material_1: ShaderMaterial = operands[22]
	var material_2 := ShaderMaterial.new()
	material_2.shader = operands[23]
	material_2.set_shader_parameter("mask1_texture", operands[24])
	material_2.set_shader_parameter("mask1_scroll", operands[25])
	material_2.set_shader_parameter("mask1_scale", operands[26])
	material_2.set_shader_parameter("use_mask2", operands[27])
	material_2.set_shader_parameter("mask2_texture", operands[28])
	material_2.set_shader_parameter("mask2_scroll", operands[29])
	material_2.set_shader_parameter("mask2_strength", operands[30])
	material_2.set_shader_parameter("mask2_blend_mode", operands[31])
	material_2.set_shader_parameter("use_mask3", operands[32])
	material_2.set_shader_parameter("mask3_texture", operands[33])
	material_2.set_shader_parameter("mask3_strength", operands[34])
	material_2.set_shader_parameter("mask3_blend_mode", operands[35])
	material_2.set_shader_parameter("primary_color", operands[36])
	material_2.set_shader_parameter("secondary_color", operands[37])
	material_2.set_shader_parameter("tertiary_color", operands[38])
	material_2.set_shader_parameter("color_smoothness", operands[39])
	material_2.set_shader_parameter("emission_strength", operands[40])
	material_2.set_shader_parameter("alpha_smoothness", operands[41])
	material_2.set_shader_parameter("alpha_multiplier", operands[42])
	material_2.set_shader_parameter("alpha_cutoff", operands[43])
	material_2.set_meta("factory_occurrence_alpha", operands[44])
	var material_3: ShaderMaterial = operands[45]
	var material_4 := ShaderMaterial.new()
	material_4.shader = operands[46]
	material_4.set_shader_parameter("fresnel_amount", operands[47])
	material_4.set_shader_parameter("fresnel_exponent", operands[48])
	material_4.set_shader_parameter("fresnel_gradient", operands[49])
	material_4.set_shader_parameter("enable_mask", operands[50])
	material_4.set_shader_parameter("mask_texture", operands[51])
	material_4.set_shader_parameter("mask_scroll", operands[52])
	material_4.set_shader_parameter("mask_blend_mode", operands[53])
	material_4.set_shader_parameter("mask_blend", operands[54])
	material_4.set_shader_parameter("primary_color", operands[55])
	material_4.set_shader_parameter("secondary_color", operands[56])
	material_4.set_shader_parameter("tertiary_color", operands[57])
	material_4.set_shader_parameter("alpha_multiplier", operands[58])
	material_4.set_shader_parameter("alpha_cutoff", operands[59])
	material_4.set_meta("factory_occurrence_alpha", operands[60])
	var material_5 := ShaderMaterial.new()
	material_5.shader = operands[61]
	material_5.set_shader_parameter("mask1_texture", operands[62])
	material_5.set_shader_parameter("mask1_scroll", operands[63])
	material_5.set_shader_parameter("mask1_scale", operands[64])
	material_5.set_shader_parameter("use_mask2", operands[65])
	material_5.set_shader_parameter("mask2_texture", operands[66])
	material_5.set_shader_parameter("mask2_scroll", operands[67])
	material_5.set_shader_parameter("mask2_strength", operands[68])
	material_5.set_shader_parameter("mask2_blend_mode", operands[69])
	material_5.set_shader_parameter("use_mask3", operands[70])
	material_5.set_shader_parameter("mask3_texture", operands[71])
	material_5.set_shader_parameter("mask3_strength", operands[72])
	material_5.set_shader_parameter("mask3_blend_mode", operands[73])
	material_5.set_shader_parameter("primary_color", operands[74])
	material_5.set_shader_parameter("secondary_color", operands[75])
	material_5.set_shader_parameter("tertiary_color", operands[76])
	material_5.set_shader_parameter("color_smoothness", operands[77])
	material_5.set_shader_parameter("emission_strength", operands[78])
	material_5.set_shader_parameter("alpha_smoothness", operands[79])
	material_5.set_shader_parameter("alpha_multiplier", operands[80])
	material_5.set_shader_parameter("alpha_cutoff", operands[81])
	material_5.set_meta("factory_occurrence_alpha", operands[82])
	var material_6: ShaderMaterial = operands[83]
	var material_7 := ShaderMaterial.new()
	material_7.shader = operands[84]
	material_7.set_shader_parameter("mask1_texture", operands[85])
	material_7.set_shader_parameter("mask1_scroll", operands[86])
	material_7.set_shader_parameter("mask1_scale", operands[87])
	material_7.set_shader_parameter("use_mask2", operands[88])
	material_7.set_shader_parameter("mask2_texture", operands[89])
	material_7.set_shader_parameter("mask2_scroll", operands[90])
	material_7.set_shader_parameter("mask2_strength", operands[91])
	material_7.set_shader_parameter("mask2_blend_mode", operands[92])
	material_7.set_shader_parameter("use_mask3", operands[93])
	material_7.set_shader_parameter("mask3_texture", operands[94])
	material_7.set_shader_parameter("mask3_strength", operands[95])
	material_7.set_shader_parameter("mask3_blend_mode", operands[96])
	material_7.set_shader_parameter("primary_color", operands[97])
	material_7.set_shader_parameter("secondary_color", operands[98])
	material_7.set_shader_parameter("tertiary_color", operands[99])
	material_7.set_shader_parameter("color_smoothness", operands[100])
	material_7.set_shader_parameter("emission_strength", operands[101])
	material_7.set_shader_parameter("alpha_smoothness", operands[102])
	material_7.set_shader_parameter("alpha_multiplier", operands[103])
	material_7.set_shader_parameter("alpha_cutoff", operands[104])
	material_7.set_meta("factory_occurrence_alpha", operands[105])
	var material_8: ShaderMaterial = operands[106]
	var material_9 := ShaderMaterial.new()
	material_9.shader = operands[107]
	material_9.set_shader_parameter("mask1_texture", operands[108])
	material_9.set_shader_parameter("mask1_scroll", operands[109])
	material_9.set_shader_parameter("mask1_scale", operands[110])
	material_9.set_shader_parameter("use_mask2", operands[111])
	material_9.set_shader_parameter("mask2_texture", operands[112])
	material_9.set_shader_parameter("mask2_scroll", operands[113])
	material_9.set_shader_parameter("mask2_strength", operands[114])
	material_9.set_shader_parameter("mask2_blend_mode", operands[115])
	material_9.set_shader_parameter("use_mask3", operands[116])
	material_9.set_shader_parameter("mask3_texture", operands[117])
	material_9.set_shader_parameter("mask3_strength", operands[118])
	material_9.set_shader_parameter("mask3_blend_mode", operands[119])
	material_9.set_shader_parameter("primary_color", operands[120])
	material_9.set_shader_parameter("secondary_color", operands[121])
	material_9.set_shader_parameter("tertiary_color", operands[122])
	material_9.set_shader_parameter("color_smoothness", operands[123])
	material_9.set_shader_parameter("emission_strength", operands[124])
	material_9.set_shader_parameter("alpha_smoothness", operands[125])
	material_9.set_shader_parameter("alpha_multiplier", operands[126])
	material_9.set_shader_parameter("alpha_cutoff", operands[127])
	material_9.set_meta("factory_occurrence_alpha", operands[128])
	var material_10: ShaderMaterial = operands[129]
	var material_11 := ShaderMaterial.new()
	material_11.shader = operands[130]
	material_11.set_shader_parameter("mask1_texture", operands[131])
	material_11.set_shader_parameter("mask1_scroll", operands[132])
	material_11.set_shader_parameter("mask1_scale", operands[133])
	material_11.set_shader_parameter("use_mask2", operands[134])
	material_11.set_shader_parameter("mask2_texture", operands[135])
	material_11.set_shader_parameter("mask2_scroll", operands[136])
	material_11.set_shader_parameter("mask2_strength", operands[137])
	material_11.set_shader_parameter("mask2_blend_mode", operands[138])
	material_11.set_shader_parameter("use_mask3", operands[139])
	material_11.set_shader_parameter("mask3_texture", operands[140])
	material_11.set_shader_parameter("mask3_strength", operands[141])
	material_11.set_shader_parameter("mask3_blend_mode", operands[142])
	material_11.set_shader_parameter("primary_color", operands[143])
	material_11.set_shader_parameter("secondary_color", operands[144])
	material_11.set_shader_parameter("tertiary_color", operands[145])
	material_11.set_shader_parameter("color_smoothness", operands[146])
	material_11.set_shader_parameter("emission_strength", operands[147])
	material_11.set_shader_parameter("alpha_smoothness", operands[148])
	material_11.set_shader_parameter("alpha_multiplier", operands[149])
	material_11.set_shader_parameter("alpha_cutoff", operands[150])
	material_11.set_meta("factory_occurrence_alpha", operands[151])
	var material_12: ShaderMaterial = operands[152]
	var material_13 := ShaderMaterial.new()
	material_13.shader = operands[153]
	material_13.set_shader_parameter("mask1_texture", operands[154])
	material_13.set_shader_parameter("mask1_scroll", operands[155])
	material_13.set_shader_parameter("mask1_scale", operands[156])
	material_13.set_shader_parameter("use_mask2", operands[157])
	material_13.set_shader_parameter("mask2_texture", operands[158])
	material_13.set_shader_parameter("mask2_scroll", operands[159])
	material_13.set_shader_parameter("mask2_strength", operands[160])
	material_13.set_shader_parameter("mask2_blend_mode", operands[161])
	material_13.set_shader_parameter("use_mask3", operands[162])
	material_13.set_shader_parameter("mask3_texture", operands[163])
	material_13.set_shader_parameter("mask3_strength", operands[164])
	material_13.set_shader_parameter("mask3_blend_mode", operands[165])
	material_13.set_shader_parameter("primary_color", operands[166])
	material_13.set_shader_parameter("secondary_color", operands[167])
	material_13.set_shader_parameter("tertiary_color", operands[168])
	material_13.set_shader_parameter("color_smoothness", operands[169])
	material_13.set_shader_parameter("emission_strength", operands[170])
	material_13.set_shader_parameter("alpha_smoothness", operands[171])
	material_13.set_shader_parameter("alpha_multiplier", operands[172])
	material_13.set_shader_parameter("alpha_cutoff", operands[173])
	material_13.set_meta("factory_occurrence_alpha", operands[174])
	var material_14: ShaderMaterial = operands[175]
	var material_15 := ShaderMaterial.new()
	material_15.shader = operands[176]
	material_15.set_shader_parameter("mask1_texture", operands[177])
	material_15.set_shader_parameter("mask1_scroll", operands[178])
	material_15.set_shader_parameter("mask1_scale", operands[179])
	material_15.set_shader_parameter("use_mask2", operands[180])
	material_15.set_shader_parameter("mask2_texture", operands[181])
	material_15.set_shader_parameter("mask2_scroll", operands[182])
	material_15.set_shader_parameter("mask2_strength", operands[183])
	material_15.set_shader_parameter("mask2_blend_mode", operands[184])
	material_15.set_shader_parameter("use_mask3", operands[185])
	material_15.set_shader_parameter("mask3_texture", operands[186])
	material_15.set_shader_parameter("mask3_strength", operands[187])
	material_15.set_shader_parameter("mask3_blend_mode", operands[188])
	material_15.set_shader_parameter("primary_color", operands[189])
	material_15.set_shader_parameter("secondary_color", operands[190])
	material_15.set_shader_parameter("tertiary_color", operands[191])
	material_15.set_shader_parameter("color_smoothness", operands[192])
	material_15.set_shader_parameter("emission_strength", operands[193])
	material_15.set_shader_parameter("alpha_smoothness", operands[194])
	material_15.set_shader_parameter("alpha_multiplier", operands[195])
	material_15.set_shader_parameter("alpha_cutoff", operands[196])
	material_15.set_meta("factory_occurrence_alpha", operands[197])
	var material_16: ShaderMaterial = operands[198]
	var material_17 := ShaderMaterial.new()
	material_17.shader = operands[199]
	material_17.set_shader_parameter("mask1_texture", operands[200])
	material_17.set_shader_parameter("mask1_scroll", operands[201])
	material_17.set_shader_parameter("mask1_scale", operands[202])
	material_17.set_shader_parameter("use_mask2", operands[203])
	material_17.set_shader_parameter("mask2_texture", operands[204])
	material_17.set_shader_parameter("mask2_scroll", operands[205])
	material_17.set_shader_parameter("mask2_strength", operands[206])
	material_17.set_shader_parameter("mask2_blend_mode", operands[207])
	material_17.set_shader_parameter("use_mask3", operands[208])
	material_17.set_shader_parameter("mask3_texture", operands[209])
	material_17.set_shader_parameter("mask3_strength", operands[210])
	material_17.set_shader_parameter("mask3_blend_mode", operands[211])
	material_17.set_shader_parameter("primary_color", operands[212])
	material_17.set_shader_parameter("secondary_color", operands[213])
	material_17.set_shader_parameter("tertiary_color", operands[214])
	material_17.set_shader_parameter("color_smoothness", operands[215])
	material_17.set_shader_parameter("emission_strength", operands[216])
	material_17.set_shader_parameter("alpha_smoothness", operands[217])
	material_17.set_shader_parameter("alpha_multiplier", operands[218])
	material_17.set_shader_parameter("alpha_cutoff", operands[219])
	material_17.set_meta("factory_occurrence_alpha", operands[220])
	var material_18: ShaderMaterial = operands[221]
	var material_19 := ShaderMaterial.new()
	material_19.shader = operands[222]
	material_19.set_shader_parameter("mask1_texture", operands[223])
	material_19.set_shader_parameter("mask1_scroll", operands[224])
	material_19.set_shader_parameter("mask1_scale", operands[225])
	material_19.set_shader_parameter("use_mask2", operands[226])
	material_19.set_shader_parameter("mask2_texture", operands[227])
	material_19.set_shader_parameter("mask2_scroll", operands[228])
	material_19.set_shader_parameter("mask2_strength", operands[229])
	material_19.set_shader_parameter("mask2_blend_mode", operands[230])
	material_19.set_shader_parameter("use_mask3", operands[231])
	material_19.set_shader_parameter("mask3_texture", operands[232])
	material_19.set_shader_parameter("mask3_strength", operands[233])
	material_19.set_shader_parameter("mask3_blend_mode", operands[234])
	material_19.set_shader_parameter("primary_color", operands[235])
	material_19.set_shader_parameter("secondary_color", operands[236])
	material_19.set_shader_parameter("tertiary_color", operands[237])
	material_19.set_shader_parameter("color_smoothness", operands[238])
	material_19.set_shader_parameter("emission_strength", operands[239])
	material_19.set_shader_parameter("alpha_smoothness", operands[240])
	material_19.set_shader_parameter("alpha_multiplier", operands[241])
	material_19.set_shader_parameter("alpha_cutoff", operands[242])
	material_19.set_meta("factory_occurrence_alpha", operands[243])
	var material_20: ShaderMaterial = operands[244]
	var material_21 := ShaderMaterial.new()
	material_21.shader = operands[245]
	material_21.set_shader_parameter("mask1_texture", operands[246])
	material_21.set_shader_parameter("mask1_scroll", operands[247])
	material_21.set_shader_parameter("mask1_scale", operands[248])
	material_21.set_shader_parameter("use_mask2", operands[249])
	material_21.set_shader_parameter("mask2_texture", operands[250])
	material_21.set_shader_parameter("mask2_scroll", operands[251])
	material_21.set_shader_parameter("mask2_strength", operands[252])
	material_21.set_shader_parameter("mask2_blend_mode", operands[253])
	material_21.set_shader_parameter("use_mask3", operands[254])
	material_21.set_shader_parameter("mask3_texture", operands[255])
	material_21.set_shader_parameter("mask3_strength", operands[256])
	material_21.set_shader_parameter("mask3_blend_mode", operands[257])
	material_21.set_shader_parameter("primary_color", operands[258])
	material_21.set_shader_parameter("secondary_color", operands[259])
	material_21.set_shader_parameter("tertiary_color", operands[260])
	material_21.set_shader_parameter("color_smoothness", operands[261])
	material_21.set_shader_parameter("emission_strength", operands[262])
	material_21.set_shader_parameter("alpha_smoothness", operands[263])
	material_21.set_shader_parameter("alpha_multiplier", operands[264])
	material_21.set_shader_parameter("alpha_cutoff", operands[265])
	material_21.set_meta("factory_occurrence_alpha", operands[266])
	var material_22: ShaderMaterial = operands[267]
	var material_23 := ShaderMaterial.new()
	material_23.shader = operands[268]
	material_23.set_shader_parameter("mask1_texture", operands[269])
	material_23.set_shader_parameter("mask1_scroll", operands[270])
	material_23.set_shader_parameter("mask1_scale", operands[271])
	material_23.set_shader_parameter("use_mask2", operands[272])
	material_23.set_shader_parameter("mask2_texture", operands[273])
	material_23.set_shader_parameter("mask2_scroll", operands[274])
	material_23.set_shader_parameter("mask2_strength", operands[275])
	material_23.set_shader_parameter("mask2_blend_mode", operands[276])
	material_23.set_shader_parameter("use_mask3", operands[277])
	material_23.set_shader_parameter("mask3_texture", operands[278])
	material_23.set_shader_parameter("mask3_strength", operands[279])
	material_23.set_shader_parameter("mask3_blend_mode", operands[280])
	material_23.set_shader_parameter("primary_color", operands[281])
	material_23.set_shader_parameter("secondary_color", operands[282])
	material_23.set_shader_parameter("tertiary_color", operands[283])
	material_23.set_shader_parameter("color_smoothness", operands[284])
	material_23.set_shader_parameter("emission_strength", operands[285])
	material_23.set_shader_parameter("alpha_smoothness", operands[286])
	material_23.set_shader_parameter("alpha_multiplier", operands[287])
	material_23.set_shader_parameter("alpha_cutoff", operands[288])
	material_23.set_meta("factory_occurrence_alpha", operands[289])
	var material_24: ShaderMaterial = operands[290]
	var material_25 := ShaderMaterial.new()
	material_25.shader = operands[291]
	material_25.set_shader_parameter("mask1_texture", operands[292])
	material_25.set_shader_parameter("mask1_scroll", operands[293])
	material_25.set_shader_parameter("mask1_scale", operands[294])
	material_25.set_shader_parameter("use_mask2", operands[295])
	material_25.set_shader_parameter("mask2_texture", operands[296])
	material_25.set_shader_parameter("mask2_scroll", operands[297])
	material_25.set_shader_parameter("mask2_strength", operands[298])
	material_25.set_shader_parameter("mask2_blend_mode", operands[299])
	material_25.set_shader_parameter("use_mask3", operands[300])
	material_25.set_shader_parameter("mask3_texture", operands[301])
	material_25.set_shader_parameter("mask3_strength", operands[302])
	material_25.set_shader_parameter("mask3_blend_mode", operands[303])
	material_25.set_shader_parameter("primary_color", operands[304])
	material_25.set_shader_parameter("secondary_color", operands[305])
	material_25.set_shader_parameter("tertiary_color", operands[306])
	material_25.set_shader_parameter("color_smoothness", operands[307])
	material_25.set_shader_parameter("emission_strength", operands[308])
	material_25.set_shader_parameter("alpha_smoothness", operands[309])
	material_25.set_shader_parameter("alpha_multiplier", operands[310])
	material_25.set_shader_parameter("alpha_cutoff", operands[311])
	material_25.set_meta("factory_occurrence_alpha", operands[312])
	var material_26: ShaderMaterial = operands[313]
	var material_27 := ShaderMaterial.new()
	material_27.shader = operands[314]
	material_27.set_shader_parameter("mask1_texture", operands[315])
	material_27.set_shader_parameter("mask1_scroll", operands[316])
	material_27.set_shader_parameter("mask1_scale", operands[317])
	material_27.set_shader_parameter("use_mask2", operands[318])
	material_27.set_shader_parameter("mask2_texture", operands[319])
	material_27.set_shader_parameter("mask2_scroll", operands[320])
	material_27.set_shader_parameter("mask2_strength", operands[321])
	material_27.set_shader_parameter("mask2_blend_mode", operands[322])
	material_27.set_shader_parameter("use_mask3", operands[323])
	material_27.set_shader_parameter("mask3_texture", operands[324])
	material_27.set_shader_parameter("mask3_strength", operands[325])
	material_27.set_shader_parameter("mask3_blend_mode", operands[326])
	material_27.set_shader_parameter("primary_color", operands[327])
	material_27.set_shader_parameter("secondary_color", operands[328])
	material_27.set_shader_parameter("tertiary_color", operands[329])
	material_27.set_shader_parameter("color_smoothness", operands[330])
	material_27.set_shader_parameter("emission_strength", operands[331])
	material_27.set_shader_parameter("alpha_smoothness", operands[332])
	material_27.set_shader_parameter("alpha_multiplier", operands[333])
	material_27.set_shader_parameter("alpha_cutoff", operands[334])
	material_27.set_meta("factory_occurrence_alpha", operands[335])
	var material_28: ShaderMaterial = operands[336]
	var material_29 := ShaderMaterial.new()
	material_29.shader = operands[337]
	material_29.set_shader_parameter("mask1_texture", operands[338])
	material_29.set_shader_parameter("mask1_scroll", operands[339])
	material_29.set_shader_parameter("mask1_scale", operands[340])
	material_29.set_shader_parameter("use_mask2", operands[341])
	material_29.set_shader_parameter("mask2_texture", operands[342])
	material_29.set_shader_parameter("mask2_scroll", operands[343])
	material_29.set_shader_parameter("mask2_strength", operands[344])
	material_29.set_shader_parameter("mask2_blend_mode", operands[345])
	material_29.set_shader_parameter("use_mask3", operands[346])
	material_29.set_shader_parameter("mask3_texture", operands[347])
	material_29.set_shader_parameter("mask3_strength", operands[348])
	material_29.set_shader_parameter("mask3_blend_mode", operands[349])
	material_29.set_shader_parameter("primary_color", operands[350])
	material_29.set_shader_parameter("secondary_color", operands[351])
	material_29.set_shader_parameter("tertiary_color", operands[352])
	material_29.set_shader_parameter("color_smoothness", operands[353])
	material_29.set_shader_parameter("emission_strength", operands[354])
	material_29.set_shader_parameter("alpha_smoothness", operands[355])
	material_29.set_shader_parameter("alpha_multiplier", operands[356])
	material_29.set_shader_parameter("alpha_cutoff", operands[357])
	material_29.set_meta("factory_occurrence_alpha", operands[358])
	var material_30: ShaderMaterial = operands[359]
	var material_31 := ShaderMaterial.new()
	material_31.shader = operands[360]
	material_31.set_shader_parameter("mask1_texture", operands[361])
	material_31.set_shader_parameter("mask1_scroll", operands[362])
	material_31.set_shader_parameter("mask1_scale", operands[363])
	material_31.set_shader_parameter("use_mask2", operands[364])
	material_31.set_shader_parameter("mask2_texture", operands[365])
	material_31.set_shader_parameter("mask2_scroll", operands[366])
	material_31.set_shader_parameter("mask2_strength", operands[367])
	material_31.set_shader_parameter("mask2_blend_mode", operands[368])
	material_31.set_shader_parameter("use_mask3", operands[369])
	material_31.set_shader_parameter("mask3_texture", operands[370])
	material_31.set_shader_parameter("mask3_strength", operands[371])
	material_31.set_shader_parameter("mask3_blend_mode", operands[372])
	material_31.set_shader_parameter("primary_color", operands[373])
	material_31.set_shader_parameter("secondary_color", operands[374])
	material_31.set_shader_parameter("tertiary_color", operands[375])
	material_31.set_shader_parameter("color_smoothness", operands[376])
	material_31.set_shader_parameter("emission_strength", operands[377])
	material_31.set_shader_parameter("alpha_smoothness", operands[378])
	material_31.set_shader_parameter("alpha_multiplier", operands[379])
	material_31.set_shader_parameter("alpha_cutoff", operands[380])
	material_31.set_meta("factory_occurrence_alpha", operands[381])
	var material_32: ShaderMaterial = operands[382]
	var material_33 := ShaderMaterial.new()
	material_33.shader = operands[383]
	material_33.set_shader_parameter("mask1_texture", operands[384])
	material_33.set_shader_parameter("mask1_scroll", operands[385])
	material_33.set_shader_parameter("mask1_scale", operands[386])
	material_33.set_shader_parameter("use_mask2", operands[387])
	material_33.set_shader_parameter("mask2_texture", operands[388])
	material_33.set_shader_parameter("mask2_scroll", operands[389])
	material_33.set_shader_parameter("mask2_strength", operands[390])
	material_33.set_shader_parameter("mask2_blend_mode", operands[391])
	material_33.set_shader_parameter("use_mask3", operands[392])
	material_33.set_shader_parameter("mask3_texture", operands[393])
	material_33.set_shader_parameter("mask3_strength", operands[394])
	material_33.set_shader_parameter("mask3_blend_mode", operands[395])
	material_33.set_shader_parameter("primary_color", operands[396])
	material_33.set_shader_parameter("secondary_color", operands[397])
	material_33.set_shader_parameter("tertiary_color", operands[398])
	material_33.set_shader_parameter("color_smoothness", operands[399])
	material_33.set_shader_parameter("emission_strength", operands[400])
	material_33.set_shader_parameter("alpha_smoothness", operands[401])
	material_33.set_shader_parameter("alpha_multiplier", operands[402])
	material_33.set_shader_parameter("alpha_cutoff", operands[403])
	material_33.set_meta("factory_occurrence_alpha", operands[404])
	var material_34: ShaderMaterial = operands[405]
	var material_35 := ShaderMaterial.new()
	material_35.shader = operands[406]
	material_35.set_shader_parameter("mask1_texture", operands[407])
	material_35.set_shader_parameter("mask1_scroll", operands[408])
	material_35.set_shader_parameter("mask1_scale", operands[409])
	material_35.set_shader_parameter("use_mask2", operands[410])
	material_35.set_shader_parameter("mask2_texture", operands[411])
	material_35.set_shader_parameter("mask2_scroll", operands[412])
	material_35.set_shader_parameter("mask2_strength", operands[413])
	material_35.set_shader_parameter("mask2_blend_mode", operands[414])
	material_35.set_shader_parameter("use_mask3", operands[415])
	material_35.set_shader_parameter("mask3_texture", operands[416])
	material_35.set_shader_parameter("mask3_strength", operands[417])
	material_35.set_shader_parameter("mask3_blend_mode", operands[418])
	material_35.set_shader_parameter("primary_color", operands[419])
	material_35.set_shader_parameter("secondary_color", operands[420])
	material_35.set_shader_parameter("tertiary_color", operands[421])
	material_35.set_shader_parameter("color_smoothness", operands[422])
	material_35.set_shader_parameter("emission_strength", operands[423])
	material_35.set_shader_parameter("alpha_smoothness", operands[424])
	material_35.set_shader_parameter("alpha_multiplier", operands[425])
	material_35.set_shader_parameter("alpha_cutoff", operands[426])
	material_35.set_meta("factory_occurrence_alpha", operands[427])
	var material_36: ShaderMaterial = operands[428]
	var material_37 := ShaderMaterial.new()
	material_37.shader = operands[429]
	material_37.set_shader_parameter("mask1_texture", operands[430])
	material_37.set_shader_parameter("mask1_scroll", operands[431])
	material_37.set_shader_parameter("mask1_scale", operands[432])
	material_37.set_shader_parameter("use_mask2", operands[433])
	material_37.set_shader_parameter("mask2_texture", operands[434])
	material_37.set_shader_parameter("mask2_scroll", operands[435])
	material_37.set_shader_parameter("mask2_strength", operands[436])
	material_37.set_shader_parameter("mask2_blend_mode", operands[437])
	material_37.set_shader_parameter("use_mask3", operands[438])
	material_37.set_shader_parameter("mask3_texture", operands[439])
	material_37.set_shader_parameter("mask3_strength", operands[440])
	material_37.set_shader_parameter("mask3_blend_mode", operands[441])
	material_37.set_shader_parameter("primary_color", operands[442])
	material_37.set_shader_parameter("secondary_color", operands[443])
	material_37.set_shader_parameter("tertiary_color", operands[444])
	material_37.set_shader_parameter("color_smoothness", operands[445])
	material_37.set_shader_parameter("emission_strength", operands[446])
	material_37.set_shader_parameter("alpha_smoothness", operands[447])
	material_37.set_shader_parameter("alpha_multiplier", operands[448])
	material_37.set_shader_parameter("alpha_cutoff", operands[449])
	material_37.set_meta("factory_occurrence_alpha", operands[450])
	var material_38: ShaderMaterial = operands[451]
	var material_39 := ShaderMaterial.new()
	material_39.shader = operands[452]
	material_39.set_shader_parameter("mask1_texture", operands[453])
	material_39.set_shader_parameter("mask1_scroll", operands[454])
	material_39.set_shader_parameter("mask1_scale", operands[455])
	material_39.set_shader_parameter("use_mask2", operands[456])
	material_39.set_shader_parameter("mask2_texture", operands[457])
	material_39.set_shader_parameter("mask2_scroll", operands[458])
	material_39.set_shader_parameter("mask2_strength", operands[459])
	material_39.set_shader_parameter("mask2_blend_mode", operands[460])
	material_39.set_shader_parameter("use_mask3", operands[461])
	material_39.set_shader_parameter("mask3_texture", operands[462])
	material_39.set_shader_parameter("mask3_strength", operands[463])
	material_39.set_shader_parameter("mask3_blend_mode", operands[464])
	material_39.set_shader_parameter("primary_color", operands[465])
	material_39.set_shader_parameter("secondary_color", operands[466])
	material_39.set_shader_parameter("tertiary_color", operands[467])
	material_39.set_shader_parameter("color_smoothness", operands[468])
	material_39.set_shader_parameter("emission_strength", operands[469])
	material_39.set_shader_parameter("alpha_smoothness", operands[470])
	material_39.set_shader_parameter("alpha_multiplier", operands[471])
	material_39.set_shader_parameter("alpha_cutoff", operands[472])
	material_39.set_meta("factory_occurrence_alpha", operands[473])
	var material_40: ShaderMaterial = operands[474]
	var material_41 := ShaderMaterial.new()
	material_41.shader = operands[475]
	material_41.set_shader_parameter("mask1_texture", operands[476])
	material_41.set_shader_parameter("mask1_scroll", operands[477])
	material_41.set_shader_parameter("mask1_scale", operands[478])
	material_41.set_shader_parameter("use_mask2", operands[479])
	material_41.set_shader_parameter("mask2_texture", operands[480])
	material_41.set_shader_parameter("mask2_scroll", operands[481])
	material_41.set_shader_parameter("mask2_strength", operands[482])
	material_41.set_shader_parameter("mask2_blend_mode", operands[483])
	material_41.set_shader_parameter("use_mask3", operands[484])
	material_41.set_shader_parameter("mask3_texture", operands[485])
	material_41.set_shader_parameter("mask3_strength", operands[486])
	material_41.set_shader_parameter("mask3_blend_mode", operands[487])
	material_41.set_shader_parameter("primary_color", operands[488])
	material_41.set_shader_parameter("secondary_color", operands[489])
	material_41.set_shader_parameter("tertiary_color", operands[490])
	material_41.set_shader_parameter("color_smoothness", operands[491])
	material_41.set_shader_parameter("emission_strength", operands[492])
	material_41.set_shader_parameter("alpha_smoothness", operands[493])
	material_41.set_shader_parameter("alpha_multiplier", operands[494])
	material_41.set_shader_parameter("alpha_cutoff", operands[495])
	material_41.set_meta("factory_occurrence_alpha", operands[496])
	var material_42: ShaderMaterial = operands[497]
	var material_43 := ShaderMaterial.new()
	material_43.shader = operands[498]
	material_43.set_shader_parameter("mask1_texture", operands[499])
	material_43.set_shader_parameter("mask1_scroll", operands[500])
	material_43.set_shader_parameter("mask1_scale", operands[501])
	material_43.set_shader_parameter("use_mask2", operands[502])
	material_43.set_shader_parameter("mask2_texture", operands[503])
	material_43.set_shader_parameter("mask2_scroll", operands[504])
	material_43.set_shader_parameter("mask2_strength", operands[505])
	material_43.set_shader_parameter("mask2_blend_mode", operands[506])
	material_43.set_shader_parameter("use_mask3", operands[507])
	material_43.set_shader_parameter("mask3_texture", operands[508])
	material_43.set_shader_parameter("mask3_strength", operands[509])
	material_43.set_shader_parameter("mask3_blend_mode", operands[510])
	material_43.set_shader_parameter("primary_color", operands[511])
	material_43.set_shader_parameter("secondary_color", operands[512])
	material_43.set_shader_parameter("tertiary_color", operands[513])
	material_43.set_shader_parameter("color_smoothness", operands[514])
	material_43.set_shader_parameter("emission_strength", operands[515])
	material_43.set_shader_parameter("alpha_smoothness", operands[516])
	material_43.set_shader_parameter("alpha_multiplier", operands[517])
	material_43.set_shader_parameter("alpha_cutoff", operands[518])
	material_43.set_meta("factory_occurrence_alpha", operands[519])
	var material_44: ShaderMaterial = operands[520]
	var material_45: ShaderMaterial = operands[521]
	var material_46 := ShaderMaterial.new()
	material_46.shader = operands[522]
	material_46.set_shader_parameter("cloud_carrier_feather_uv", operands[523])
	material_46.set_shader_parameter("noise_texture_1", operands[524])
	material_46.set_shader_parameter("noise_texture_2", operands[525])
	material_46.set_shader_parameter("texture_mask", operands[526])
	material_46.set_shader_parameter("edge_softness", operands[527])
	material_46.set_shader_parameter("texture_scale", operands[528])
	material_46.set_shader_parameter("smoke_color", operands[529])
	material_46.set_shader_parameter("mask_scale", operands[530])
	material_46.set_meta("factory_occurrence_alpha", operands[531])
	material_46.set_meta("factory_prepared_shader", operands[532])
	material_46.set_meta("factory_opacity_prepared_shader", operands[533])
	material_46.set_meta("factory_world_space_uniform", operands[534])
	material_46.set_meta("factory_clock_names", operands[535])
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "Donor"
	var node_1 := GPUParticles3D.new()
	node_1.name = "Clouds_01"
	node_1.transform = operands[536]
	node_1.visible = operands[537]
	node_1.material_override = material_0
	node_1.amount = operands[538]
	node_1.lifetime = operands[539]
	node_1.preprocess = operands[540]
	node_1.use_fixed_seed = operands[541]
	node_1.seed = operands[542]
	node_1.fixed_fps = operands[543]
	node_1.visibility_aabb = operands[544]
	node_1.local_coords = operands[545]
	node_1.transform_align = operands[546]
	node_1.process_material = material_1
	node_1.draw_pass_1 = operands[547]
	node_0.add_child(node_1)
	var node_2 := GPUParticles3D.new()
	node_2.name = "Clouds_02"
	node_2.transform = operands[548]
	node_2.visible = operands[549]
	node_2.sorting_offset = operands[550]
	node_2.material_override = material_2
	node_2.amount = operands[551]
	node_2.lifetime = operands[552]
	node_2.preprocess = operands[553]
	node_2.use_fixed_seed = operands[554]
	node_2.seed = operands[555]
	node_2.fixed_fps = operands[556]
	node_2.visibility_aabb = operands[557]
	node_2.local_coords = operands[558]
	node_2.transform_align = operands[559]
	node_2.process_material = material_3
	node_2.draw_pass_1 = operands[560]
	node_0.add_child(node_2)
	var node_3 := MeshInstance3D.new()
	node_3.name = "Glow"
	node_3.visible = operands[561]
	node_3.sorting_offset = operands[562]
	node_3.material_override = material_4
	node_3.mesh = operands[563]
	node_0.add_child(node_3)
	var node_4 := AnimationPlayer.new()
	node_4.name = "AnimationPlayer"
	node_4.process_mode = operands[564]
	node_4.set("libraries/", operands[565])
	node_0.add_child(node_4)
	var node_5 := GPUParticles3D.new()
	node_5.name = "BoundaryBillow0"
	node_5.transform = operands[566]
	node_5.visible = operands[567]
	node_5.sorting_offset = operands[568]
	node_5.material_override = material_5
	node_5.amount = operands[569]
	node_5.lifetime = operands[570]
	node_5.preprocess = operands[571]
	node_5.use_fixed_seed = operands[572]
	node_5.seed = operands[573]
	node_5.fixed_fps = operands[574]
	node_5.visibility_aabb = operands[575]
	node_5.local_coords = operands[576]
	node_5.transform_align = operands[577]
	node_5.process_material = material_6
	node_5.draw_pass_1 = operands[578]
	node_0.add_child(node_5)
	var node_6 := GPUParticles3D.new()
	node_6.name = "BoundaryBillow1"
	node_6.transform = operands[579]
	node_6.visible = operands[580]
	node_6.sorting_offset = operands[581]
	node_6.material_override = material_7
	node_6.amount = operands[582]
	node_6.lifetime = operands[583]
	node_6.preprocess = operands[584]
	node_6.use_fixed_seed = operands[585]
	node_6.seed = operands[586]
	node_6.fixed_fps = operands[587]
	node_6.visibility_aabb = operands[588]
	node_6.local_coords = operands[589]
	node_6.transform_align = operands[590]
	node_6.process_material = material_8
	node_6.draw_pass_1 = operands[591]
	node_0.add_child(node_6)
	var node_7 := GPUParticles3D.new()
	node_7.name = "BoundaryBillow2"
	node_7.transform = operands[592]
	node_7.visible = operands[593]
	node_7.sorting_offset = operands[594]
	node_7.material_override = material_9
	node_7.amount = operands[595]
	node_7.lifetime = operands[596]
	node_7.preprocess = operands[597]
	node_7.use_fixed_seed = operands[598]
	node_7.seed = operands[599]
	node_7.fixed_fps = operands[600]
	node_7.visibility_aabb = operands[601]
	node_7.local_coords = operands[602]
	node_7.transform_align = operands[603]
	node_7.process_material = material_10
	node_7.draw_pass_1 = operands[604]
	node_0.add_child(node_7)
	var node_8 := GPUParticles3D.new()
	node_8.name = "BoundaryBillow3"
	node_8.transform = operands[605]
	node_8.visible = operands[606]
	node_8.sorting_offset = operands[607]
	node_8.material_override = material_11
	node_8.amount = operands[608]
	node_8.lifetime = operands[609]
	node_8.preprocess = operands[610]
	node_8.use_fixed_seed = operands[611]
	node_8.seed = operands[612]
	node_8.fixed_fps = operands[613]
	node_8.visibility_aabb = operands[614]
	node_8.local_coords = operands[615]
	node_8.transform_align = operands[616]
	node_8.process_material = material_12
	node_8.draw_pass_1 = operands[617]
	node_0.add_child(node_8)
	var node_9 := GPUParticles3D.new()
	node_9.name = "BoundaryBillow4"
	node_9.transform = operands[618]
	node_9.visible = operands[619]
	node_9.sorting_offset = operands[620]
	node_9.material_override = material_13
	node_9.amount = operands[621]
	node_9.lifetime = operands[622]
	node_9.preprocess = operands[623]
	node_9.use_fixed_seed = operands[624]
	node_9.seed = operands[625]
	node_9.fixed_fps = operands[626]
	node_9.visibility_aabb = operands[627]
	node_9.local_coords = operands[628]
	node_9.transform_align = operands[629]
	node_9.process_material = material_14
	node_9.draw_pass_1 = operands[630]
	node_0.add_child(node_9)
	var node_10 := GPUParticles3D.new()
	node_10.name = "BoundaryBillow5"
	node_10.transform = operands[631]
	node_10.visible = operands[632]
	node_10.sorting_offset = operands[633]
	node_10.material_override = material_15
	node_10.amount = operands[634]
	node_10.lifetime = operands[635]
	node_10.preprocess = operands[636]
	node_10.use_fixed_seed = operands[637]
	node_10.seed = operands[638]
	node_10.fixed_fps = operands[639]
	node_10.visibility_aabb = operands[640]
	node_10.local_coords = operands[641]
	node_10.transform_align = operands[642]
	node_10.process_material = material_16
	node_10.draw_pass_1 = operands[643]
	node_0.add_child(node_10)
	var node_11 := GPUParticles3D.new()
	node_11.name = "BoundaryBillow6"
	node_11.transform = operands[644]
	node_11.visible = operands[645]
	node_11.sorting_offset = operands[646]
	node_11.material_override = material_17
	node_11.amount = operands[647]
	node_11.lifetime = operands[648]
	node_11.preprocess = operands[649]
	node_11.use_fixed_seed = operands[650]
	node_11.seed = operands[651]
	node_11.fixed_fps = operands[652]
	node_11.visibility_aabb = operands[653]
	node_11.local_coords = operands[654]
	node_11.transform_align = operands[655]
	node_11.process_material = material_18
	node_11.draw_pass_1 = operands[656]
	node_0.add_child(node_11)
	var node_12 := GPUParticles3D.new()
	node_12.name = "BoundaryBillow7"
	node_12.transform = operands[657]
	node_12.visible = operands[658]
	node_12.sorting_offset = operands[659]
	node_12.material_override = material_19
	node_12.amount = operands[660]
	node_12.lifetime = operands[661]
	node_12.preprocess = operands[662]
	node_12.use_fixed_seed = operands[663]
	node_12.seed = operands[664]
	node_12.fixed_fps = operands[665]
	node_12.visibility_aabb = operands[666]
	node_12.local_coords = operands[667]
	node_12.transform_align = operands[668]
	node_12.process_material = material_20
	node_12.draw_pass_1 = operands[669]
	node_0.add_child(node_12)
	var node_13 := GPUParticles3D.new()
	node_13.name = "BoundaryBillow8"
	node_13.transform = operands[670]
	node_13.visible = operands[671]
	node_13.sorting_offset = operands[672]
	node_13.material_override = material_21
	node_13.amount = operands[673]
	node_13.lifetime = operands[674]
	node_13.preprocess = operands[675]
	node_13.use_fixed_seed = operands[676]
	node_13.seed = operands[677]
	node_13.fixed_fps = operands[678]
	node_13.visibility_aabb = operands[679]
	node_13.local_coords = operands[680]
	node_13.transform_align = operands[681]
	node_13.process_material = material_22
	node_13.draw_pass_1 = operands[682]
	node_0.add_child(node_13)
	var node_14 := GPUParticles3D.new()
	node_14.name = "BoundaryBillow9"
	node_14.transform = operands[683]
	node_14.visible = operands[684]
	node_14.sorting_offset = operands[685]
	node_14.material_override = material_23
	node_14.amount = operands[686]
	node_14.lifetime = operands[687]
	node_14.preprocess = operands[688]
	node_14.use_fixed_seed = operands[689]
	node_14.seed = operands[690]
	node_14.fixed_fps = operands[691]
	node_14.visibility_aabb = operands[692]
	node_14.local_coords = operands[693]
	node_14.transform_align = operands[694]
	node_14.process_material = material_24
	node_14.draw_pass_1 = operands[695]
	node_0.add_child(node_14)
	var node_15 := GPUParticles3D.new()
	node_15.name = "BoundaryBillow10"
	node_15.transform = operands[696]
	node_15.visible = operands[697]
	node_15.sorting_offset = operands[698]
	node_15.material_override = material_25
	node_15.amount = operands[699]
	node_15.lifetime = operands[700]
	node_15.preprocess = operands[701]
	node_15.use_fixed_seed = operands[702]
	node_15.seed = operands[703]
	node_15.fixed_fps = operands[704]
	node_15.visibility_aabb = operands[705]
	node_15.local_coords = operands[706]
	node_15.transform_align = operands[707]
	node_15.process_material = material_26
	node_15.draw_pass_1 = operands[708]
	node_0.add_child(node_15)
	var node_16 := GPUParticles3D.new()
	node_16.name = "BoundaryBillow11"
	node_16.transform = operands[709]
	node_16.visible = operands[710]
	node_16.sorting_offset = operands[711]
	node_16.material_override = material_27
	node_16.amount = operands[712]
	node_16.lifetime = operands[713]
	node_16.preprocess = operands[714]
	node_16.use_fixed_seed = operands[715]
	node_16.seed = operands[716]
	node_16.fixed_fps = operands[717]
	node_16.visibility_aabb = operands[718]
	node_16.local_coords = operands[719]
	node_16.transform_align = operands[720]
	node_16.process_material = material_28
	node_16.draw_pass_1 = operands[721]
	node_0.add_child(node_16)
	var node_17 := GPUParticles3D.new()
	node_17.name = "BoundaryBillow12"
	node_17.transform = operands[722]
	node_17.visible = operands[723]
	node_17.sorting_offset = operands[724]
	node_17.material_override = material_29
	node_17.amount = operands[725]
	node_17.lifetime = operands[726]
	node_17.preprocess = operands[727]
	node_17.use_fixed_seed = operands[728]
	node_17.seed = operands[729]
	node_17.fixed_fps = operands[730]
	node_17.visibility_aabb = operands[731]
	node_17.local_coords = operands[732]
	node_17.transform_align = operands[733]
	node_17.process_material = material_30
	node_17.draw_pass_1 = operands[734]
	node_0.add_child(node_17)
	var node_18 := GPUParticles3D.new()
	node_18.name = "BoundaryBillow13"
	node_18.transform = operands[735]
	node_18.visible = operands[736]
	node_18.sorting_offset = operands[737]
	node_18.material_override = material_31
	node_18.amount = operands[738]
	node_18.lifetime = operands[739]
	node_18.preprocess = operands[740]
	node_18.use_fixed_seed = operands[741]
	node_18.seed = operands[742]
	node_18.fixed_fps = operands[743]
	node_18.visibility_aabb = operands[744]
	node_18.local_coords = operands[745]
	node_18.transform_align = operands[746]
	node_18.process_material = material_32
	node_18.draw_pass_1 = operands[747]
	node_0.add_child(node_18)
	var node_19 := GPUParticles3D.new()
	node_19.name = "BoundaryBillow14"
	node_19.transform = operands[748]
	node_19.visible = operands[749]
	node_19.sorting_offset = operands[750]
	node_19.material_override = material_33
	node_19.amount = operands[751]
	node_19.lifetime = operands[752]
	node_19.preprocess = operands[753]
	node_19.use_fixed_seed = operands[754]
	node_19.seed = operands[755]
	node_19.fixed_fps = operands[756]
	node_19.visibility_aabb = operands[757]
	node_19.local_coords = operands[758]
	node_19.transform_align = operands[759]
	node_19.process_material = material_34
	node_19.draw_pass_1 = operands[760]
	node_0.add_child(node_19)
	var node_20 := GPUParticles3D.new()
	node_20.name = "BoundaryBillow15"
	node_20.transform = operands[761]
	node_20.visible = operands[762]
	node_20.sorting_offset = operands[763]
	node_20.material_override = material_35
	node_20.amount = operands[764]
	node_20.lifetime = operands[765]
	node_20.preprocess = operands[766]
	node_20.use_fixed_seed = operands[767]
	node_20.seed = operands[768]
	node_20.fixed_fps = operands[769]
	node_20.visibility_aabb = operands[770]
	node_20.local_coords = operands[771]
	node_20.transform_align = operands[772]
	node_20.process_material = material_36
	node_20.draw_pass_1 = operands[773]
	node_0.add_child(node_20)
	var node_21 := GPUParticles3D.new()
	node_21.name = "BoundaryBillow16"
	node_21.transform = operands[774]
	node_21.visible = operands[775]
	node_21.sorting_offset = operands[776]
	node_21.material_override = material_37
	node_21.amount = operands[777]
	node_21.lifetime = operands[778]
	node_21.preprocess = operands[779]
	node_21.use_fixed_seed = operands[780]
	node_21.seed = operands[781]
	node_21.fixed_fps = operands[782]
	node_21.visibility_aabb = operands[783]
	node_21.local_coords = operands[784]
	node_21.transform_align = operands[785]
	node_21.process_material = material_38
	node_21.draw_pass_1 = operands[786]
	node_0.add_child(node_21)
	var node_22 := GPUParticles3D.new()
	node_22.name = "BoundaryBillow17"
	node_22.transform = operands[787]
	node_22.visible = operands[788]
	node_22.sorting_offset = operands[789]
	node_22.material_override = material_39
	node_22.amount = operands[790]
	node_22.lifetime = operands[791]
	node_22.preprocess = operands[792]
	node_22.use_fixed_seed = operands[793]
	node_22.seed = operands[794]
	node_22.fixed_fps = operands[795]
	node_22.visibility_aabb = operands[796]
	node_22.local_coords = operands[797]
	node_22.transform_align = operands[798]
	node_22.process_material = material_40
	node_22.draw_pass_1 = operands[799]
	node_0.add_child(node_22)
	var node_23 := GPUParticles3D.new()
	node_23.name = "BoundaryBillow18"
	node_23.transform = operands[800]
	node_23.visible = operands[801]
	node_23.sorting_offset = operands[802]
	node_23.material_override = material_41
	node_23.amount = operands[803]
	node_23.lifetime = operands[804]
	node_23.preprocess = operands[805]
	node_23.use_fixed_seed = operands[806]
	node_23.seed = operands[807]
	node_23.fixed_fps = operands[808]
	node_23.visibility_aabb = operands[809]
	node_23.local_coords = operands[810]
	node_23.transform_align = operands[811]
	node_23.process_material = material_42
	node_23.draw_pass_1 = operands[812]
	node_0.add_child(node_23)
	var node_24 := GPUParticles3D.new()
	node_24.name = "BoundaryBillow19"
	node_24.transform = operands[813]
	node_24.visible = operands[814]
	node_24.sorting_offset = operands[815]
	node_24.material_override = material_43
	node_24.amount = operands[816]
	node_24.lifetime = operands[817]
	node_24.preprocess = operands[818]
	node_24.use_fixed_seed = operands[819]
	node_24.seed = operands[820]
	node_24.fixed_fps = operands[821]
	node_24.visibility_aabb = operands[822]
	node_24.local_coords = operands[823]
	node_24.transform_align = operands[824]
	node_24.process_material = material_44
	node_24.draw_pass_1 = operands[825]
	node_0.add_child(node_24)
	var node_25 := GPUParticles3D.new()
	node_25.name = "Flame"
	node_25.transform = operands[826]
	node_25.sorting_offset = operands[827]
	node_25.sorting_use_aabb_center = operands[828]
	node_25.amount = operands[829]
	node_25.lifetime = operands[830]
	node_25.one_shot = operands[831]
	node_25.preprocess = operands[832]
	node_25.use_fixed_seed = operands[833]
	node_25.seed = operands[834]
	node_25.fixed_fps = operands[835]
	node_25.visibility_aabb = operands[836]
	node_25.local_coords = operands[837]
	node_25.draw_order = operands[838]
	node_25.process_material = material_45
	var mesh_0: Mesh = operands[839].duplicate(false)
	mesh_0.surface_set_material(0, material_46)
	node_25.draw_pass_1 = mesh_0
	node_0.add_child(node_25)
	var node_26 := GPUParticles3D.new()
	node_26.name = "Flame_next_cohort"
	node_26.transform = operands[840]
	node_26.sorting_offset = operands[841]
	node_26.sorting_use_aabb_center = operands[842]
	node_26.emitting = operands[843]
	node_26.amount = operands[844]
	node_26.lifetime = operands[845]
	node_26.one_shot = operands[846]
	node_26.use_fixed_seed = operands[847]
	node_26.seed = operands[848]
	node_26.fixed_fps = operands[849]
	node_26.visibility_aabb = operands[850]
	node_26.local_coords = operands[851]
	node_26.draw_order = operands[852]
	node_26.process_material = material_45
	node_26.draw_pass_1 = mesh_0
	node_0.add_child(node_26)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"root": node_0, "geometry": [node_1, node_2, node_3, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26], "materials": [node_25.get_draw_pass_mesh(0).surface_get_material(0)], "cohorts": [[node_25, node_26]]}
