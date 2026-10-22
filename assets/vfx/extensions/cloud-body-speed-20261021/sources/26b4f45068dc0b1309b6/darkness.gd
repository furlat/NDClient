extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	var material_0 := ShaderMaterial.new()
	material_0.shader = operands[0]
	material_0.set_shader_parameter("cloud_carrier_feather_uv", operands[1])
	material_0.set_shader_parameter("mask1_texture", operands[2])
	material_0.set_shader_parameter("mask1_scroll", operands[3])
	material_0.set_shader_parameter("use_mask2", operands[4])
	material_0.set_shader_parameter("mask2_texture", operands[5])
	material_0.set_shader_parameter("mask2_scroll", operands[6])
	material_0.set_shader_parameter("mask2_strength", operands[7])
	material_0.set_shader_parameter("mask2_blend_mode", operands[8])
	material_0.set_shader_parameter("use_mask3", operands[9])
	material_0.set_shader_parameter("mask3_texture", operands[10])
	material_0.set_shader_parameter("mask3_strength", operands[11])
	material_0.set_shader_parameter("mask3_blend_mode", operands[12])
	material_0.set_shader_parameter("primary_color", operands[13])
	material_0.set_shader_parameter("secondary_color", operands[14])
	material_0.set_shader_parameter("tertiary_color", operands[15])
	material_0.set_shader_parameter("use_tertiary", operands[16])
	material_0.set_shader_parameter("color_smoothness", operands[17])
	material_0.set_shader_parameter("emission_strength", operands[18])
	material_0.set_shader_parameter("alpha_smoothness", operands[19])
	material_0.set_shader_parameter("alpha_multiplier", operands[20])
	material_0.set_shader_parameter("alpha_cutoff", operands[21])
	material_0.set_shader_parameter("cloud_kind", operands[22])
	material_0.set_shader_parameter("cloud_radius", operands[23])
	material_0.set_meta("factory_occurrence_alpha", operands[24])
	material_0.set_meta("factory_prepared_shader", operands[25])
	material_0.set_meta("factory_opacity_prepared_shader", operands[26])
	material_0.set_meta("factory_world_space_uniform", operands[27])
	material_0.set_meta("factory_clock_names", operands[28])
	var material_1: ShaderMaterial = operands[29]
	var material_2 := ShaderMaterial.new()
	material_2.shader = operands[30]
	material_2.set_shader_parameter("cloud_carrier_feather_uv", operands[31])
	material_2.set_shader_parameter("mask1_texture", operands[32])
	material_2.set_shader_parameter("mask1_scroll", operands[33])
	material_2.set_shader_parameter("mask1_scale", operands[34])
	material_2.set_shader_parameter("use_mask2", operands[35])
	material_2.set_shader_parameter("mask2_texture", operands[36])
	material_2.set_shader_parameter("mask2_scroll", operands[37])
	material_2.set_shader_parameter("mask2_strength", operands[38])
	material_2.set_shader_parameter("mask2_blend_mode", operands[39])
	material_2.set_shader_parameter("use_mask3", operands[40])
	material_2.set_shader_parameter("mask3_texture", operands[41])
	material_2.set_shader_parameter("mask3_strength", operands[42])
	material_2.set_shader_parameter("mask3_blend_mode", operands[43])
	material_2.set_shader_parameter("primary_color", operands[44])
	material_2.set_shader_parameter("secondary_color", operands[45])
	material_2.set_shader_parameter("tertiary_color", operands[46])
	material_2.set_shader_parameter("color_smoothness", operands[47])
	material_2.set_shader_parameter("emission_strength", operands[48])
	material_2.set_shader_parameter("alpha_smoothness", operands[49])
	material_2.set_shader_parameter("alpha_multiplier", operands[50])
	material_2.set_shader_parameter("alpha_cutoff", operands[51])
	material_2.set_shader_parameter("cloud_kind", operands[52])
	material_2.set_shader_parameter("cloud_radius", operands[53])
	material_2.set_meta("factory_occurrence_alpha", operands[54])
	material_2.set_meta("factory_prepared_shader", operands[55])
	material_2.set_meta("factory_opacity_prepared_shader", operands[56])
	material_2.set_meta("factory_world_space_uniform", operands[57])
	material_2.set_meta("factory_clock_names", operands[58])
	var material_3: ShaderMaterial = operands[59]
	var material_4 := ShaderMaterial.new()
	material_4.shader = operands[60]
	material_4.set_shader_parameter("fresnel_amount", operands[61])
	material_4.set_shader_parameter("fresnel_exponent", operands[62])
	material_4.set_shader_parameter("fresnel_gradient", operands[63])
	material_4.set_shader_parameter("enable_mask", operands[64])
	material_4.set_shader_parameter("mask_texture", operands[65])
	material_4.set_shader_parameter("mask_scroll", operands[66])
	material_4.set_shader_parameter("mask_blend_mode", operands[67])
	material_4.set_shader_parameter("mask_blend", operands[68])
	material_4.set_shader_parameter("primary_color", operands[69])
	material_4.set_shader_parameter("secondary_color", operands[70])
	material_4.set_shader_parameter("tertiary_color", operands[71])
	material_4.set_shader_parameter("alpha_multiplier", operands[72])
	material_4.set_shader_parameter("alpha_cutoff", operands[73])
	material_4.set_meta("factory_occurrence_alpha", operands[74])
	var material_5: ShaderMaterial = material_2
	var material_6: ShaderMaterial = operands[104]
	var material_7: ShaderMaterial = material_2
	var material_8: ShaderMaterial = operands[134]
	var material_9: ShaderMaterial = material_2
	var material_10: ShaderMaterial = operands[164]
	var material_11: ShaderMaterial = material_2
	var material_12: ShaderMaterial = operands[194]
	var material_13: ShaderMaterial = material_2
	var material_14: ShaderMaterial = operands[224]
	var material_15: ShaderMaterial = material_2
	var material_16: ShaderMaterial = operands[254]
	var material_17: ShaderMaterial = material_2
	var material_18: ShaderMaterial = operands[284]
	var material_19: ShaderMaterial = material_2
	var material_20: ShaderMaterial = operands[314]
	var material_21: ShaderMaterial = material_2
	var material_22: ShaderMaterial = operands[344]
	var material_23: ShaderMaterial = material_2
	var material_24: ShaderMaterial = operands[374]
	var material_25: ShaderMaterial = material_2
	var material_26: ShaderMaterial = operands[404]
	var material_27: ShaderMaterial = material_2
	var material_28: ShaderMaterial = operands[434]
	var material_29: ShaderMaterial = material_2
	var material_30: ShaderMaterial = operands[464]
	var material_31: ShaderMaterial = material_2
	var material_32: ShaderMaterial = operands[494]
	var material_33: ShaderMaterial = material_2
	var material_34: ShaderMaterial = operands[524]
	var material_35: ShaderMaterial = material_2
	var material_36: ShaderMaterial = operands[554]
	var material_37: ShaderMaterial = material_2
	var material_38: ShaderMaterial = operands[584]
	var material_39: ShaderMaterial = material_2
	var material_40: ShaderMaterial = operands[614]
	var material_41: ShaderMaterial = material_2
	var material_42: ShaderMaterial = operands[644]
	var material_43: ShaderMaterial = material_2
	var material_44: ShaderMaterial = operands[674]
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "Donor"
	var node_1 := GPUParticles3D.new()
	node_1.name = "Clouds_01"
	node_1.transform = operands[675]
	node_1.material_override = material_0
	node_1.amount = operands[676]
	node_1.lifetime = operands[677]
	node_1.one_shot = operands[678]
	node_1.preprocess = operands[679]
	node_1.use_fixed_seed = operands[680]
	node_1.seed = operands[681]
	node_1.fixed_fps = operands[682]
	node_1.visibility_aabb = operands[683]
	node_1.local_coords = operands[684]
	node_1.transform_align = operands[685]
	node_1.process_material = material_1
	node_1.draw_pass_1 = operands[686]
	node_0.add_child(node_1)
	var node_2 := GPUParticles3D.new()
	node_2.name = "Clouds_02"
	node_2.transform = operands[687]
	node_2.sorting_offset = operands[688]
	node_2.material_override = material_2
	node_2.amount = operands[689]
	node_2.lifetime = operands[690]
	node_2.one_shot = operands[691]
	node_2.preprocess = operands[692]
	node_2.use_fixed_seed = operands[693]
	node_2.seed = operands[694]
	node_2.fixed_fps = operands[695]
	node_2.visibility_aabb = operands[696]
	node_2.local_coords = operands[697]
	node_2.transform_align = operands[698]
	node_2.process_material = material_3
	node_2.draw_pass_1 = operands[699]
	node_0.add_child(node_2)
	var node_3 := MeshInstance3D.new()
	node_3.name = "Glow"
	node_3.visible = operands[700]
	node_3.sorting_offset = operands[701]
	node_3.material_override = material_4
	node_3.mesh = operands[702]
	node_0.add_child(node_3)
	var node_4 := AnimationPlayer.new()
	node_4.name = "AnimationPlayer"
	node_4.process_mode = operands[703]
	node_4.set("libraries/", operands[704])
	node_0.add_child(node_4)
	var node_5 := GPUParticles3D.new()
	node_5.name = "BoundaryBillow0"
	node_5.transform = operands[705]
	node_5.sorting_offset = operands[706]
	node_5.material_override = material_5
	node_5.amount = operands[707]
	node_5.lifetime = operands[708]
	node_5.one_shot = operands[709]
	node_5.preprocess = operands[710]
	node_5.use_fixed_seed = operands[711]
	node_5.seed = operands[712]
	node_5.fixed_fps = operands[713]
	node_5.visibility_aabb = operands[714]
	node_5.local_coords = operands[715]
	node_5.transform_align = operands[716]
	node_5.process_material = material_6
	node_5.draw_pass_1 = operands[717]
	node_0.add_child(node_5)
	var node_6 := GPUParticles3D.new()
	node_6.name = "BoundaryBillow1"
	node_6.transform = operands[718]
	node_6.sorting_offset = operands[719]
	node_6.material_override = material_7
	node_6.amount = operands[720]
	node_6.lifetime = operands[721]
	node_6.one_shot = operands[722]
	node_6.preprocess = operands[723]
	node_6.use_fixed_seed = operands[724]
	node_6.seed = operands[725]
	node_6.fixed_fps = operands[726]
	node_6.visibility_aabb = operands[727]
	node_6.local_coords = operands[728]
	node_6.transform_align = operands[729]
	node_6.process_material = material_8
	node_6.draw_pass_1 = operands[730]
	node_0.add_child(node_6)
	var node_7 := GPUParticles3D.new()
	node_7.name = "BoundaryBillow2"
	node_7.transform = operands[731]
	node_7.sorting_offset = operands[732]
	node_7.material_override = material_9
	node_7.amount = operands[733]
	node_7.lifetime = operands[734]
	node_7.one_shot = operands[735]
	node_7.preprocess = operands[736]
	node_7.use_fixed_seed = operands[737]
	node_7.seed = operands[738]
	node_7.fixed_fps = operands[739]
	node_7.visibility_aabb = operands[740]
	node_7.local_coords = operands[741]
	node_7.transform_align = operands[742]
	node_7.process_material = material_10
	node_7.draw_pass_1 = operands[743]
	node_0.add_child(node_7)
	var node_8 := GPUParticles3D.new()
	node_8.name = "BoundaryBillow3"
	node_8.transform = operands[744]
	node_8.sorting_offset = operands[745]
	node_8.material_override = material_11
	node_8.amount = operands[746]
	node_8.lifetime = operands[747]
	node_8.one_shot = operands[748]
	node_8.preprocess = operands[749]
	node_8.use_fixed_seed = operands[750]
	node_8.seed = operands[751]
	node_8.fixed_fps = operands[752]
	node_8.visibility_aabb = operands[753]
	node_8.local_coords = operands[754]
	node_8.transform_align = operands[755]
	node_8.process_material = material_12
	node_8.draw_pass_1 = operands[756]
	node_0.add_child(node_8)
	var node_9 := GPUParticles3D.new()
	node_9.name = "BoundaryBillow4"
	node_9.transform = operands[757]
	node_9.sorting_offset = operands[758]
	node_9.material_override = material_13
	node_9.amount = operands[759]
	node_9.lifetime = operands[760]
	node_9.one_shot = operands[761]
	node_9.preprocess = operands[762]
	node_9.use_fixed_seed = operands[763]
	node_9.seed = operands[764]
	node_9.fixed_fps = operands[765]
	node_9.visibility_aabb = operands[766]
	node_9.local_coords = operands[767]
	node_9.transform_align = operands[768]
	node_9.process_material = material_14
	node_9.draw_pass_1 = operands[769]
	node_0.add_child(node_9)
	var node_10 := GPUParticles3D.new()
	node_10.name = "BoundaryBillow5"
	node_10.transform = operands[770]
	node_10.sorting_offset = operands[771]
	node_10.material_override = material_15
	node_10.amount = operands[772]
	node_10.lifetime = operands[773]
	node_10.one_shot = operands[774]
	node_10.preprocess = operands[775]
	node_10.use_fixed_seed = operands[776]
	node_10.seed = operands[777]
	node_10.fixed_fps = operands[778]
	node_10.visibility_aabb = operands[779]
	node_10.local_coords = operands[780]
	node_10.transform_align = operands[781]
	node_10.process_material = material_16
	node_10.draw_pass_1 = operands[782]
	node_0.add_child(node_10)
	var node_11 := GPUParticles3D.new()
	node_11.name = "BoundaryBillow6"
	node_11.transform = operands[783]
	node_11.sorting_offset = operands[784]
	node_11.material_override = material_17
	node_11.amount = operands[785]
	node_11.lifetime = operands[786]
	node_11.one_shot = operands[787]
	node_11.preprocess = operands[788]
	node_11.use_fixed_seed = operands[789]
	node_11.seed = operands[790]
	node_11.fixed_fps = operands[791]
	node_11.visibility_aabb = operands[792]
	node_11.local_coords = operands[793]
	node_11.transform_align = operands[794]
	node_11.process_material = material_18
	node_11.draw_pass_1 = operands[795]
	node_0.add_child(node_11)
	var node_12 := GPUParticles3D.new()
	node_12.name = "BoundaryBillow7"
	node_12.transform = operands[796]
	node_12.sorting_offset = operands[797]
	node_12.material_override = material_19
	node_12.amount = operands[798]
	node_12.lifetime = operands[799]
	node_12.one_shot = operands[800]
	node_12.preprocess = operands[801]
	node_12.use_fixed_seed = operands[802]
	node_12.seed = operands[803]
	node_12.fixed_fps = operands[804]
	node_12.visibility_aabb = operands[805]
	node_12.local_coords = operands[806]
	node_12.transform_align = operands[807]
	node_12.process_material = material_20
	node_12.draw_pass_1 = operands[808]
	node_0.add_child(node_12)
	var node_13 := GPUParticles3D.new()
	node_13.name = "BoundaryBillow8"
	node_13.transform = operands[809]
	node_13.sorting_offset = operands[810]
	node_13.material_override = material_21
	node_13.amount = operands[811]
	node_13.lifetime = operands[812]
	node_13.one_shot = operands[813]
	node_13.preprocess = operands[814]
	node_13.use_fixed_seed = operands[815]
	node_13.seed = operands[816]
	node_13.fixed_fps = operands[817]
	node_13.visibility_aabb = operands[818]
	node_13.local_coords = operands[819]
	node_13.transform_align = operands[820]
	node_13.process_material = material_22
	node_13.draw_pass_1 = operands[821]
	node_0.add_child(node_13)
	var node_14 := GPUParticles3D.new()
	node_14.name = "BoundaryBillow9"
	node_14.transform = operands[822]
	node_14.sorting_offset = operands[823]
	node_14.material_override = material_23
	node_14.amount = operands[824]
	node_14.lifetime = operands[825]
	node_14.one_shot = operands[826]
	node_14.preprocess = operands[827]
	node_14.use_fixed_seed = operands[828]
	node_14.seed = operands[829]
	node_14.fixed_fps = operands[830]
	node_14.visibility_aabb = operands[831]
	node_14.local_coords = operands[832]
	node_14.transform_align = operands[833]
	node_14.process_material = material_24
	node_14.draw_pass_1 = operands[834]
	node_0.add_child(node_14)
	var node_15 := GPUParticles3D.new()
	node_15.name = "BoundaryBillow10"
	node_15.transform = operands[835]
	node_15.sorting_offset = operands[836]
	node_15.material_override = material_25
	node_15.amount = operands[837]
	node_15.lifetime = operands[838]
	node_15.one_shot = operands[839]
	node_15.preprocess = operands[840]
	node_15.use_fixed_seed = operands[841]
	node_15.seed = operands[842]
	node_15.fixed_fps = operands[843]
	node_15.visibility_aabb = operands[844]
	node_15.local_coords = operands[845]
	node_15.transform_align = operands[846]
	node_15.process_material = material_26
	node_15.draw_pass_1 = operands[847]
	node_0.add_child(node_15)
	var node_16 := GPUParticles3D.new()
	node_16.name = "BoundaryBillow11"
	node_16.transform = operands[848]
	node_16.sorting_offset = operands[849]
	node_16.material_override = material_27
	node_16.amount = operands[850]
	node_16.lifetime = operands[851]
	node_16.one_shot = operands[852]
	node_16.preprocess = operands[853]
	node_16.use_fixed_seed = operands[854]
	node_16.seed = operands[855]
	node_16.fixed_fps = operands[856]
	node_16.visibility_aabb = operands[857]
	node_16.local_coords = operands[858]
	node_16.transform_align = operands[859]
	node_16.process_material = material_28
	node_16.draw_pass_1 = operands[860]
	node_0.add_child(node_16)
	var node_17 := GPUParticles3D.new()
	node_17.name = "BoundaryBillow12"
	node_17.transform = operands[861]
	node_17.sorting_offset = operands[862]
	node_17.material_override = material_29
	node_17.amount = operands[863]
	node_17.lifetime = operands[864]
	node_17.one_shot = operands[865]
	node_17.preprocess = operands[866]
	node_17.use_fixed_seed = operands[867]
	node_17.seed = operands[868]
	node_17.fixed_fps = operands[869]
	node_17.visibility_aabb = operands[870]
	node_17.local_coords = operands[871]
	node_17.transform_align = operands[872]
	node_17.process_material = material_30
	node_17.draw_pass_1 = operands[873]
	node_0.add_child(node_17)
	var node_18 := GPUParticles3D.new()
	node_18.name = "BoundaryBillow13"
	node_18.transform = operands[874]
	node_18.sorting_offset = operands[875]
	node_18.material_override = material_31
	node_18.amount = operands[876]
	node_18.lifetime = operands[877]
	node_18.one_shot = operands[878]
	node_18.preprocess = operands[879]
	node_18.use_fixed_seed = operands[880]
	node_18.seed = operands[881]
	node_18.fixed_fps = operands[882]
	node_18.visibility_aabb = operands[883]
	node_18.local_coords = operands[884]
	node_18.transform_align = operands[885]
	node_18.process_material = material_32
	node_18.draw_pass_1 = operands[886]
	node_0.add_child(node_18)
	var node_19 := GPUParticles3D.new()
	node_19.name = "BoundaryBillow14"
	node_19.transform = operands[887]
	node_19.sorting_offset = operands[888]
	node_19.material_override = material_33
	node_19.amount = operands[889]
	node_19.lifetime = operands[890]
	node_19.one_shot = operands[891]
	node_19.preprocess = operands[892]
	node_19.use_fixed_seed = operands[893]
	node_19.seed = operands[894]
	node_19.fixed_fps = operands[895]
	node_19.visibility_aabb = operands[896]
	node_19.local_coords = operands[897]
	node_19.transform_align = operands[898]
	node_19.process_material = material_34
	node_19.draw_pass_1 = operands[899]
	node_0.add_child(node_19)
	var node_20 := GPUParticles3D.new()
	node_20.name = "BoundaryBillow15"
	node_20.transform = operands[900]
	node_20.sorting_offset = operands[901]
	node_20.material_override = material_35
	node_20.amount = operands[902]
	node_20.lifetime = operands[903]
	node_20.one_shot = operands[904]
	node_20.preprocess = operands[905]
	node_20.use_fixed_seed = operands[906]
	node_20.seed = operands[907]
	node_20.fixed_fps = operands[908]
	node_20.visibility_aabb = operands[909]
	node_20.local_coords = operands[910]
	node_20.transform_align = operands[911]
	node_20.process_material = material_36
	node_20.draw_pass_1 = operands[912]
	node_0.add_child(node_20)
	var node_21 := GPUParticles3D.new()
	node_21.name = "BoundaryBillow16"
	node_21.transform = operands[913]
	node_21.sorting_offset = operands[914]
	node_21.material_override = material_37
	node_21.amount = operands[915]
	node_21.lifetime = operands[916]
	node_21.one_shot = operands[917]
	node_21.preprocess = operands[918]
	node_21.use_fixed_seed = operands[919]
	node_21.seed = operands[920]
	node_21.fixed_fps = operands[921]
	node_21.visibility_aabb = operands[922]
	node_21.local_coords = operands[923]
	node_21.transform_align = operands[924]
	node_21.process_material = material_38
	node_21.draw_pass_1 = operands[925]
	node_0.add_child(node_21)
	var node_22 := GPUParticles3D.new()
	node_22.name = "BoundaryBillow17"
	node_22.transform = operands[926]
	node_22.sorting_offset = operands[927]
	node_22.material_override = material_39
	node_22.amount = operands[928]
	node_22.lifetime = operands[929]
	node_22.one_shot = operands[930]
	node_22.preprocess = operands[931]
	node_22.use_fixed_seed = operands[932]
	node_22.seed = operands[933]
	node_22.fixed_fps = operands[934]
	node_22.visibility_aabb = operands[935]
	node_22.local_coords = operands[936]
	node_22.transform_align = operands[937]
	node_22.process_material = material_40
	node_22.draw_pass_1 = operands[938]
	node_0.add_child(node_22)
	var node_23 := GPUParticles3D.new()
	node_23.name = "BoundaryBillow18"
	node_23.transform = operands[939]
	node_23.sorting_offset = operands[940]
	node_23.material_override = material_41
	node_23.amount = operands[941]
	node_23.lifetime = operands[942]
	node_23.one_shot = operands[943]
	node_23.preprocess = operands[944]
	node_23.use_fixed_seed = operands[945]
	node_23.seed = operands[946]
	node_23.fixed_fps = operands[947]
	node_23.visibility_aabb = operands[948]
	node_23.local_coords = operands[949]
	node_23.transform_align = operands[950]
	node_23.process_material = material_42
	node_23.draw_pass_1 = operands[951]
	node_0.add_child(node_23)
	var node_24 := GPUParticles3D.new()
	node_24.name = "BoundaryBillow19"
	node_24.transform = operands[952]
	node_24.sorting_offset = operands[953]
	node_24.material_override = material_43
	node_24.amount = operands[954]
	node_24.lifetime = operands[955]
	node_24.one_shot = operands[956]
	node_24.preprocess = operands[957]
	node_24.use_fixed_seed = operands[958]
	node_24.seed = operands[959]
	node_24.fixed_fps = operands[960]
	node_24.visibility_aabb = operands[961]
	node_24.local_coords = operands[962]
	node_24.transform_align = operands[963]
	node_24.process_material = material_44
	node_24.draw_pass_1 = operands[964]
	node_0.add_child(node_24)
	var node_25 := GPUParticles3D.new()
	node_25.name = "Clouds_01_next_cohort"
	node_25.transform = operands[965]
	node_25.sorting_offset = operands[966]
	node_25.material_override = material_0
	node_25.emitting = operands[967]
	node_25.amount = operands[968]
	node_25.lifetime = operands[969]
	node_25.one_shot = operands[970]
	node_25.use_fixed_seed = operands[971]
	node_25.seed = operands[972]
	node_25.fixed_fps = operands[973]
	node_25.visibility_aabb = operands[974]
	node_25.local_coords = operands[975]
	node_25.transform_align = operands[976]
	node_25.process_material = material_1
	node_25.draw_pass_1 = operands[977]
	node_0.add_child(node_25)
	var node_26 := GPUParticles3D.new()
	node_26.name = "Clouds_02_next_cohort"
	node_26.transform = operands[978]
	node_26.sorting_offset = operands[979]
	node_26.material_override = material_2
	node_26.emitting = operands[980]
	node_26.amount = operands[981]
	node_26.lifetime = operands[982]
	node_26.one_shot = operands[983]
	node_26.use_fixed_seed = operands[984]
	node_26.seed = operands[985]
	node_26.fixed_fps = operands[986]
	node_26.visibility_aabb = operands[987]
	node_26.local_coords = operands[988]
	node_26.transform_align = operands[989]
	node_26.process_material = material_3
	node_26.draw_pass_1 = operands[990]
	node_0.add_child(node_26)
	var node_27 := GPUParticles3D.new()
	node_27.name = "BoundaryBillow0_next_cohort"
	node_27.transform = operands[991]
	node_27.sorting_offset = operands[992]
	node_27.material_override = material_5
	node_27.emitting = operands[993]
	node_27.amount = operands[994]
	node_27.lifetime = operands[995]
	node_27.one_shot = operands[996]
	node_27.use_fixed_seed = operands[997]
	node_27.seed = operands[998]
	node_27.fixed_fps = operands[999]
	node_27.visibility_aabb = operands[1000]
	node_27.local_coords = operands[1001]
	node_27.transform_align = operands[1002]
	node_27.process_material = material_6
	node_27.draw_pass_1 = operands[1003]
	node_0.add_child(node_27)
	var node_28 := GPUParticles3D.new()
	node_28.name = "BoundaryBillow1_next_cohort"
	node_28.transform = operands[1004]
	node_28.sorting_offset = operands[1005]
	node_28.material_override = material_7
	node_28.emitting = operands[1006]
	node_28.amount = operands[1007]
	node_28.lifetime = operands[1008]
	node_28.one_shot = operands[1009]
	node_28.use_fixed_seed = operands[1010]
	node_28.seed = operands[1011]
	node_28.fixed_fps = operands[1012]
	node_28.visibility_aabb = operands[1013]
	node_28.local_coords = operands[1014]
	node_28.transform_align = operands[1015]
	node_28.process_material = material_8
	node_28.draw_pass_1 = operands[1016]
	node_0.add_child(node_28)
	var node_29 := GPUParticles3D.new()
	node_29.name = "BoundaryBillow2_next_cohort"
	node_29.transform = operands[1017]
	node_29.sorting_offset = operands[1018]
	node_29.material_override = material_9
	node_29.emitting = operands[1019]
	node_29.amount = operands[1020]
	node_29.lifetime = operands[1021]
	node_29.one_shot = operands[1022]
	node_29.use_fixed_seed = operands[1023]
	node_29.seed = operands[1024]
	node_29.fixed_fps = operands[1025]
	node_29.visibility_aabb = operands[1026]
	node_29.local_coords = operands[1027]
	node_29.transform_align = operands[1028]
	node_29.process_material = material_10
	node_29.draw_pass_1 = operands[1029]
	node_0.add_child(node_29)
	var node_30 := GPUParticles3D.new()
	node_30.name = "BoundaryBillow3_next_cohort"
	node_30.transform = operands[1030]
	node_30.sorting_offset = operands[1031]
	node_30.material_override = material_11
	node_30.emitting = operands[1032]
	node_30.amount = operands[1033]
	node_30.lifetime = operands[1034]
	node_30.one_shot = operands[1035]
	node_30.use_fixed_seed = operands[1036]
	node_30.seed = operands[1037]
	node_30.fixed_fps = operands[1038]
	node_30.visibility_aabb = operands[1039]
	node_30.local_coords = operands[1040]
	node_30.transform_align = operands[1041]
	node_30.process_material = material_12
	node_30.draw_pass_1 = operands[1042]
	node_0.add_child(node_30)
	var node_31 := GPUParticles3D.new()
	node_31.name = "BoundaryBillow4_next_cohort"
	node_31.transform = operands[1043]
	node_31.sorting_offset = operands[1044]
	node_31.material_override = material_13
	node_31.emitting = operands[1045]
	node_31.amount = operands[1046]
	node_31.lifetime = operands[1047]
	node_31.one_shot = operands[1048]
	node_31.use_fixed_seed = operands[1049]
	node_31.seed = operands[1050]
	node_31.fixed_fps = operands[1051]
	node_31.visibility_aabb = operands[1052]
	node_31.local_coords = operands[1053]
	node_31.transform_align = operands[1054]
	node_31.process_material = material_14
	node_31.draw_pass_1 = operands[1055]
	node_0.add_child(node_31)
	var node_32 := GPUParticles3D.new()
	node_32.name = "BoundaryBillow5_next_cohort"
	node_32.transform = operands[1056]
	node_32.sorting_offset = operands[1057]
	node_32.material_override = material_15
	node_32.emitting = operands[1058]
	node_32.amount = operands[1059]
	node_32.lifetime = operands[1060]
	node_32.one_shot = operands[1061]
	node_32.use_fixed_seed = operands[1062]
	node_32.seed = operands[1063]
	node_32.fixed_fps = operands[1064]
	node_32.visibility_aabb = operands[1065]
	node_32.local_coords = operands[1066]
	node_32.transform_align = operands[1067]
	node_32.process_material = material_16
	node_32.draw_pass_1 = operands[1068]
	node_0.add_child(node_32)
	var node_33 := GPUParticles3D.new()
	node_33.name = "BoundaryBillow6_next_cohort"
	node_33.transform = operands[1069]
	node_33.sorting_offset = operands[1070]
	node_33.material_override = material_17
	node_33.emitting = operands[1071]
	node_33.amount = operands[1072]
	node_33.lifetime = operands[1073]
	node_33.one_shot = operands[1074]
	node_33.use_fixed_seed = operands[1075]
	node_33.seed = operands[1076]
	node_33.fixed_fps = operands[1077]
	node_33.visibility_aabb = operands[1078]
	node_33.local_coords = operands[1079]
	node_33.transform_align = operands[1080]
	node_33.process_material = material_18
	node_33.draw_pass_1 = operands[1081]
	node_0.add_child(node_33)
	var node_34 := GPUParticles3D.new()
	node_34.name = "BoundaryBillow7_next_cohort"
	node_34.transform = operands[1082]
	node_34.sorting_offset = operands[1083]
	node_34.material_override = material_19
	node_34.emitting = operands[1084]
	node_34.amount = operands[1085]
	node_34.lifetime = operands[1086]
	node_34.one_shot = operands[1087]
	node_34.use_fixed_seed = operands[1088]
	node_34.seed = operands[1089]
	node_34.fixed_fps = operands[1090]
	node_34.visibility_aabb = operands[1091]
	node_34.local_coords = operands[1092]
	node_34.transform_align = operands[1093]
	node_34.process_material = material_20
	node_34.draw_pass_1 = operands[1094]
	node_0.add_child(node_34)
	var node_35 := GPUParticles3D.new()
	node_35.name = "BoundaryBillow8_next_cohort"
	node_35.transform = operands[1095]
	node_35.sorting_offset = operands[1096]
	node_35.material_override = material_21
	node_35.emitting = operands[1097]
	node_35.amount = operands[1098]
	node_35.lifetime = operands[1099]
	node_35.one_shot = operands[1100]
	node_35.use_fixed_seed = operands[1101]
	node_35.seed = operands[1102]
	node_35.fixed_fps = operands[1103]
	node_35.visibility_aabb = operands[1104]
	node_35.local_coords = operands[1105]
	node_35.transform_align = operands[1106]
	node_35.process_material = material_22
	node_35.draw_pass_1 = operands[1107]
	node_0.add_child(node_35)
	var node_36 := GPUParticles3D.new()
	node_36.name = "BoundaryBillow9_next_cohort"
	node_36.transform = operands[1108]
	node_36.sorting_offset = operands[1109]
	node_36.material_override = material_23
	node_36.emitting = operands[1110]
	node_36.amount = operands[1111]
	node_36.lifetime = operands[1112]
	node_36.one_shot = operands[1113]
	node_36.use_fixed_seed = operands[1114]
	node_36.seed = operands[1115]
	node_36.fixed_fps = operands[1116]
	node_36.visibility_aabb = operands[1117]
	node_36.local_coords = operands[1118]
	node_36.transform_align = operands[1119]
	node_36.process_material = material_24
	node_36.draw_pass_1 = operands[1120]
	node_0.add_child(node_36)
	var node_37 := GPUParticles3D.new()
	node_37.name = "BoundaryBillow10_next_cohort"
	node_37.transform = operands[1121]
	node_37.sorting_offset = operands[1122]
	node_37.material_override = material_25
	node_37.emitting = operands[1123]
	node_37.amount = operands[1124]
	node_37.lifetime = operands[1125]
	node_37.one_shot = operands[1126]
	node_37.use_fixed_seed = operands[1127]
	node_37.seed = operands[1128]
	node_37.fixed_fps = operands[1129]
	node_37.visibility_aabb = operands[1130]
	node_37.local_coords = operands[1131]
	node_37.transform_align = operands[1132]
	node_37.process_material = material_26
	node_37.draw_pass_1 = operands[1133]
	node_0.add_child(node_37)
	var node_38 := GPUParticles3D.new()
	node_38.name = "BoundaryBillow11_next_cohort"
	node_38.transform = operands[1134]
	node_38.sorting_offset = operands[1135]
	node_38.material_override = material_27
	node_38.emitting = operands[1136]
	node_38.amount = operands[1137]
	node_38.lifetime = operands[1138]
	node_38.one_shot = operands[1139]
	node_38.use_fixed_seed = operands[1140]
	node_38.seed = operands[1141]
	node_38.fixed_fps = operands[1142]
	node_38.visibility_aabb = operands[1143]
	node_38.local_coords = operands[1144]
	node_38.transform_align = operands[1145]
	node_38.process_material = material_28
	node_38.draw_pass_1 = operands[1146]
	node_0.add_child(node_38)
	var node_39 := GPUParticles3D.new()
	node_39.name = "BoundaryBillow12_next_cohort"
	node_39.transform = operands[1147]
	node_39.sorting_offset = operands[1148]
	node_39.material_override = material_29
	node_39.emitting = operands[1149]
	node_39.amount = operands[1150]
	node_39.lifetime = operands[1151]
	node_39.one_shot = operands[1152]
	node_39.use_fixed_seed = operands[1153]
	node_39.seed = operands[1154]
	node_39.fixed_fps = operands[1155]
	node_39.visibility_aabb = operands[1156]
	node_39.local_coords = operands[1157]
	node_39.transform_align = operands[1158]
	node_39.process_material = material_30
	node_39.draw_pass_1 = operands[1159]
	node_0.add_child(node_39)
	var node_40 := GPUParticles3D.new()
	node_40.name = "BoundaryBillow13_next_cohort"
	node_40.transform = operands[1160]
	node_40.sorting_offset = operands[1161]
	node_40.material_override = material_31
	node_40.emitting = operands[1162]
	node_40.amount = operands[1163]
	node_40.lifetime = operands[1164]
	node_40.one_shot = operands[1165]
	node_40.use_fixed_seed = operands[1166]
	node_40.seed = operands[1167]
	node_40.fixed_fps = operands[1168]
	node_40.visibility_aabb = operands[1169]
	node_40.local_coords = operands[1170]
	node_40.transform_align = operands[1171]
	node_40.process_material = material_32
	node_40.draw_pass_1 = operands[1172]
	node_0.add_child(node_40)
	var node_41 := GPUParticles3D.new()
	node_41.name = "BoundaryBillow14_next_cohort"
	node_41.transform = operands[1173]
	node_41.sorting_offset = operands[1174]
	node_41.material_override = material_33
	node_41.emitting = operands[1175]
	node_41.amount = operands[1176]
	node_41.lifetime = operands[1177]
	node_41.one_shot = operands[1178]
	node_41.use_fixed_seed = operands[1179]
	node_41.seed = operands[1180]
	node_41.fixed_fps = operands[1181]
	node_41.visibility_aabb = operands[1182]
	node_41.local_coords = operands[1183]
	node_41.transform_align = operands[1184]
	node_41.process_material = material_34
	node_41.draw_pass_1 = operands[1185]
	node_0.add_child(node_41)
	var node_42 := GPUParticles3D.new()
	node_42.name = "BoundaryBillow15_next_cohort"
	node_42.transform = operands[1186]
	node_42.sorting_offset = operands[1187]
	node_42.material_override = material_35
	node_42.emitting = operands[1188]
	node_42.amount = operands[1189]
	node_42.lifetime = operands[1190]
	node_42.one_shot = operands[1191]
	node_42.use_fixed_seed = operands[1192]
	node_42.seed = operands[1193]
	node_42.fixed_fps = operands[1194]
	node_42.visibility_aabb = operands[1195]
	node_42.local_coords = operands[1196]
	node_42.transform_align = operands[1197]
	node_42.process_material = material_36
	node_42.draw_pass_1 = operands[1198]
	node_0.add_child(node_42)
	var node_43 := GPUParticles3D.new()
	node_43.name = "BoundaryBillow16_next_cohort"
	node_43.transform = operands[1199]
	node_43.sorting_offset = operands[1200]
	node_43.material_override = material_37
	node_43.emitting = operands[1201]
	node_43.amount = operands[1202]
	node_43.lifetime = operands[1203]
	node_43.one_shot = operands[1204]
	node_43.use_fixed_seed = operands[1205]
	node_43.seed = operands[1206]
	node_43.fixed_fps = operands[1207]
	node_43.visibility_aabb = operands[1208]
	node_43.local_coords = operands[1209]
	node_43.transform_align = operands[1210]
	node_43.process_material = material_38
	node_43.draw_pass_1 = operands[1211]
	node_0.add_child(node_43)
	var node_44 := GPUParticles3D.new()
	node_44.name = "BoundaryBillow17_next_cohort"
	node_44.transform = operands[1212]
	node_44.sorting_offset = operands[1213]
	node_44.material_override = material_39
	node_44.emitting = operands[1214]
	node_44.amount = operands[1215]
	node_44.lifetime = operands[1216]
	node_44.one_shot = operands[1217]
	node_44.use_fixed_seed = operands[1218]
	node_44.seed = operands[1219]
	node_44.fixed_fps = operands[1220]
	node_44.visibility_aabb = operands[1221]
	node_44.local_coords = operands[1222]
	node_44.transform_align = operands[1223]
	node_44.process_material = material_40
	node_44.draw_pass_1 = operands[1224]
	node_0.add_child(node_44)
	var node_45 := GPUParticles3D.new()
	node_45.name = "BoundaryBillow18_next_cohort"
	node_45.transform = operands[1225]
	node_45.sorting_offset = operands[1226]
	node_45.material_override = material_41
	node_45.emitting = operands[1227]
	node_45.amount = operands[1228]
	node_45.lifetime = operands[1229]
	node_45.one_shot = operands[1230]
	node_45.use_fixed_seed = operands[1231]
	node_45.seed = operands[1232]
	node_45.fixed_fps = operands[1233]
	node_45.visibility_aabb = operands[1234]
	node_45.local_coords = operands[1235]
	node_45.transform_align = operands[1236]
	node_45.process_material = material_42
	node_45.draw_pass_1 = operands[1237]
	node_0.add_child(node_45)
	var node_46 := GPUParticles3D.new()
	node_46.name = "BoundaryBillow19_next_cohort"
	node_46.transform = operands[1238]
	node_46.sorting_offset = operands[1239]
	node_46.material_override = material_43
	node_46.emitting = operands[1240]
	node_46.amount = operands[1241]
	node_46.lifetime = operands[1242]
	node_46.one_shot = operands[1243]
	node_46.use_fixed_seed = operands[1244]
	node_46.seed = operands[1245]
	node_46.fixed_fps = operands[1246]
	node_46.visibility_aabb = operands[1247]
	node_46.local_coords = operands[1248]
	node_46.transform_align = operands[1249]
	node_46.process_material = material_44
	node_46.draw_pass_1 = operands[1250]
	node_0.add_child(node_46)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"root": node_0, "geometry": [node_1, node_2, node_3, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_41, node_42, node_43, node_44, node_45, node_46], "materials": [node_1.material_override, node_2.material_override], "cohorts": [[node_1, node_25], [node_2, node_26], [node_5, node_27], [node_6, node_28], [node_7, node_29], [node_8, node_30], [node_9, node_31], [node_10, node_32], [node_11, node_33], [node_12, node_34], [node_13, node_35], [node_14, node_36], [node_15, node_37], [node_16, node_38], [node_17, node_39], [node_18, node_40], [node_19, node_41], [node_20, node_42], [node_21, node_43], [node_22, node_44], [node_23, node_45], [node_24, node_46]]}
