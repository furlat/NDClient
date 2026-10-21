extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("vfx_package_clock_slot", operands[1])
	material_0.set_shader_parameter("factory_world_to_source", operands[2])
	material_0.set_shader_parameter("noise_tex", operands[3])
	material_0.set_shader_parameter("age", operands[4])
	material_0.set_shader_parameter("env", operands[5])
	material_0.set_meta("factory_clock_names", operands[6])
	material_0.set_meta("factory_prepared_shader", operands[7])
	material_0.set_meta("factory_opacity_prepared_shader", operands[8])
	material_0.set_meta("factory_world_space_uniform", operands[9])
	material_0.set_meta("factory_clock_pool_required", operands[10])
	material_0.set_meta("factory_native_program_defaults", operands[11])
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
	var material_29 := ShaderMaterial.new()
	material_29.shader = operands[348]
	material_29.render_priority = -1
	material_29.set_shader_parameter("vfx_package_clock_slot", operands[349])
	material_29.set_shader_parameter("factory_world_to_source", operands[350])
	material_29.set_shader_parameter("age", operands[351])
	material_29.set_shader_parameter("env", operands[352])
	material_29.set_shader_parameter("Intensity", operands[353])
	material_29.set_shader_parameter("Texture_Add", operands[354])
	material_29.set_shader_parameter("Enable_Distortion", operands[355])
	material_29.set_shader_parameter("Dist_Zoom_Strenght", operands[356])
	material_29.set_shader_parameter("Diost_repeat_strenght", operands[357])
	material_29.set_shader_parameter("Distortion_Speed_XY", operands[358])
	material_29.set_shader_parameter("Distortion_Texture", operands[359])
	material_29.set_shader_parameter("Distortion_Attenuation", operands[360])
	material_29.set_shader_parameter("Zoom_Strenght", operands[361])
	material_29.set_shader_parameter("repeat", operands[362])
	material_29.set_shader_parameter("Speed_XY", operands[363])
	material_29.set_shader_parameter("Texture_Main", operands[364])
	material_29.set_shader_parameter("Power", operands[365])
	material_29.set_shader_parameter("Texture_Substract", operands[366])
	material_29.set_shader_parameter("Proximity_Fade", operands[367])
	material_29.set_shader_parameter("Color_1D_Gradient", operands[368])
	material_29.set_shader_parameter("Transparency", operands[369])
	material_29.set_meta("factory_clock_names", operands[370])
	material_29.set_meta("factory_prepared_shader", operands[371])
	material_29.set_meta("factory_opacity_prepared_shader", operands[372])
	material_29.set_meta("factory_world_space_uniform", operands[373])
	material_29.set_meta("factory_clock_pool_required", operands[374])
	material_29.set_meta("factory_native_program_defaults", operands[375])
	var material_30 := ShaderMaterial.new()
	material_30.shader = operands[376]
	material_30.set_shader_parameter("factory_world_to_source", operands[377])
	material_30.set_shader_parameter("env", operands[378])
	material_30.set_meta("factory_prepared_shader", operands[379])
	material_30.set_meta("factory_opacity_prepared_shader", operands[380])
	material_30.set_meta("factory_world_space_uniform", operands[381])
	material_30.set_meta("factory_clock_pool_required", operands[382])
	material_30.set_meta("factory_native_program_defaults", operands[383])
	var material_31 := ShaderMaterial.new()
	material_31.shader = operands[384]
	material_31.set_shader_parameter("factory_world_to_source", operands[385])
	material_31.set_shader_parameter("env", operands[386])
	material_31.set_meta("factory_prepared_shader", operands[387])
	material_31.set_meta("factory_opacity_prepared_shader", operands[388])
	material_31.set_meta("factory_world_space_uniform", operands[389])
	material_31.set_meta("factory_clock_pool_required", operands[390])
	material_31.set_meta("factory_native_program_defaults", operands[391])
	var material_32 := ShaderMaterial.new()
	material_32.shader = operands[392]
	material_32.set_shader_parameter("factory_world_to_source", operands[393])
	material_32.set_shader_parameter("sprite", operands[394])
	material_32.set_shader_parameter("env", operands[395])
	material_32.set_meta("factory_prepared_shader", operands[396])
	material_32.set_meta("factory_opacity_prepared_shader", operands[397])
	material_32.set_meta("factory_world_space_uniform", operands[398])
	material_32.set_meta("factory_clock_pool_required", operands[399])
	material_32.set_meta("factory_native_program_defaults", operands[400])
	var material_33 := ShaderMaterial.new()
	material_33.shader = operands[401]
	material_33.set_shader_parameter("direction", operands[402])
	material_33.set_shader_parameter("spread", operands[403])
	material_33.set_shader_parameter("flatness", operands[404])
	material_33.set_shader_parameter("inherit_emitter_velocity_ratio", operands[405])
	material_33.set_shader_parameter("initial_linear_velocity_min", operands[406])
	material_33.set_shader_parameter("initial_linear_velocity_max", operands[407])
	material_33.set_shader_parameter("directional_velocity_min", operands[408])
	material_33.set_shader_parameter("directional_velocity_max", operands[409])
	material_33.set_shader_parameter("angular_velocity_min", operands[410])
	material_33.set_shader_parameter("angular_velocity_max", operands[411])
	material_33.set_shader_parameter("orbit_velocity_min", operands[412])
	material_33.set_shader_parameter("orbit_velocity_max", operands[413])
	material_33.set_shader_parameter("radial_velocity_min", operands[414])
	material_33.set_shader_parameter("radial_velocity_max", operands[415])
	material_33.set_shader_parameter("linear_accel_min", operands[416])
	material_33.set_shader_parameter("linear_accel_max", operands[417])
	material_33.set_shader_parameter("radial_accel_min", operands[418])
	material_33.set_shader_parameter("radial_accel_max", operands[419])
	material_33.set_shader_parameter("tangent_accel_min", operands[420])
	material_33.set_shader_parameter("tangent_accel_max", operands[421])
	material_33.set_shader_parameter("damping_min", operands[422])
	material_33.set_shader_parameter("damping_max", operands[423])
	material_33.set_shader_parameter("initial_angle_min", operands[424])
	material_33.set_shader_parameter("initial_angle_max", operands[425])
	material_33.set_shader_parameter("scale_min", operands[426])
	material_33.set_shader_parameter("scale_max", operands[427])
	material_33.set_shader_parameter("hue_variation_min", operands[428])
	material_33.set_shader_parameter("hue_variation_max", operands[429])
	material_33.set_shader_parameter("anim_speed_min", operands[430])
	material_33.set_shader_parameter("anim_speed_max", operands[431])
	material_33.set_shader_parameter("anim_offset_min", operands[432])
	material_33.set_shader_parameter("anim_offset_max", operands[433])
	material_33.set_shader_parameter("lifetime_randomness", operands[434])
	material_33.set_shader_parameter("emission_shape_offset", operands[435])
	material_33.set_shader_parameter("emission_shape_scale", operands[436])
	material_33.set_shader_parameter("velocity_pivot", operands[437])
	material_33.set_shader_parameter("emission_sphere_radius", operands[438])
	material_33.set_shader_parameter("color_value", operands[439])
	material_33.set_shader_parameter("gravity", operands[440])
	material_33.set_shader_parameter("tangent_accel_texture", operands[441])
	material_33.set_shader_parameter("scale_curve", operands[442])
	material_33.set_shader_parameter("radial_velocity_curve", operands[443])
	material_33.set_shader_parameter("directional_velocity_curve", operands[444])
	material_33.set_meta("factory_prepared_shader", operands[445])
	material_33.set_meta("factory_clock_names", operands[446])
	material_33.set_meta("factory_opacity_prepared_shader", operands[447])
	material_33.set_meta("factory_native_process_source", operands[448])
	material_33.set_meta("factory_clock_pool_required", operands[449])
	material_33.set_meta("factory_world_space_uniform", operands[450])
	material_33.set_meta("factory_native_program_defaults", operands[451])
	var material_34 := ShaderMaterial.new()
	material_34.shader = operands[452]
	material_34.set_shader_parameter("factory_world_to_source", operands[453])
	material_34.set_shader_parameter("sprite", operands[454])
	material_34.set_shader_parameter("env", operands[455])
	material_34.set_meta("factory_prepared_shader", operands[456])
	material_34.set_meta("factory_opacity_prepared_shader", operands[457])
	material_34.set_meta("factory_world_space_uniform", operands[458])
	material_34.set_meta("factory_clock_pool_required", operands[459])
	material_34.set_meta("factory_native_program_defaults", operands[460])
	var material_35 := ShaderMaterial.new()
	material_35.shader = operands[461]
	material_35.set_shader_parameter("direction", operands[462])
	material_35.set_shader_parameter("spread", operands[463])
	material_35.set_shader_parameter("flatness", operands[464])
	material_35.set_shader_parameter("inherit_emitter_velocity_ratio", operands[465])
	material_35.set_shader_parameter("initial_linear_velocity_min", operands[466])
	material_35.set_shader_parameter("initial_linear_velocity_max", operands[467])
	material_35.set_shader_parameter("directional_velocity_min", operands[468])
	material_35.set_shader_parameter("directional_velocity_max", operands[469])
	material_35.set_shader_parameter("angular_velocity_min", operands[470])
	material_35.set_shader_parameter("angular_velocity_max", operands[471])
	material_35.set_shader_parameter("orbit_velocity_min", operands[472])
	material_35.set_shader_parameter("orbit_velocity_max", operands[473])
	material_35.set_shader_parameter("radial_velocity_min", operands[474])
	material_35.set_shader_parameter("radial_velocity_max", operands[475])
	material_35.set_shader_parameter("linear_accel_min", operands[476])
	material_35.set_shader_parameter("linear_accel_max", operands[477])
	material_35.set_shader_parameter("radial_accel_min", operands[478])
	material_35.set_shader_parameter("radial_accel_max", operands[479])
	material_35.set_shader_parameter("tangent_accel_min", operands[480])
	material_35.set_shader_parameter("tangent_accel_max", operands[481])
	material_35.set_shader_parameter("damping_min", operands[482])
	material_35.set_shader_parameter("damping_max", operands[483])
	material_35.set_shader_parameter("initial_angle_min", operands[484])
	material_35.set_shader_parameter("initial_angle_max", operands[485])
	material_35.set_shader_parameter("scale_min", operands[486])
	material_35.set_shader_parameter("scale_max", operands[487])
	material_35.set_shader_parameter("hue_variation_min", operands[488])
	material_35.set_shader_parameter("hue_variation_max", operands[489])
	material_35.set_shader_parameter("anim_speed_min", operands[490])
	material_35.set_shader_parameter("anim_speed_max", operands[491])
	material_35.set_shader_parameter("anim_offset_min", operands[492])
	material_35.set_shader_parameter("anim_offset_max", operands[493])
	material_35.set_shader_parameter("lifetime_randomness", operands[494])
	material_35.set_shader_parameter("emission_shape_offset", operands[495])
	material_35.set_shader_parameter("emission_shape_scale", operands[496])
	material_35.set_shader_parameter("velocity_pivot", operands[497])
	material_35.set_shader_parameter("color_value", operands[498])
	material_35.set_shader_parameter("gravity", operands[499])
	material_35.set_shader_parameter("alpha_curve", operands[500])
	material_35.set_shader_parameter("scale_curve", operands[501])
	material_35.set_meta("factory_prepared_shader", operands[502])
	material_35.set_meta("factory_clock_names", operands[503])
	material_35.set_meta("factory_opacity_prepared_shader", operands[504])
	material_35.set_meta("factory_native_process_source", operands[505])
	material_35.set_meta("factory_clock_pool_required", operands[506])
	material_35.set_meta("factory_world_space_uniform", operands[507])
	material_35.set_meta("factory_native_program_defaults", operands[508])
	var material_36 := ShaderMaterial.new()
	material_36.shader = operands[509]
	material_36.set_shader_parameter("vfx_package_clock_slot", operands[510])
	material_36.set_shader_parameter("delivery_clock", operands[511])
	material_36.set_shader_parameter("delivery_envelope", operands[512])
	material_36.set_shader_parameter("Fire_Scale", operands[513])
	material_36.set_shader_parameter("Fire_Speed", operands[514])
	material_36.set_shader_parameter("Fire_Texture", operands[515])
	material_36.set_shader_parameter("Gradient_Substract", operands[516])
	material_36.set_shader_parameter("Color_Dissipation", operands[517])
	material_36.set_shader_parameter("Color_1D_Gradient", operands[518])
	material_36.set_shader_parameter("Dissapear_Step", operands[519])
	material_36.set_shader_parameter("Proximity_Fade", operands[520])
	material_36.set_meta("factory_clock_names", operands[521])
	material_36.set_meta("factory_prepared_shader", operands[522])
	material_36.set_meta("factory_opacity_prepared_shader", operands[523])
	material_36.set_meta("factory_world_space_uniform", operands[524])
	material_36.set_meta("factory_clock_pool_required", operands[525])
	material_36.set_meta("factory_native_program_defaults", operands[526])
	var material_37 := ShaderMaterial.new()
	material_37.shader = operands[527]
	material_37.render_priority = -1
	material_37.set_shader_parameter("vfx_package_clock_slot", operands[528])
	material_37.set_shader_parameter("delivery_clock", operands[529])
	material_37.set_shader_parameter("delivery_envelope", operands[530])
	material_37.set_shader_parameter("Fire_Scale", operands[531])
	material_37.set_shader_parameter("Fire_Speed", operands[532])
	material_37.set_shader_parameter("Fire_Texture", operands[533])
	material_37.set_shader_parameter("Gradient_Substract", operands[534])
	material_37.set_shader_parameter("Color_Dissipation", operands[535])
	material_37.set_shader_parameter("Color_1D_Gradient", operands[536])
	material_37.set_shader_parameter("Dissapear_Step", operands[537])
	material_37.set_shader_parameter("Proximity_Fade", operands[538])
	material_37.set_meta("factory_clock_names", operands[539])
	material_37.set_meta("factory_prepared_shader", operands[540])
	material_37.set_meta("factory_opacity_prepared_shader", operands[541])
	material_37.set_meta("factory_world_space_uniform", operands[542])
	material_37.set_meta("factory_clock_pool_required", operands[543])
	material_37.set_meta("factory_native_program_defaults", operands[544])
	var material_38 := ShaderMaterial.new()
	material_38.shader = operands[545]
	material_38.set_shader_parameter("vfx_package_clock_slot", operands[546])
	material_38.set_shader_parameter("delivery_clock", operands[547])
	material_38.set_shader_parameter("delivery_envelope", operands[548])
	material_38.set_shader_parameter("Fire_Scale", operands[549])
	material_38.set_shader_parameter("Fire_Speed", operands[550])
	material_38.set_shader_parameter("Fire_Texture", operands[551])
	material_38.set_shader_parameter("Gradient_Substract", operands[552])
	material_38.set_shader_parameter("Color_Dissipation", operands[553])
	material_38.set_shader_parameter("Color_1D_Gradient", operands[554])
	material_38.set_shader_parameter("Dissapear_Step", operands[555])
	material_38.set_shader_parameter("Proximity_Fade", operands[556])
	material_38.set_meta("factory_clock_names", operands[557])
	material_38.set_meta("factory_prepared_shader", operands[558])
	material_38.set_meta("factory_opacity_prepared_shader", operands[559])
	material_38.set_meta("factory_world_space_uniform", operands[560])
	material_38.set_meta("factory_clock_pool_required", operands[561])
	material_38.set_meta("factory_native_program_defaults", operands[562])
	var material_39 := ShaderMaterial.new()
	material_39.shader = operands[563]
	material_39.set_shader_parameter("source_noise", operands[564])
	material_39.set_meta("factory_prepared_shader", operands[565])
	material_39.set_meta("factory_opacity_prepared_shader", operands[566])
	material_39.set_meta("factory_world_space_uniform", operands[567])
	material_39.set_meta("factory_clock_pool_required", operands[568])
	material_39.set_meta("factory_native_program_defaults", operands[569])
	var material_40: ShaderMaterial = material_39
	var material_41: ShaderMaterial = material_39
	var material_42: ShaderMaterial = material_39
	var material_43: ShaderMaterial = material_39
	var material_44: ShaderMaterial = material_39
	var material_45: ShaderMaterial = material_39
	var material_46: ShaderMaterial = material_39
	var material_47: ShaderMaterial = material_39
	var material_48: ShaderMaterial = material_39
	var material_49: ShaderMaterial = material_39
	var material_50: ShaderMaterial = material_39
	var material_51: ShaderMaterial = material_39
	var material_52: ShaderMaterial = material_39
	var material_53: ShaderMaterial = material_39
	var material_54: ShaderMaterial = material_39
	var material_55: ShaderMaterial = material_39
	var material_56: ShaderMaterial = material_39
	var material_57: ShaderMaterial = material_39
	var material_58: ShaderMaterial = material_39
	var material_59: ShaderMaterial = material_39
	var material_60: ShaderMaterial = material_39
	var material_61: ShaderMaterial = material_39
	var material_62: ShaderMaterial = material_39
	var material_63: ShaderMaterial = material_39
	var material_64: ShaderMaterial = material_39
	var material_65: ShaderMaterial = material_39
	var material_66: ShaderMaterial = material_39
	var material_67: ShaderMaterial = material_39
	var material_68: ShaderMaterial = material_39
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "assembly"
	var node_1 := Node3D.new()
	node_1.name = "effect"
	node_0.add_child(node_1)
	var node_2 := Node3D.new()
	node_2.name = "FactoryGenerated_0000_Node3D"
	node_2.transform = operands[773]
	node_1.add_child(node_2)
	var node_3 := Node3D.new()
	node_3.name = "Donor"
	node_2.add_child(node_3)
	var node_4 := Node3D.new()
	node_4.name = "SkeletalArm"
	node_4.transform = operands[774]
	node_3.add_child(node_4)
	var node_5 := Node3D.new()
	node_5.name = "SkeletalHandRig"
	node_4.add_child(node_5)
	var node_6 := Skeleton3D.new()
	node_6.name = "Skeleton3D"
	node_6.set("bones/0/name", operands[775])
	node_6.set("bones/0/parent", operands[776])
	node_6.set("bones/0/rest", operands[777])
	node_6.set("bones/0/enabled", operands[778])
	node_6.set("bones/0/position", operands[779])
	node_6.set("bones/0/rotation", operands[780])
	node_6.set("bones/0/scale", operands[781])
	node_6.set("bones/1/name", operands[782])
	node_6.set("bones/1/parent", operands[783])
	node_6.set("bones/1/rest", operands[784])
	node_6.set("bones/1/enabled", operands[785])
	node_6.set("bones/1/position", operands[786])
	node_6.set("bones/1/rotation", operands[787])
	node_6.set("bones/1/scale", operands[788])
	node_6.set("bones/2/name", operands[789])
	node_6.set("bones/2/parent", operands[790])
	node_6.set("bones/2/rest", operands[791])
	node_6.set("bones/2/enabled", operands[792])
	node_6.set("bones/2/position", operands[793])
	node_6.set("bones/2/rotation", operands[794])
	node_6.set("bones/2/scale", operands[795])
	node_6.set("bones/3/name", operands[796])
	node_6.set("bones/3/parent", operands[797])
	node_6.set("bones/3/rest", operands[798])
	node_6.set("bones/3/enabled", operands[799])
	node_6.set("bones/3/position", operands[800])
	node_6.set("bones/3/rotation", operands[801])
	node_6.set("bones/3/scale", operands[802])
	node_6.set("bones/4/name", operands[803])
	node_6.set("bones/4/parent", operands[804])
	node_6.set("bones/4/rest", operands[805])
	node_6.set("bones/4/enabled", operands[806])
	node_6.set("bones/4/position", operands[807])
	node_6.set("bones/4/rotation", operands[808])
	node_6.set("bones/4/scale", operands[809])
	node_6.set("bones/5/name", operands[810])
	node_6.set("bones/5/parent", operands[811])
	node_6.set("bones/5/rest", operands[812])
	node_6.set("bones/5/enabled", operands[813])
	node_6.set("bones/5/position", operands[814])
	node_6.set("bones/5/rotation", operands[815])
	node_6.set("bones/5/scale", operands[816])
	node_6.set("bones/6/name", operands[817])
	node_6.set("bones/6/parent", operands[818])
	node_6.set("bones/6/rest", operands[819])
	node_6.set("bones/6/enabled", operands[820])
	node_6.set("bones/6/position", operands[821])
	node_6.set("bones/6/rotation", operands[822])
	node_6.set("bones/6/scale", operands[823])
	node_6.set("bones/7/name", operands[824])
	node_6.set("bones/7/parent", operands[825])
	node_6.set("bones/7/rest", operands[826])
	node_6.set("bones/7/enabled", operands[827])
	node_6.set("bones/7/position", operands[828])
	node_6.set("bones/7/rotation", operands[829])
	node_6.set("bones/7/scale", operands[830])
	node_6.set("bones/8/name", operands[831])
	node_6.set("bones/8/parent", operands[832])
	node_6.set("bones/8/rest", operands[833])
	node_6.set("bones/8/enabled", operands[834])
	node_6.set("bones/8/position", operands[835])
	node_6.set("bones/8/rotation", operands[836])
	node_6.set("bones/8/scale", operands[837])
	node_6.set("bones/9/name", operands[838])
	node_6.set("bones/9/parent", operands[839])
	node_6.set("bones/9/rest", operands[840])
	node_6.set("bones/9/enabled", operands[841])
	node_6.set("bones/9/position", operands[842])
	node_6.set("bones/9/rotation", operands[843])
	node_6.set("bones/9/scale", operands[844])
	node_6.set("bones/10/name", operands[845])
	node_6.set("bones/10/parent", operands[846])
	node_6.set("bones/10/rest", operands[847])
	node_6.set("bones/10/enabled", operands[848])
	node_6.set("bones/10/position", operands[849])
	node_6.set("bones/10/rotation", operands[850])
	node_6.set("bones/10/scale", operands[851])
	node_6.set("bones/11/name", operands[852])
	node_6.set("bones/11/parent", operands[853])
	node_6.set("bones/11/rest", operands[854])
	node_6.set("bones/11/enabled", operands[855])
	node_6.set("bones/11/position", operands[856])
	node_6.set("bones/11/rotation", operands[857])
	node_6.set("bones/11/scale", operands[858])
	node_6.set("bones/12/name", operands[859])
	node_6.set("bones/12/parent", operands[860])
	node_6.set("bones/12/rest", operands[861])
	node_6.set("bones/12/enabled", operands[862])
	node_6.set("bones/12/position", operands[863])
	node_6.set("bones/12/rotation", operands[864])
	node_6.set("bones/12/scale", operands[865])
	node_6.set("bones/13/name", operands[866])
	node_6.set("bones/13/parent", operands[867])
	node_6.set("bones/13/rest", operands[868])
	node_6.set("bones/13/enabled", operands[869])
	node_6.set("bones/13/position", operands[870])
	node_6.set("bones/13/rotation", operands[871])
	node_6.set("bones/13/scale", operands[872])
	node_6.set("bones/14/name", operands[873])
	node_6.set("bones/14/parent", operands[874])
	node_6.set("bones/14/rest", operands[875])
	node_6.set("bones/14/enabled", operands[876])
	node_6.set("bones/14/position", operands[877])
	node_6.set("bones/14/rotation", operands[878])
	node_6.set("bones/14/scale", operands[879])
	node_6.set("bones/15/name", operands[880])
	node_6.set("bones/15/parent", operands[881])
	node_6.set("bones/15/rest", operands[882])
	node_6.set("bones/15/enabled", operands[883])
	node_6.set("bones/15/position", operands[884])
	node_6.set("bones/15/rotation", operands[885])
	node_6.set("bones/15/scale", operands[886])
	node_6.set("bones/16/name", operands[887])
	node_6.set("bones/16/parent", operands[888])
	node_6.set("bones/16/rest", operands[889])
	node_6.set("bones/16/enabled", operands[890])
	node_6.set("bones/16/position", operands[891])
	node_6.set("bones/16/rotation", operands[892])
	node_6.set("bones/16/scale", operands[893])
	node_6.set("bones/17/name", operands[894])
	node_6.set("bones/17/parent", operands[895])
	node_6.set("bones/17/rest", operands[896])
	node_6.set("bones/17/enabled", operands[897])
	node_6.set("bones/17/position", operands[898])
	node_6.set("bones/17/rotation", operands[899])
	node_6.set("bones/17/scale", operands[900])
	node_6.set("bones/18/name", operands[901])
	node_6.set("bones/18/parent", operands[902])
	node_6.set("bones/18/rest", operands[903])
	node_6.set("bones/18/enabled", operands[904])
	node_6.set("bones/18/position", operands[905])
	node_6.set("bones/18/rotation", operands[906])
	node_6.set("bones/18/scale", operands[907])
	node_6.set("bones/19/name", operands[908])
	node_6.set("bones/19/parent", operands[909])
	node_6.set("bones/19/rest", operands[910])
	node_6.set("bones/19/enabled", operands[911])
	node_6.set("bones/19/position", operands[912])
	node_6.set("bones/19/rotation", operands[913])
	node_6.set("bones/19/scale", operands[914])
	node_6.set("bones/20/name", operands[915])
	node_6.set("bones/20/parent", operands[916])
	node_6.set("bones/20/rest", operands[917])
	node_6.set("bones/20/enabled", operands[918])
	node_6.set("bones/20/position", operands[919])
	node_6.set("bones/20/rotation", operands[920])
	node_6.set("bones/20/scale", operands[921])
	node_5.add_child(node_6)
	var node_7 := BoneAttachment3D.new()
	node_7.name = "finger_1_2_2"
	node_7.transform = operands[922]
	node_7.bone_name = operands[923]
	node_7.bone_idx = operands[924]
	node_6.add_child(node_7)
	var node_8 := Node3D.new()
	node_8.name = "IndexEmissionSocket"
	node_8.transform = operands[925]
	node_7.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "Carpal_0"
	node_9.material_override = material_0
	node_9.mesh = operands[926]
	node_9.skin = operands[927]
	node_9.skeleton = operands[928]
	node_6.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "Carpal_1"
	node_10.material_override = material_1
	node_10.mesh = operands[929]
	node_10.skin = operands[930]
	node_10.skeleton = operands[931]
	node_6.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "Carpal_2"
	node_11.material_override = material_2
	node_11.mesh = operands[932]
	node_11.skin = operands[933]
	node_11.skeleton = operands[934]
	node_6.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "Carpal_3"
	node_12.material_override = material_3
	node_12.mesh = operands[935]
	node_12.skin = operands[936]
	node_12.skeleton = operands[937]
	node_6.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "Carpal_4"
	node_13.material_override = material_4
	node_13.mesh = operands[938]
	node_13.skin = operands[939]
	node_13.skeleton = operands[940]
	node_6.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "Carpal_5"
	node_14.material_override = material_5
	node_14.mesh = operands[941]
	node_14.skin = operands[942]
	node_14.skeleton = operands[943]
	node_6.add_child(node_14)
	var node_15 := MeshInstance3D.new()
	node_15.name = "Carpal_6"
	node_15.material_override = material_6
	node_15.mesh = operands[944]
	node_15.skin = operands[945]
	node_15.skeleton = operands[946]
	node_6.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "Carpal_7"
	node_16.material_override = material_7
	node_16.mesh = operands[947]
	node_16.skin = operands[948]
	node_16.skeleton = operands[949]
	node_6.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "finger_0_0"
	node_17.material_override = material_8
	node_17.mesh = operands[950]
	node_17.skin = operands[951]
	node_17.skeleton = operands[952]
	node_6.add_child(node_17)
	var node_18 := MeshInstance3D.new()
	node_18.name = "finger_0_1"
	node_18.material_override = material_9
	node_18.mesh = operands[953]
	node_18.skin = operands[954]
	node_18.skeleton = operands[955]
	node_6.add_child(node_18)
	var node_19 := MeshInstance3D.new()
	node_19.name = "finger_1_0"
	node_19.material_override = material_10
	node_19.mesh = operands[956]
	node_19.skin = operands[957]
	node_19.skeleton = operands[958]
	node_6.add_child(node_19)
	var node_20 := MeshInstance3D.new()
	node_20.name = "finger_1_1"
	node_20.material_override = material_11
	node_20.mesh = operands[959]
	node_20.skin = operands[960]
	node_20.skeleton = operands[961]
	node_6.add_child(node_20)
	var node_21 := MeshInstance3D.new()
	node_21.name = "finger_1_2"
	node_21.material_override = material_12
	node_21.mesh = operands[962]
	node_21.skin = operands[963]
	node_21.skeleton = operands[964]
	node_6.add_child(node_21)
	var node_22 := MeshInstance3D.new()
	node_22.name = "finger_2_0"
	node_22.material_override = material_13
	node_22.mesh = operands[965]
	node_22.skin = operands[966]
	node_22.skeleton = operands[967]
	node_6.add_child(node_22)
	var node_23 := MeshInstance3D.new()
	node_23.name = "finger_2_1"
	node_23.material_override = material_14
	node_23.mesh = operands[968]
	node_23.skin = operands[969]
	node_23.skeleton = operands[970]
	node_6.add_child(node_23)
	var node_24 := MeshInstance3D.new()
	node_24.name = "finger_2_2"
	node_24.material_override = material_15
	node_24.mesh = operands[971]
	node_24.skin = operands[972]
	node_24.skeleton = operands[973]
	node_6.add_child(node_24)
	var node_25 := MeshInstance3D.new()
	node_25.name = "finger_3_0"
	node_25.material_override = material_16
	node_25.mesh = operands[974]
	node_25.skin = operands[975]
	node_25.skeleton = operands[976]
	node_6.add_child(node_25)
	var node_26 := MeshInstance3D.new()
	node_26.name = "finger_3_1"
	node_26.material_override = material_17
	node_26.mesh = operands[977]
	node_26.skin = operands[978]
	node_26.skeleton = operands[979]
	node_6.add_child(node_26)
	var node_27 := MeshInstance3D.new()
	node_27.name = "finger_3_2"
	node_27.material_override = material_18
	node_27.mesh = operands[980]
	node_27.skin = operands[981]
	node_27.skeleton = operands[982]
	node_6.add_child(node_27)
	var node_28 := MeshInstance3D.new()
	node_28.name = "finger_4_0"
	node_28.material_override = material_19
	node_28.mesh = operands[983]
	node_28.skin = operands[984]
	node_28.skeleton = operands[985]
	node_6.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "finger_4_1"
	node_29.material_override = material_20
	node_29.mesh = operands[986]
	node_29.skin = operands[987]
	node_29.skeleton = operands[988]
	node_6.add_child(node_29)
	var node_30 := MeshInstance3D.new()
	node_30.name = "finger_4_2"
	node_30.material_override = material_21
	node_30.mesh = operands[989]
	node_30.skin = operands[990]
	node_30.skeleton = operands[991]
	node_6.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "forearm"
	node_31.material_override = material_22
	node_31.mesh = operands[992]
	node_31.skin = operands[993]
	node_31.skeleton = operands[994]
	node_6.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "forearm_001"
	node_32.material_override = material_23
	node_32.mesh = operands[995]
	node_32.skin = operands[996]
	node_32.skeleton = operands[997]
	node_6.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "metacarpal_0"
	node_33.material_override = material_24
	node_33.mesh = operands[998]
	node_33.skin = operands[999]
	node_33.skeleton = operands[1000]
	node_6.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "metacarpal_1"
	node_34.material_override = material_25
	node_34.mesh = operands[1001]
	node_34.skin = operands[1002]
	node_34.skeleton = operands[1003]
	node_6.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "metacarpal_2"
	node_35.material_override = material_26
	node_35.mesh = operands[1004]
	node_35.skin = operands[1005]
	node_35.skeleton = operands[1006]
	node_6.add_child(node_35)
	var node_36 := MeshInstance3D.new()
	node_36.name = "metacarpal_3"
	node_36.material_override = material_27
	node_36.mesh = operands[1007]
	node_36.skin = operands[1008]
	node_36.skeleton = operands[1009]
	node_6.add_child(node_36)
	var node_37 := MeshInstance3D.new()
	node_37.name = "metacarpal_4"
	node_37.material_override = material_28
	node_37.mesh = operands[1010]
	node_37.skin = operands[1011]
	node_37.skeleton = operands[1012]
	node_6.add_child(node_37)
	var node_38 := AnimationPlayer.new()
	node_38.name = "AnimationPlayer"
	node_38.callback_mode_process = operands[1013]
	node_38.set("libraries/", operands[1014])
	node_4.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "HandBirthPortal"
	node_39.transform = operands[1015]
	node_39.material_override = material_29
	node_39.mesh = operands[1016]
	node_3.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "FactoryGenerated_0002_MeshInstance3D"
	node_40.transform = operands[1017]
	node_40.material_override = material_30
	node_40.mesh = operands[1018]
	node_3.add_child(node_40)
	var node_41 := MeshInstance3D.new()
	node_41.name = "FactoryGenerated_0003_MeshInstance3D"
	node_41.transform = operands[1019]
	node_41.material_override = material_31
	node_41.mesh = operands[1020]
	node_3.add_child(node_41)
	var node_42 := GPUParticles3D.new()
	node_42.name = "sparkling_details2"
	node_42.transform = operands[1021]
	node_42.material_override = material_32
	node_42.cast_shadow = operands[1022]
	node_42.emitting = operands[1023]
	node_42.amount = operands[1024]
	node_42.lifetime = operands[1025]
	node_42.explosiveness = operands[1026]
	node_42.randomness = operands[1027]
	node_42.use_fixed_seed = operands[1028]
	node_42.seed = operands[1029]
	node_42.fixed_fps = operands[1030]
	node_42.local_coords = operands[1031]
	node_42.process_material = material_33
	node_42.draw_pass_1 = operands[1032]
	node_42.set("metadata/_edit_lock_", operands[1033])
	node_3.add_child(node_42)
	var node_43 := GPUParticles3D.new()
	node_43.name = "muzzle2start"
	node_43.transform = operands[1034]
	node_43.material_override = material_34
	node_43.cast_shadow = operands[1035]
	node_43.emitting = operands[1036]
	node_43.amount = operands[1037]
	node_43.lifetime = operands[1038]
	node_43.one_shot = operands[1039]
	node_43.explosiveness = operands[1040]
	node_43.use_fixed_seed = operands[1041]
	node_43.seed = operands[1042]
	node_43.fixed_fps = operands[1043]
	node_43.local_coords = operands[1044]
	node_43.process_material = material_35
	node_43.draw_pass_1 = operands[1045]
	node_43.set("metadata/_edit_lock_", operands[1046])
	node_3.add_child(node_43)
	var node_44 := DirectionalLight3D.new()
	node_44.name = "FactoryGenerated_0006_DirectionalLight3D"
	node_44.transform = operands[1047]
	node_44.light_energy = operands[1048]
	node_44.set("metadata/factory_light_role", operands[1049])
	node_3.add_child(node_44)
	var node_45 := Node3D.new()
	node_45.name = "VFX_DarknessProjectile"
	node_1.add_child(node_45)
	var node_46 := MeshInstance3D.new()
	node_46.name = "FBHead"
	node_46.transform = operands[1050]
	node_46.sorting_offset = operands[1051]
	node_46.material_override = material_36
	node_46.cast_shadow = operands[1052]
	node_46.mesh = operands[1053]
	node_46.skeleton = operands[1054]
	node_45.add_child(node_46)
	var node_47 := MeshInstance3D.new()
	node_47.name = "FBHead2inner"
	node_47.transform = operands[1055]
	node_47.sorting_offset = operands[1056]
	node_47.material_override = material_37
	node_47.cast_shadow = operands[1057]
	node_47.mesh = operands[1058]
	node_47.skeleton = operands[1059]
	node_45.add_child(node_47)
	var node_48 := MeshInstance3D.new()
	node_48.name = "FBHead3outside"
	node_48.transform = operands[1060]
	node_48.sorting_offset = operands[1061]
	node_48.material_override = material_38
	node_48.cast_shadow = operands[1062]
	node_48.mesh = operands[1063]
	node_48.skeleton = operands[1064]
	node_45.add_child(node_48)
	var node_49 := MeshInstance3D.new()
	node_49.name = "FactoryGenerated_0002_MeshInstance3D"
	node_49.material_override = material_39
	node_49.cast_shadow = operands[1065]
	node_49.mesh = operands[1066]
	node_1.add_child(node_49)
	var node_50 := MeshInstance3D.new()
	node_50.name = "FactoryGenerated_0003_MeshInstance3D"
	node_50.material_override = material_40
	node_50.cast_shadow = operands[1067]
	node_50.mesh = operands[1068]
	node_1.add_child(node_50)
	var node_51 := MeshInstance3D.new()
	node_51.name = "FactoryGenerated_0004_MeshInstance3D"
	node_51.material_override = material_41
	node_51.cast_shadow = operands[1069]
	node_51.mesh = operands[1070]
	node_1.add_child(node_51)
	var node_52 := MeshInstance3D.new()
	node_52.name = "FactoryGenerated_0005_MeshInstance3D"
	node_52.material_override = material_42
	node_52.cast_shadow = operands[1071]
	node_52.mesh = operands[1072]
	node_1.add_child(node_52)
	var node_53 := MeshInstance3D.new()
	node_53.name = "FactoryGenerated_0006_MeshInstance3D"
	node_53.material_override = material_43
	node_53.cast_shadow = operands[1073]
	node_53.mesh = operands[1074]
	node_1.add_child(node_53)
	var node_54 := MeshInstance3D.new()
	node_54.name = "FactoryGenerated_0007_MeshInstance3D"
	node_54.material_override = material_44
	node_54.cast_shadow = operands[1075]
	node_54.mesh = operands[1076]
	node_1.add_child(node_54)
	var node_55 := MeshInstance3D.new()
	node_55.name = "FactoryGenerated_0008_MeshInstance3D"
	node_55.material_override = material_45
	node_55.cast_shadow = operands[1077]
	node_55.mesh = operands[1078]
	node_1.add_child(node_55)
	var node_56 := MeshInstance3D.new()
	node_56.name = "FactoryGenerated_0009_MeshInstance3D"
	node_56.material_override = material_46
	node_56.cast_shadow = operands[1079]
	node_56.mesh = operands[1080]
	node_1.add_child(node_56)
	var node_57 := MeshInstance3D.new()
	node_57.name = "FactoryGenerated_0010_MeshInstance3D"
	node_57.material_override = material_47
	node_57.cast_shadow = operands[1081]
	node_57.mesh = operands[1082]
	node_1.add_child(node_57)
	var node_58 := MeshInstance3D.new()
	node_58.name = "FactoryGenerated_0011_MeshInstance3D"
	node_58.material_override = material_48
	node_58.cast_shadow = operands[1083]
	node_58.mesh = operands[1084]
	node_1.add_child(node_58)
	var node_59 := MeshInstance3D.new()
	node_59.name = "FactoryGenerated_0012_MeshInstance3D"
	node_59.material_override = material_49
	node_59.cast_shadow = operands[1085]
	node_59.mesh = operands[1086]
	node_1.add_child(node_59)
	var node_60 := MeshInstance3D.new()
	node_60.name = "FactoryGenerated_0013_MeshInstance3D"
	node_60.material_override = material_50
	node_60.cast_shadow = operands[1087]
	node_60.mesh = operands[1088]
	node_1.add_child(node_60)
	var node_61 := MeshInstance3D.new()
	node_61.name = "FactoryGenerated_0014_MeshInstance3D"
	node_61.material_override = material_51
	node_61.cast_shadow = operands[1089]
	node_61.mesh = operands[1090]
	node_1.add_child(node_61)
	var node_62 := MeshInstance3D.new()
	node_62.name = "FactoryGenerated_0015_MeshInstance3D"
	node_62.material_override = material_52
	node_62.cast_shadow = operands[1091]
	node_62.mesh = operands[1092]
	node_1.add_child(node_62)
	var node_63 := MeshInstance3D.new()
	node_63.name = "FactoryGenerated_0016_MeshInstance3D"
	node_63.material_override = material_53
	node_63.cast_shadow = operands[1093]
	node_63.mesh = operands[1094]
	node_1.add_child(node_63)
	var node_64 := MeshInstance3D.new()
	node_64.name = "FactoryGenerated_0017_MeshInstance3D"
	node_64.material_override = material_54
	node_64.cast_shadow = operands[1095]
	node_64.mesh = operands[1096]
	node_1.add_child(node_64)
	var node_65 := MeshInstance3D.new()
	node_65.name = "FactoryGenerated_0018_MeshInstance3D"
	node_65.material_override = material_55
	node_65.cast_shadow = operands[1097]
	node_65.mesh = operands[1098]
	node_1.add_child(node_65)
	var node_66 := MeshInstance3D.new()
	node_66.name = "FactoryGenerated_0019_MeshInstance3D"
	node_66.material_override = material_56
	node_66.cast_shadow = operands[1099]
	node_66.mesh = operands[1100]
	node_1.add_child(node_66)
	var node_67 := MeshInstance3D.new()
	node_67.name = "FactoryGenerated_0020_MeshInstance3D"
	node_67.material_override = material_57
	node_67.cast_shadow = operands[1101]
	node_67.mesh = operands[1102]
	node_1.add_child(node_67)
	var node_68 := MeshInstance3D.new()
	node_68.name = "FactoryGenerated_0021_MeshInstance3D"
	node_68.material_override = material_58
	node_68.cast_shadow = operands[1103]
	node_68.mesh = operands[1104]
	node_1.add_child(node_68)
	var node_69 := MeshInstance3D.new()
	node_69.name = "FactoryGenerated_0022_MeshInstance3D"
	node_69.material_override = material_59
	node_69.cast_shadow = operands[1105]
	node_69.mesh = operands[1106]
	node_1.add_child(node_69)
	var node_70 := MeshInstance3D.new()
	node_70.name = "FactoryGenerated_0023_MeshInstance3D"
	node_70.material_override = material_60
	node_70.cast_shadow = operands[1107]
	node_70.mesh = operands[1108]
	node_1.add_child(node_70)
	var node_71 := MeshInstance3D.new()
	node_71.name = "FactoryGenerated_0024_MeshInstance3D"
	node_71.material_override = material_61
	node_71.cast_shadow = operands[1109]
	node_71.mesh = operands[1110]
	node_1.add_child(node_71)
	var node_72 := MeshInstance3D.new()
	node_72.name = "FactoryGenerated_0025_MeshInstance3D"
	node_72.material_override = material_62
	node_72.cast_shadow = operands[1111]
	node_72.mesh = operands[1112]
	node_1.add_child(node_72)
	var node_73 := MeshInstance3D.new()
	node_73.name = "FactoryGenerated_0026_MeshInstance3D"
	node_73.material_override = material_63
	node_73.cast_shadow = operands[1113]
	node_73.mesh = operands[1114]
	node_1.add_child(node_73)
	var node_74 := MeshInstance3D.new()
	node_74.name = "FactoryGenerated_0027_MeshInstance3D"
	node_74.material_override = material_64
	node_74.cast_shadow = operands[1115]
	node_74.mesh = operands[1116]
	node_1.add_child(node_74)
	var node_75 := MeshInstance3D.new()
	node_75.name = "FactoryGenerated_0028_MeshInstance3D"
	node_75.material_override = material_65
	node_75.cast_shadow = operands[1117]
	node_75.mesh = operands[1118]
	node_1.add_child(node_75)
	var node_76 := MeshInstance3D.new()
	node_76.name = "FactoryGenerated_0029_MeshInstance3D"
	node_76.material_override = material_66
	node_76.cast_shadow = operands[1119]
	node_76.mesh = operands[1120]
	node_1.add_child(node_76)
	var node_77 := MeshInstance3D.new()
	node_77.name = "FactoryGenerated_0030_MeshInstance3D"
	node_77.material_override = material_67
	node_77.cast_shadow = operands[1121]
	node_77.mesh = operands[1122]
	node_1.add_child(node_77)
	var node_78 := MeshInstance3D.new()
	node_78.name = "FactoryGenerated_0031_MeshInstance3D"
	node_78.material_override = material_68
	node_78.cast_shadow = operands[1123]
	node_78.mesh = operands[1124]
	node_1.add_child(node_78)
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
	node_50.owner = node_0
	node_51.owner = node_0
	node_52.owner = node_0
	node_53.owner = node_0
	node_54.owner = node_0
	node_55.owner = node_0
	node_56.owner = node_0
	node_57.owner = node_0
	node_58.owner = node_0
	node_59.owner = node_0
	node_60.owner = node_0
	node_61.owner = node_0
	node_62.owner = node_0
	node_63.owner = node_0
	node_64.owner = node_0
	node_65.owner = node_0
	node_66.owner = node_0
	node_67.owner = node_0
	node_68.owner = node_0
	node_69.owner = node_0
	node_70.owner = node_0
	node_71.owner = node_0
	node_72.owner = node_0
	node_73.owner = node_0
	node_74.owner = node_0
	node_75.owner = node_0
	node_76.owner = node_0
	node_77.owner = node_0
	node_78.owner = node_0
	node_0.scene_file_path = operands[1125]
	return {"material_sites_bound": true, "nodes": [node_0, node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_41, node_42, node_43, node_44, node_45, node_46, node_47, node_48, node_49, node_50, node_51, node_52, node_53, node_54, node_55, node_56, node_57, node_58, node_59, node_60, node_61, node_62, node_63, node_64, node_65, node_66, node_67, node_68, node_69, node_70, node_71, node_72, node_73, node_74, node_75, node_76, node_77, node_78], "private_materials": [material_0, material_1, material_2, material_3, material_4, material_5, material_6, material_7, material_8, material_9, material_10, material_11, material_12, material_13, material_14, material_15, material_16, material_17, material_18, material_19, material_20, material_21, material_22, material_23, material_24, material_25, material_26, material_27, material_28, material_29, material_30, material_31, material_32, material_33, material_34, material_35, material_36, material_37, material_38, material_39, material_40, material_41, material_42, material_43, material_44, material_45, material_46, material_47, material_48, material_49, material_50, material_51, material_52, material_53, material_54, material_55, material_56, material_57, material_58, material_59, material_60, material_61, material_62, material_63, material_64, material_65, material_66, material_67, material_68], "root": node_0, "geometry": [node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_39, node_40, node_41, node_42, node_43, node_46, node_47, node_48, node_49, node_50, node_51, node_52, node_53, node_54, node_55, node_56, node_57, node_58, node_59, node_60, node_61, node_62, node_63, node_64, node_65, node_66, node_67, node_68, node_69, node_70, node_71, node_72, node_73, node_74, node_75, node_76, node_77, node_78], "materials": [], "cohorts": []}
