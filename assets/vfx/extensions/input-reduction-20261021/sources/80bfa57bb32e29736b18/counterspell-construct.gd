extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("vfx_package_clock_slot", operands[1])
	material_0.set_shader_parameter("factory_world_to_source", operands[2])
	material_0.set_shader_parameter("finger_source_palette", operands[3])
	material_0.set_shader_parameter("finger_source_count", operands[4])
	material_0.set_shader_parameter("finger_source_exponent", operands[5])
	material_0.set_shader_parameter("noise_tex", operands[6])
	material_0.set_shader_parameter("age", operands[7])
	material_0.set_shader_parameter("env", operands[8])
	material_0.set_meta("finger_source_finish_v193", operands[9])
	material_0.set_meta("factory_clock_names", operands[10])
	material_0.set_meta("factory_prepared_shader", operands[11])
	material_0.set_meta("factory_opacity_prepared_shader", operands[12])
	material_0.set_meta("factory_world_space_uniform", operands[13])
	material_0.set_meta("factory_clock_pool_required", operands[14])
	material_0.set_meta("factory_native_program_defaults", operands[15])
	var material_1: ShaderMaterial = material_0
	var material_2: ShaderMaterial = material_0
	var material_3: ShaderMaterial = material_0
	var material_4: ShaderMaterial = material_0
	var material_5: ShaderMaterial = material_0
	var material_6: ShaderMaterial = material_0
	var material_7: ShaderMaterial = material_0
	var material_8: ShaderMaterial = material_0
	var material_9: ShaderMaterial = material_0
	var material_10: ShaderMaterial = material_0
	var material_11: ShaderMaterial = material_0
	var material_12: ShaderMaterial = material_0
	var material_13: ShaderMaterial = material_0
	var material_14: ShaderMaterial = material_0
	var material_15: ShaderMaterial = material_0
	var material_16: ShaderMaterial = material_0
	var material_17: ShaderMaterial = material_0
	var material_18: ShaderMaterial = material_0
	var material_19: ShaderMaterial = material_0
	var material_20: ShaderMaterial = material_0
	var material_21: ShaderMaterial = material_0
	var material_22: ShaderMaterial = material_0
	var material_23: ShaderMaterial = material_0
	var material_24: ShaderMaterial = material_0
	var material_25: ShaderMaterial = material_0
	var material_26: ShaderMaterial = material_0
	var material_27: ShaderMaterial = material_0
	var material_28: ShaderMaterial = material_0
	var material_29: ShaderMaterial = material_0
	var material_30: ShaderMaterial = material_0
	var material_31 := ShaderMaterial.new()
	material_31.shader = operands[496]
	material_31.render_priority = -1
	material_31.set_shader_parameter("vfx_package_clock_slot", operands[497])
	material_31.set_shader_parameter("factory_world_to_source", operands[498])
	material_31.set_shader_parameter("finger_source_palette", operands[499])
	material_31.set_shader_parameter("finger_source_count", operands[500])
	material_31.set_shader_parameter("finger_source_exponent", operands[501])
	material_31.set_shader_parameter("age", operands[502])
	material_31.set_shader_parameter("env", operands[503])
	material_31.set_shader_parameter("Intensity", operands[504])
	material_31.set_shader_parameter("Texture_Add", operands[505])
	material_31.set_shader_parameter("Enable_Distortion", operands[506])
	material_31.set_shader_parameter("Dist_Zoom_Strenght", operands[507])
	material_31.set_shader_parameter("Diost_repeat_strenght", operands[508])
	material_31.set_shader_parameter("Distortion_Speed_XY", operands[509])
	material_31.set_shader_parameter("Distortion_Texture", operands[510])
	material_31.set_shader_parameter("Distortion_Attenuation", operands[511])
	material_31.set_shader_parameter("Zoom_Strenght", operands[512])
	material_31.set_shader_parameter("repeat", operands[513])
	material_31.set_shader_parameter("Speed_XY", operands[514])
	material_31.set_shader_parameter("Texture_Main", operands[515])
	material_31.set_shader_parameter("Power", operands[516])
	material_31.set_shader_parameter("Texture_Substract", operands[517])
	material_31.set_shader_parameter("Proximity_Fade", operands[518])
	material_31.set_shader_parameter("Color_1D_Gradient", operands[519])
	material_31.set_shader_parameter("Transparency", operands[520])
	material_31.set_meta("finger_source_finish_v193", operands[521])
	material_31.set_meta("factory_clock_names", operands[522])
	material_31.set_meta("factory_prepared_shader", operands[523])
	material_31.set_meta("factory_opacity_prepared_shader", operands[524])
	material_31.set_meta("factory_world_space_uniform", operands[525])
	material_31.set_meta("factory_clock_pool_required", operands[526])
	material_31.set_meta("factory_native_program_defaults", operands[527])
	var material_32 := ShaderMaterial.new()
	material_32.shader = operands[528]
	material_32.set_shader_parameter("factory_world_to_source", operands[529])
	material_32.set_shader_parameter("finger_source_palette", operands[530])
	material_32.set_shader_parameter("finger_source_count", operands[531])
	material_32.set_shader_parameter("finger_source_exponent", operands[532])
	material_32.set_shader_parameter("env", operands[533])
	material_32.set_meta("finger_source_finish_v193", operands[534])
	material_32.set_meta("factory_prepared_shader", operands[535])
	material_32.set_meta("factory_opacity_prepared_shader", operands[536])
	material_32.set_meta("factory_world_space_uniform", operands[537])
	material_32.set_meta("factory_clock_pool_required", operands[538])
	material_32.set_meta("factory_native_program_defaults", operands[539])
	var material_33 := ShaderMaterial.new()
	material_33.shader = operands[540]
	material_33.set_shader_parameter("factory_world_to_source", operands[541])
	material_33.set_shader_parameter("finger_source_palette", operands[542])
	material_33.set_shader_parameter("finger_source_count", operands[543])
	material_33.set_shader_parameter("finger_source_exponent", operands[544])
	material_33.set_shader_parameter("env", operands[545])
	material_33.set_meta("finger_source_finish_v193", operands[546])
	material_33.set_meta("factory_prepared_shader", operands[547])
	material_33.set_meta("factory_opacity_prepared_shader", operands[548])
	material_33.set_meta("factory_world_space_uniform", operands[549])
	material_33.set_meta("factory_clock_pool_required", operands[550])
	material_33.set_meta("factory_native_program_defaults", operands[551])
	var material_34 := ShaderMaterial.new()
	material_34.shader = operands[552]
	material_34.set_shader_parameter("factory_world_to_source", operands[553])
	material_34.set_shader_parameter("finger_source_palette", operands[554])
	material_34.set_shader_parameter("finger_source_count", operands[555])
	material_34.set_shader_parameter("finger_source_exponent", operands[556])
	material_34.set_shader_parameter("sprite", operands[557])
	material_34.set_shader_parameter("env", operands[558])
	material_34.set_meta("finger_source_finish_v193", operands[559])
	material_34.set_meta("factory_prepared_shader", operands[560])
	material_34.set_meta("factory_opacity_prepared_shader", operands[561])
	material_34.set_meta("factory_world_space_uniform", operands[562])
	material_34.set_meta("factory_clock_pool_required", operands[563])
	material_34.set_meta("factory_native_program_defaults", operands[564])
	var material_35 := ShaderMaterial.new()
	material_35.shader = operands[565]
	material_35.set_shader_parameter("direction", operands[566])
	material_35.set_shader_parameter("spread", operands[567])
	material_35.set_shader_parameter("flatness", operands[568])
	material_35.set_shader_parameter("inherit_emitter_velocity_ratio", operands[569])
	material_35.set_shader_parameter("initial_linear_velocity_min", operands[570])
	material_35.set_shader_parameter("initial_linear_velocity_max", operands[571])
	material_35.set_shader_parameter("directional_velocity_min", operands[572])
	material_35.set_shader_parameter("directional_velocity_max", operands[573])
	material_35.set_shader_parameter("angular_velocity_min", operands[574])
	material_35.set_shader_parameter("angular_velocity_max", operands[575])
	material_35.set_shader_parameter("orbit_velocity_min", operands[576])
	material_35.set_shader_parameter("orbit_velocity_max", operands[577])
	material_35.set_shader_parameter("radial_velocity_min", operands[578])
	material_35.set_shader_parameter("radial_velocity_max", operands[579])
	material_35.set_shader_parameter("linear_accel_min", operands[580])
	material_35.set_shader_parameter("linear_accel_max", operands[581])
	material_35.set_shader_parameter("radial_accel_min", operands[582])
	material_35.set_shader_parameter("radial_accel_max", operands[583])
	material_35.set_shader_parameter("tangent_accel_min", operands[584])
	material_35.set_shader_parameter("tangent_accel_max", operands[585])
	material_35.set_shader_parameter("damping_min", operands[586])
	material_35.set_shader_parameter("damping_max", operands[587])
	material_35.set_shader_parameter("initial_angle_min", operands[588])
	material_35.set_shader_parameter("initial_angle_max", operands[589])
	material_35.set_shader_parameter("scale_min", operands[590])
	material_35.set_shader_parameter("scale_max", operands[591])
	material_35.set_shader_parameter("hue_variation_min", operands[592])
	material_35.set_shader_parameter("hue_variation_max", operands[593])
	material_35.set_shader_parameter("anim_speed_min", operands[594])
	material_35.set_shader_parameter("anim_speed_max", operands[595])
	material_35.set_shader_parameter("anim_offset_min", operands[596])
	material_35.set_shader_parameter("anim_offset_max", operands[597])
	material_35.set_shader_parameter("lifetime_randomness", operands[598])
	material_35.set_shader_parameter("emission_shape_offset", operands[599])
	material_35.set_shader_parameter("emission_shape_scale", operands[600])
	material_35.set_shader_parameter("velocity_pivot", operands[601])
	material_35.set_shader_parameter("emission_sphere_radius", operands[602])
	material_35.set_shader_parameter("color_value", operands[603])
	material_35.set_shader_parameter("gravity", operands[604])
	material_35.set_shader_parameter("tangent_accel_texture", operands[605])
	material_35.set_shader_parameter("scale_curve", operands[606])
	material_35.set_shader_parameter("radial_velocity_curve", operands[607])
	material_35.set_shader_parameter("directional_velocity_curve", operands[608])
	material_35.set_meta("factory_prepared_shader", operands[609])
	material_35.set_meta("factory_clock_names", operands[610])
	material_35.set_meta("factory_opacity_prepared_shader", operands[611])
	material_35.set_meta("factory_native_process_source", operands[612])
	material_35.set_meta("factory_clock_pool_required", operands[613])
	material_35.set_meta("factory_world_space_uniform", operands[614])
	material_35.set_meta("factory_native_program_defaults", operands[615])
	var material_36 := ShaderMaterial.new()
	material_36.shader = operands[616]
	material_36.set_shader_parameter("factory_world_to_source", operands[617])
	material_36.set_shader_parameter("finger_source_palette", operands[618])
	material_36.set_shader_parameter("finger_source_count", operands[619])
	material_36.set_shader_parameter("finger_source_exponent", operands[620])
	material_36.set_shader_parameter("sprite", operands[621])
	material_36.set_shader_parameter("env", operands[622])
	material_36.set_meta("finger_source_finish_v193", operands[623])
	material_36.set_meta("factory_prepared_shader", operands[624])
	material_36.set_meta("factory_opacity_prepared_shader", operands[625])
	material_36.set_meta("factory_world_space_uniform", operands[626])
	material_36.set_meta("factory_clock_pool_required", operands[627])
	material_36.set_meta("factory_native_program_defaults", operands[628])
	var material_37 := ShaderMaterial.new()
	material_37.shader = operands[629]
	material_37.set_shader_parameter("direction", operands[630])
	material_37.set_shader_parameter("spread", operands[631])
	material_37.set_shader_parameter("flatness", operands[632])
	material_37.set_shader_parameter("inherit_emitter_velocity_ratio", operands[633])
	material_37.set_shader_parameter("initial_linear_velocity_min", operands[634])
	material_37.set_shader_parameter("initial_linear_velocity_max", operands[635])
	material_37.set_shader_parameter("directional_velocity_min", operands[636])
	material_37.set_shader_parameter("directional_velocity_max", operands[637])
	material_37.set_shader_parameter("angular_velocity_min", operands[638])
	material_37.set_shader_parameter("angular_velocity_max", operands[639])
	material_37.set_shader_parameter("orbit_velocity_min", operands[640])
	material_37.set_shader_parameter("orbit_velocity_max", operands[641])
	material_37.set_shader_parameter("radial_velocity_min", operands[642])
	material_37.set_shader_parameter("radial_velocity_max", operands[643])
	material_37.set_shader_parameter("linear_accel_min", operands[644])
	material_37.set_shader_parameter("linear_accel_max", operands[645])
	material_37.set_shader_parameter("radial_accel_min", operands[646])
	material_37.set_shader_parameter("radial_accel_max", operands[647])
	material_37.set_shader_parameter("tangent_accel_min", operands[648])
	material_37.set_shader_parameter("tangent_accel_max", operands[649])
	material_37.set_shader_parameter("damping_min", operands[650])
	material_37.set_shader_parameter("damping_max", operands[651])
	material_37.set_shader_parameter("initial_angle_min", operands[652])
	material_37.set_shader_parameter("initial_angle_max", operands[653])
	material_37.set_shader_parameter("scale_min", operands[654])
	material_37.set_shader_parameter("scale_max", operands[655])
	material_37.set_shader_parameter("hue_variation_min", operands[656])
	material_37.set_shader_parameter("hue_variation_max", operands[657])
	material_37.set_shader_parameter("anim_speed_min", operands[658])
	material_37.set_shader_parameter("anim_speed_max", operands[659])
	material_37.set_shader_parameter("anim_offset_min", operands[660])
	material_37.set_shader_parameter("anim_offset_max", operands[661])
	material_37.set_shader_parameter("lifetime_randomness", operands[662])
	material_37.set_shader_parameter("emission_shape_offset", operands[663])
	material_37.set_shader_parameter("emission_shape_scale", operands[664])
	material_37.set_shader_parameter("velocity_pivot", operands[665])
	material_37.set_shader_parameter("color_value", operands[666])
	material_37.set_shader_parameter("gravity", operands[667])
	material_37.set_shader_parameter("alpha_curve", operands[668])
	material_37.set_shader_parameter("scale_curve", operands[669])
	material_37.set_meta("factory_prepared_shader", operands[670])
	material_37.set_meta("factory_clock_names", operands[671])
	material_37.set_meta("factory_opacity_prepared_shader", operands[672])
	material_37.set_meta("factory_native_process_source", operands[673])
	material_37.set_meta("factory_clock_pool_required", operands[674])
	material_37.set_meta("factory_world_space_uniform", operands[675])
	material_37.set_meta("factory_native_program_defaults", operands[676])
	var material_38 := ShaderMaterial.new()
	material_38.shader = operands[677]
	material_38.render_priority = 1
	material_38.set_shader_parameter("vfx_package_clock_slot", operands[678])
	material_38.set_shader_parameter("vfx_clock", operands[679])
	material_38.set_shader_parameter("vfx_alpha", operands[680])
	material_38.set_shader_parameter("original_palette", operands[681])
	material_38.set_shader_parameter("Size_Sphere", operands[682])
	material_38.set_shader_parameter("Gradient_Line", operands[683])
	material_38.set_shader_parameter("Line_Baias", operands[684])
	material_38.set_shader_parameter("SmoothStep", operands[685])
	material_38.set_shader_parameter("Disolver_Scale", operands[686])
	material_38.set_shader_parameter("Disolver_Noise_Line", operands[687])
	material_38.set_shader_parameter("Line_Distortion_Divider", operands[688])
	material_38.set_shader_parameter("Gradient_Disappear", operands[689])
	material_38.set_shader_parameter("Line_Gradient", operands[690])
	material_38.set_shader_parameter("Overlay_Scale", operands[691])
	material_38.set_shader_parameter("Overlay_Velocity", operands[692])
	material_38.set_shader_parameter("Overlay_Texture", operands[693])
	material_38.set_shader_parameter("Overlay_Power", operands[694])
	material_38.set_shader_parameter("Proximity_light", operands[695])
	material_38.set_shader_parameter("Proximity_Power", operands[696])
	material_38.set_shader_parameter("Fresnel_invert", operands[697])
	material_38.set_shader_parameter("fresnel_power", operands[698])
	material_38.set_shader_parameter("darkness", operands[699])
	material_38.set_shader_parameter("Gradient_1D_Color", operands[700])
	material_38.set_meta("factory_clock_names", operands[701])
	material_38.set_meta("factory_prepared_shader", operands[702])
	material_38.set_meta("factory_opacity_prepared_shader", operands[703])
	material_38.set_meta("factory_world_space_uniform", operands[704])
	material_38.set_meta("factory_clock_pool_required", operands[705])
	material_38.set_meta("factory_native_program_defaults", operands[706])
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "assembly"
	var node_1 := Node3D.new()
	node_1.name = "effect"
	node_1.visible = operands[707]
	node_0.add_child(node_1)
	var node_2 := Node3D.new()
	node_2.name = "OriginalCounterspellHand"
	node_2.visible = operands[708]
	node_1.add_child(node_2)
	var node_3 := Node3D.new()
	node_3.name = "FactoryGenerated_0000_Node3D"
	node_3.transform = operands[709]
	node_2.add_child(node_3)
	var node_4 := Node3D.new()
	node_4.name = "Donor"
	node_3.add_child(node_4)
	var node_5 := Node3D.new()
	node_5.name = "SkeletalCounterspellV5"
	node_5.transform = operands[710]
	node_4.add_child(node_5)
	var node_6 := Node3D.new()
	node_6.name = "SkeletalHandRig"
	node_5.add_child(node_6)
	var node_7 := Skeleton3D.new()
	node_7.name = "Skeleton3D"
	node_7.set("bones/0/name", operands[711])
	node_7.set("bones/0/parent", operands[712])
	node_7.set("bones/0/rest", operands[713])
	node_7.set("bones/0/enabled", operands[714])
	node_7.set("bones/0/position", operands[715])
	node_7.set("bones/0/rotation", operands[716])
	node_7.set("bones/0/scale", operands[717])
	node_7.set("bones/1/name", operands[718])
	node_7.set("bones/1/parent", operands[719])
	node_7.set("bones/1/rest", operands[720])
	node_7.set("bones/1/enabled", operands[721])
	node_7.set("bones/1/position", operands[722])
	node_7.set("bones/1/rotation", operands[723])
	node_7.set("bones/1/scale", operands[724])
	node_7.set("bones/2/name", operands[725])
	node_7.set("bones/2/parent", operands[726])
	node_7.set("bones/2/rest", operands[727])
	node_7.set("bones/2/enabled", operands[728])
	node_7.set("bones/2/position", operands[729])
	node_7.set("bones/2/rotation", operands[730])
	node_7.set("bones/2/scale", operands[731])
	node_7.set("bones/3/name", operands[732])
	node_7.set("bones/3/parent", operands[733])
	node_7.set("bones/3/rest", operands[734])
	node_7.set("bones/3/enabled", operands[735])
	node_7.set("bones/3/position", operands[736])
	node_7.set("bones/3/rotation", operands[737])
	node_7.set("bones/3/scale", operands[738])
	node_7.set("bones/4/name", operands[739])
	node_7.set("bones/4/parent", operands[740])
	node_7.set("bones/4/rest", operands[741])
	node_7.set("bones/4/enabled", operands[742])
	node_7.set("bones/4/position", operands[743])
	node_7.set("bones/4/rotation", operands[744])
	node_7.set("bones/4/scale", operands[745])
	node_7.set("bones/5/name", operands[746])
	node_7.set("bones/5/parent", operands[747])
	node_7.set("bones/5/rest", operands[748])
	node_7.set("bones/5/enabled", operands[749])
	node_7.set("bones/5/position", operands[750])
	node_7.set("bones/5/rotation", operands[751])
	node_7.set("bones/5/scale", operands[752])
	node_7.set("bones/6/name", operands[753])
	node_7.set("bones/6/parent", operands[754])
	node_7.set("bones/6/rest", operands[755])
	node_7.set("bones/6/enabled", operands[756])
	node_7.set("bones/6/position", operands[757])
	node_7.set("bones/6/rotation", operands[758])
	node_7.set("bones/6/scale", operands[759])
	node_7.set("bones/7/name", operands[760])
	node_7.set("bones/7/parent", operands[761])
	node_7.set("bones/7/rest", operands[762])
	node_7.set("bones/7/enabled", operands[763])
	node_7.set("bones/7/position", operands[764])
	node_7.set("bones/7/rotation", operands[765])
	node_7.set("bones/7/scale", operands[766])
	node_7.set("bones/8/name", operands[767])
	node_7.set("bones/8/parent", operands[768])
	node_7.set("bones/8/rest", operands[769])
	node_7.set("bones/8/enabled", operands[770])
	node_7.set("bones/8/position", operands[771])
	node_7.set("bones/8/rotation", operands[772])
	node_7.set("bones/8/scale", operands[773])
	node_7.set("bones/9/name", operands[774])
	node_7.set("bones/9/parent", operands[775])
	node_7.set("bones/9/rest", operands[776])
	node_7.set("bones/9/enabled", operands[777])
	node_7.set("bones/9/position", operands[778])
	node_7.set("bones/9/rotation", operands[779])
	node_7.set("bones/9/scale", operands[780])
	node_7.set("bones/10/name", operands[781])
	node_7.set("bones/10/parent", operands[782])
	node_7.set("bones/10/rest", operands[783])
	node_7.set("bones/10/enabled", operands[784])
	node_7.set("bones/10/position", operands[785])
	node_7.set("bones/10/rotation", operands[786])
	node_7.set("bones/10/scale", operands[787])
	node_7.set("bones/11/name", operands[788])
	node_7.set("bones/11/parent", operands[789])
	node_7.set("bones/11/rest", operands[790])
	node_7.set("bones/11/enabled", operands[791])
	node_7.set("bones/11/position", operands[792])
	node_7.set("bones/11/rotation", operands[793])
	node_7.set("bones/11/scale", operands[794])
	node_7.set("bones/12/name", operands[795])
	node_7.set("bones/12/parent", operands[796])
	node_7.set("bones/12/rest", operands[797])
	node_7.set("bones/12/enabled", operands[798])
	node_7.set("bones/12/position", operands[799])
	node_7.set("bones/12/rotation", operands[800])
	node_7.set("bones/12/scale", operands[801])
	node_7.set("bones/13/name", operands[802])
	node_7.set("bones/13/parent", operands[803])
	node_7.set("bones/13/rest", operands[804])
	node_7.set("bones/13/enabled", operands[805])
	node_7.set("bones/13/position", operands[806])
	node_7.set("bones/13/rotation", operands[807])
	node_7.set("bones/13/scale", operands[808])
	node_7.set("bones/14/name", operands[809])
	node_7.set("bones/14/parent", operands[810])
	node_7.set("bones/14/rest", operands[811])
	node_7.set("bones/14/enabled", operands[812])
	node_7.set("bones/14/position", operands[813])
	node_7.set("bones/14/rotation", operands[814])
	node_7.set("bones/14/scale", operands[815])
	node_7.set("bones/15/name", operands[816])
	node_7.set("bones/15/parent", operands[817])
	node_7.set("bones/15/rest", operands[818])
	node_7.set("bones/15/enabled", operands[819])
	node_7.set("bones/15/position", operands[820])
	node_7.set("bones/15/rotation", operands[821])
	node_7.set("bones/15/scale", operands[822])
	node_7.set("bones/16/name", operands[823])
	node_7.set("bones/16/parent", operands[824])
	node_7.set("bones/16/rest", operands[825])
	node_7.set("bones/16/enabled", operands[826])
	node_7.set("bones/16/position", operands[827])
	node_7.set("bones/16/rotation", operands[828])
	node_7.set("bones/16/scale", operands[829])
	node_7.set("bones/17/name", operands[830])
	node_7.set("bones/17/parent", operands[831])
	node_7.set("bones/17/rest", operands[832])
	node_7.set("bones/17/enabled", operands[833])
	node_7.set("bones/17/position", operands[834])
	node_7.set("bones/17/rotation", operands[835])
	node_7.set("bones/17/scale", operands[836])
	node_7.set("bones/18/name", operands[837])
	node_7.set("bones/18/parent", operands[838])
	node_7.set("bones/18/rest", operands[839])
	node_7.set("bones/18/enabled", operands[840])
	node_7.set("bones/18/position", operands[841])
	node_7.set("bones/18/rotation", operands[842])
	node_7.set("bones/18/scale", operands[843])
	node_7.set("bones/19/name", operands[844])
	node_7.set("bones/19/parent", operands[845])
	node_7.set("bones/19/rest", operands[846])
	node_7.set("bones/19/enabled", operands[847])
	node_7.set("bones/19/position", operands[848])
	node_7.set("bones/19/rotation", operands[849])
	node_7.set("bones/19/scale", operands[850])
	node_7.set("bones/20/name", operands[851])
	node_7.set("bones/20/parent", operands[852])
	node_7.set("bones/20/rest", operands[853])
	node_7.set("bones/20/enabled", operands[854])
	node_7.set("bones/20/position", operands[855])
	node_7.set("bones/20/rotation", operands[856])
	node_7.set("bones/20/scale", operands[857])
	node_6.add_child(node_7)
	var node_8 := BoneAttachment3D.new()
	node_8.name = "finger_1_2_2"
	node_8.transform = operands[858]
	node_8.bone_name = operands[859]
	node_8.bone_idx = operands[860]
	node_7.add_child(node_8)
	var node_9 := Node3D.new()
	node_9.name = "IndexEmissionSocket"
	node_9.transform = operands[861]
	node_8.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "Carpal_0"
	node_10.material_override = material_0
	node_10.mesh = operands[862]
	node_10.skin = operands[863]
	node_10.skeleton = operands[864]
	node_7.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "Carpal_1"
	node_11.material_override = material_1
	node_11.mesh = operands[865]
	node_11.skin = operands[866]
	node_11.skeleton = operands[867]
	node_7.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "Carpal_2"
	node_12.material_override = material_2
	node_12.mesh = operands[868]
	node_12.skin = operands[869]
	node_12.skeleton = operands[870]
	node_7.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "Carpal_3"
	node_13.material_override = material_3
	node_13.mesh = operands[871]
	node_13.skin = operands[872]
	node_13.skeleton = operands[873]
	node_7.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "Carpal_4"
	node_14.material_override = material_4
	node_14.mesh = operands[874]
	node_14.skin = operands[875]
	node_14.skeleton = operands[876]
	node_7.add_child(node_14)
	var node_15 := MeshInstance3D.new()
	node_15.name = "Carpal_5"
	node_15.material_override = material_5
	node_15.mesh = operands[877]
	node_15.skin = operands[878]
	node_15.skeleton = operands[879]
	node_7.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "Carpal_6"
	node_16.material_override = material_6
	node_16.mesh = operands[880]
	node_16.skin = operands[881]
	node_16.skeleton = operands[882]
	node_7.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "Carpal_7"
	node_17.material_override = material_7
	node_17.mesh = operands[883]
	node_17.skin = operands[884]
	node_17.skeleton = operands[885]
	node_7.add_child(node_17)
	var node_18 := MeshInstance3D.new()
	node_18.name = "finger_0_0"
	node_18.material_override = material_8
	node_18.mesh = operands[886]
	node_18.skin = operands[887]
	node_18.skeleton = operands[888]
	node_7.add_child(node_18)
	var node_19 := MeshInstance3D.new()
	node_19.name = "finger_0_1"
	node_19.material_override = material_9
	node_19.mesh = operands[889]
	node_19.skin = operands[890]
	node_19.skeleton = operands[891]
	node_7.add_child(node_19)
	var node_20 := MeshInstance3D.new()
	node_20.name = "finger_1_0"
	node_20.material_override = material_10
	node_20.mesh = operands[892]
	node_20.skin = operands[893]
	node_20.skeleton = operands[894]
	node_7.add_child(node_20)
	var node_21 := MeshInstance3D.new()
	node_21.name = "finger_1_1"
	node_21.material_override = material_11
	node_21.mesh = operands[895]
	node_21.skin = operands[896]
	node_21.skeleton = operands[897]
	node_7.add_child(node_21)
	var node_22 := MeshInstance3D.new()
	node_22.name = "finger_1_2"
	node_22.material_override = material_12
	node_22.mesh = operands[898]
	node_22.skin = operands[899]
	node_22.skeleton = operands[900]
	node_7.add_child(node_22)
	var node_23 := MeshInstance3D.new()
	node_23.name = "finger_2_0"
	node_23.material_override = material_13
	node_23.mesh = operands[901]
	node_23.skin = operands[902]
	node_23.skeleton = operands[903]
	node_7.add_child(node_23)
	var node_24 := MeshInstance3D.new()
	node_24.name = "finger_2_1"
	node_24.material_override = material_14
	node_24.mesh = operands[904]
	node_24.skin = operands[905]
	node_24.skeleton = operands[906]
	node_7.add_child(node_24)
	var node_25 := MeshInstance3D.new()
	node_25.name = "finger_2_2"
	node_25.material_override = material_15
	node_25.mesh = operands[907]
	node_25.skin = operands[908]
	node_25.skeleton = operands[909]
	node_7.add_child(node_25)
	var node_26 := MeshInstance3D.new()
	node_26.name = "finger_3_0"
	node_26.material_override = material_16
	node_26.mesh = operands[910]
	node_26.skin = operands[911]
	node_26.skeleton = operands[912]
	node_7.add_child(node_26)
	var node_27 := MeshInstance3D.new()
	node_27.name = "finger_3_1"
	node_27.material_override = material_17
	node_27.mesh = operands[913]
	node_27.skin = operands[914]
	node_27.skeleton = operands[915]
	node_7.add_child(node_27)
	var node_28 := MeshInstance3D.new()
	node_28.name = "finger_3_2"
	node_28.material_override = material_18
	node_28.mesh = operands[916]
	node_28.skin = operands[917]
	node_28.skeleton = operands[918]
	node_7.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "finger_4_0"
	node_29.material_override = material_19
	node_29.mesh = operands[919]
	node_29.skin = operands[920]
	node_29.skeleton = operands[921]
	node_7.add_child(node_29)
	var node_30 := MeshInstance3D.new()
	node_30.name = "finger_4_1"
	node_30.material_override = material_20
	node_30.mesh = operands[922]
	node_30.skin = operands[923]
	node_30.skeleton = operands[924]
	node_7.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "finger_4_2"
	node_31.material_override = material_21
	node_31.mesh = operands[925]
	node_31.skin = operands[926]
	node_31.skeleton = operands[927]
	node_7.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "forearm"
	node_32.material_override = material_22
	node_32.mesh = operands[928]
	node_32.skin = operands[929]
	node_32.skeleton = operands[930]
	node_7.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "forearm_001"
	node_33.material_override = material_23
	node_33.mesh = operands[931]
	node_33.skin = operands[932]
	node_33.skeleton = operands[933]
	node_7.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "metacarpal_0"
	node_34.material_override = material_24
	node_34.mesh = operands[934]
	node_34.skin = operands[935]
	node_34.skeleton = operands[936]
	node_7.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "metacarpal_1"
	node_35.material_override = material_25
	node_35.mesh = operands[937]
	node_35.skin = operands[938]
	node_35.skeleton = operands[939]
	node_7.add_child(node_35)
	var node_36 := MeshInstance3D.new()
	node_36.name = "metacarpal_2"
	node_36.material_override = material_26
	node_36.mesh = operands[940]
	node_36.skin = operands[941]
	node_36.skeleton = operands[942]
	node_7.add_child(node_36)
	var node_37 := MeshInstance3D.new()
	node_37.name = "metacarpal_3"
	node_37.material_override = material_27
	node_37.mesh = operands[943]
	node_37.skin = operands[944]
	node_37.skeleton = operands[945]
	node_7.add_child(node_37)
	var node_38 := MeshInstance3D.new()
	node_38.name = "metacarpal_4"
	node_38.material_override = material_28
	node_38.mesh = operands[946]
	node_38.skin = operands[947]
	node_38.skeleton = operands[948]
	node_7.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "wrist"
	node_39.material_override = material_29
	node_39.mesh = operands[949]
	node_39.skin = operands[950]
	node_39.skeleton = operands[951]
	node_7.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "wrist_001"
	node_40.material_override = material_30
	node_40.mesh = operands[952]
	node_40.skin = operands[953]
	node_40.skeleton = operands[954]
	node_7.add_child(node_40)
	var node_41 := AnimationPlayer.new()
	node_41.name = "AnimationPlayer"
	node_41.callback_mode_process = operands[955]
	node_41.set("libraries/", operands[956])
	node_5.add_child(node_41)
	var node_42 := MeshInstance3D.new()
	node_42.name = "HandBirthPortal"
	node_42.transform = operands[957]
	node_42.material_override = material_31
	node_42.mesh = operands[958]
	node_4.add_child(node_42)
	var node_43 := MeshInstance3D.new()
	node_43.name = "FactoryGenerated_0002_MeshInstance3D"
	node_43.transform = operands[959]
	node_43.material_override = material_32
	node_43.mesh = operands[960]
	node_4.add_child(node_43)
	var node_44 := MeshInstance3D.new()
	node_44.name = "FactoryGenerated_0003_MeshInstance3D"
	node_44.transform = operands[961]
	node_44.material_override = material_33
	node_44.mesh = operands[962]
	node_4.add_child(node_44)
	var node_45 := GPUParticles3D.new()
	node_45.name = "sparkling_details2"
	node_45.transform = operands[963]
	node_45.material_override = material_34
	node_45.cast_shadow = operands[964]
	node_45.emitting = operands[965]
	node_45.amount = operands[966]
	node_45.lifetime = operands[967]
	node_45.explosiveness = operands[968]
	node_45.randomness = operands[969]
	node_45.use_fixed_seed = operands[970]
	node_45.seed = operands[971]
	node_45.fixed_fps = operands[972]
	node_45.local_coords = operands[973]
	node_45.process_material = material_35
	node_45.draw_pass_1 = operands[974]
	node_45.set("metadata/_edit_lock_", operands[975])
	node_4.add_child(node_45)
	var node_46 := GPUParticles3D.new()
	node_46.name = "muzzle2start"
	node_46.transform = operands[976]
	node_46.material_override = material_36
	node_46.cast_shadow = operands[977]
	node_46.emitting = operands[978]
	node_46.amount = operands[979]
	node_46.lifetime = operands[980]
	node_46.one_shot = operands[981]
	node_46.explosiveness = operands[982]
	node_46.use_fixed_seed = operands[983]
	node_46.seed = operands[984]
	node_46.fixed_fps = operands[985]
	node_46.local_coords = operands[986]
	node_46.process_material = material_37
	node_46.draw_pass_1 = operands[987]
	node_46.set("metadata/_edit_lock_", operands[988])
	node_4.add_child(node_46)
	var node_47 := DirectionalLight3D.new()
	node_47.name = "FactoryGenerated_0006_DirectionalLight3D"
	node_47.transform = operands[989]
	node_47.light_energy = operands[990]
	node_47.set("metadata/factory_light_role", operands[991])
	node_4.add_child(node_47)
	var node_48 := Node3D.new()
	node_48.name = "OriginalCoralInterception"
	node_48.transform = operands[992]
	node_48.visible = operands[993]
	node_1.add_child(node_48)
	var node_49 := MeshInstance3D.new()
	node_49.name = "OriginalUnequalOpposingShieldFragments"
	node_49.transform = operands[994]
	node_49.visible = operands[995]
	node_49.material_override = material_38
	node_49.cast_shadow = operands[996]
	node_49.mesh = operands[997]
	node_48.add_child(node_49)
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
	node_49.owner = node_0
	node_0.scene_file_path = operands[998]
	return {"material_sites_bound": true, "nodes": [node_0, node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_41, node_42, node_43, node_44, node_45, node_46, node_47, node_48, node_49], "private_materials": [material_0, material_1, material_2, material_3, material_4, material_5, material_6, material_7, material_8, material_9, material_10, material_11, material_12, material_13, material_14, material_15, material_16, material_17, material_18, material_19, material_20, material_21, material_22, material_23, material_24, material_25, material_26, material_27, material_28, material_29, material_30, material_31, material_32, material_33, material_34, material_35, material_36, material_37, material_38], "root": node_0, "geometry": [node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_42, node_43, node_44, node_45, node_46, node_49], "materials": [], "cohorts": []}
