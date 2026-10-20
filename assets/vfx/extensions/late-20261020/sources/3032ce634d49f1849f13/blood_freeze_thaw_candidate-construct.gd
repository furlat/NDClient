extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("liquid_private_materials")
	var material_0: ShaderMaterial = operands[444].duplicate(false)
	var material_1: ShaderMaterial = operands[445].duplicate(false)
	var material_2: ShaderMaterial = operands[446].duplicate(false)
	var material_3: ShaderMaterial = material_1
	var material_4: ShaderMaterial = material_2
	var material_5: ShaderMaterial = material_1
	var material_6: ShaderMaterial = material_2
	var material_7: ShaderMaterial = material_1
	var material_8: ShaderMaterial = material_2
	var material_9: ShaderMaterial = material_1
	var material_10: ShaderMaterial = material_2
	var material_11: ShaderMaterial = material_1
	var material_12: ShaderMaterial = material_2
	var material_13: ShaderMaterial = material_1
	var material_14: ShaderMaterial = material_2
	var material_15: ShaderMaterial = material_1
	var material_16: ShaderMaterial = material_2
	var material_17: ShaderMaterial = material_1
	var material_18: ShaderMaterial = material_2
	var material_19: ShaderMaterial = material_1
	var material_20: ShaderMaterial = material_2
	var material_21: ShaderMaterial = material_1
	var material_22: ShaderMaterial = material_2
	var material_23: ShaderMaterial = material_1
	var material_24: ShaderMaterial = material_2
	var material_25: ShaderMaterial = operands[447].duplicate(false)
	var material_26: ShaderMaterial = operands[448].duplicate(false)
	var material_27: ShaderMaterial = operands[449].duplicate(false)
	var material_28: ShaderMaterial = operands[450].duplicate(false)
	var material_29: ShaderMaterial = operands[451].duplicate(false)
	var material_30: ShaderMaterial = material_27
	var material_31: ShaderMaterial = material_28
	var material_32: ShaderMaterial = material_29
	var material_33: ShaderMaterial = material_27
	var material_34: ShaderMaterial = material_28
	var material_35: ShaderMaterial = material_29
	var material_36: ShaderMaterial = material_27
	var material_37: ShaderMaterial = material_28
	var material_38: ShaderMaterial = material_29
	var material_39: ShaderMaterial = material_27
	var material_40: ShaderMaterial = material_28
	var material_41: ShaderMaterial = material_29
	var material_42: ShaderMaterial = material_27
	var material_43: ShaderMaterial = material_28
	var material_44: ShaderMaterial = material_29
	var material_45: ShaderMaterial = material_27
	var material_46: ShaderMaterial = material_28
	var material_47: ShaderMaterial = material_29
	var material_48: ShaderMaterial = material_27
	var material_49: ShaderMaterial = material_28
	var material_50: ShaderMaterial = material_29
	var material_51: ShaderMaterial = material_27
	var material_52: ShaderMaterial = material_28
	var material_53: ShaderMaterial = material_29
	var material_54: ShaderMaterial = material_27
	var material_55: ShaderMaterial = material_28
	var material_56: ShaderMaterial = material_29
	var material_57: ShaderMaterial = material_27
	var material_58: ShaderMaterial = material_28
	var material_59: ShaderMaterial = material_29
	var material_60: ShaderMaterial = material_27
	var material_61: ShaderMaterial = material_28
	var material_62: ShaderMaterial = material_29
	var material_63: ShaderMaterial = material_25
	var material_64: ShaderMaterial = material_25
	var material_65: ShaderMaterial = material_25
	var material_66: ShaderMaterial = material_25
	var material_67: ShaderMaterial = material_25
	var material_68: ShaderMaterial = material_25
	var material_69: ShaderMaterial = material_25
	var material_70: ShaderMaterial = material_25
	var material_71: ShaderMaterial = material_25
	var material_72: ShaderMaterial = material_25
	var material_73: ShaderMaterial = material_25
	var material_74: ShaderMaterial = operands[452].duplicate(false)
	var material_75: ShaderMaterial = operands[453].duplicate(false)
	var material_76: ShaderMaterial = material_74
	var material_77: ShaderMaterial = material_75
	var material_78: ShaderMaterial = material_74
	var material_79: ShaderMaterial = material_75
	var material_80: ShaderMaterial = material_74
	var material_81: ShaderMaterial = material_75
	var material_82: ShaderMaterial = material_74
	var material_83: ShaderMaterial = material_75
	var material_84: ShaderMaterial = material_74
	var material_85: ShaderMaterial = material_75
	var material_86: ShaderMaterial = material_74
	var material_87: ShaderMaterial = material_75
	var material_88: ShaderMaterial = material_74
	var material_89: ShaderMaterial = material_75
	var material_90: ShaderMaterial = material_74
	var material_91: ShaderMaterial = material_75
	var material_92: ShaderMaterial = material_74
	var material_93: ShaderMaterial = material_75
	var material_94: ShaderMaterial = material_74
	var material_95: ShaderMaterial = material_75
	var material_96: ShaderMaterial = material_74
	var material_97: ShaderMaterial = material_75
	var material_98: ShaderMaterial = operands[454].duplicate(false)
	if profile_details: Profile.end("liquid_private_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0 := Node3D.new()
	node_0.name = "surface"
	var node_1 := MeshInstance3D.new()
	node_1.name = "FactoryGenerated_0000_MeshInstance3D"
	node_1.transform = operands[0]
	node_1.layers = operands[1]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_1.material_override = material_0
	if profile_details: Profile.end("liquid_node_material_override")
	node_1.cast_shadow = operands[2]
	node_1.mesh = operands[3]
	node_0.add_child(node_1)
	var node_2 := MultiMeshInstance3D.new()
	node_2.name = "FactoryGenerated_0001_MultiMeshInstance3D"
	node_2.layers = operands[4]
	node_2.cast_shadow = operands[5]
	node_2.custom_aabb = operands[6]
	node_0.add_child(node_2)
	var node_3 := Node3D.new()
	node_3.name = "FactoryGenerated_0002_Node3D"
	node_3.visible = operands[7]
	node_0.add_child(node_3)
	var node_4 := MeshInstance3D.new()
	node_4.name = "ElectricCore0"
	node_4.layers = operands[8]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_4.material_override = material_1
	if profile_details: Profile.end("liquid_node_material_override")
	node_4.cast_shadow = operands[9]
	node_4.custom_aabb = operands[10]
	node_4.set("instance_shader_parameters/factory_liquid_link_index", operands[11])
	node_4.mesh = operands[12]
	node_3.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "ElectricGlow0"
	node_5.layers = operands[13]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_5.material_override = material_2
	if profile_details: Profile.end("liquid_node_material_override")
	node_5.cast_shadow = operands[14]
	node_5.custom_aabb = operands[15]
	node_5.set("instance_shader_parameters/factory_liquid_link_index", operands[16])
	node_5.mesh = operands[17]
	node_3.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "ElectricCore1"
	node_6.layers = operands[18]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_6.material_override = material_3
	if profile_details: Profile.end("liquid_node_material_override")
	node_6.cast_shadow = operands[19]
	node_6.custom_aabb = operands[20]
	node_6.set("instance_shader_parameters/factory_liquid_link_index", operands[21])
	node_6.mesh = operands[22]
	node_3.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "ElectricGlow1"
	node_7.layers = operands[23]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_7.material_override = material_4
	if profile_details: Profile.end("liquid_node_material_override")
	node_7.cast_shadow = operands[24]
	node_7.custom_aabb = operands[25]
	node_7.set("instance_shader_parameters/factory_liquid_link_index", operands[26])
	node_7.mesh = operands[27]
	node_3.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "ElectricCore2"
	node_8.layers = operands[28]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_8.material_override = material_5
	if profile_details: Profile.end("liquid_node_material_override")
	node_8.cast_shadow = operands[29]
	node_8.custom_aabb = operands[30]
	node_8.set("instance_shader_parameters/factory_liquid_link_index", operands[31])
	node_8.mesh = operands[32]
	node_3.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "ElectricGlow2"
	node_9.layers = operands[33]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_9.material_override = material_6
	if profile_details: Profile.end("liquid_node_material_override")
	node_9.cast_shadow = operands[34]
	node_9.custom_aabb = operands[35]
	node_9.set("instance_shader_parameters/factory_liquid_link_index", operands[36])
	node_9.mesh = operands[37]
	node_3.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "ElectricCore3"
	node_10.layers = operands[38]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_10.material_override = material_7
	if profile_details: Profile.end("liquid_node_material_override")
	node_10.cast_shadow = operands[39]
	node_10.custom_aabb = operands[40]
	node_10.set("instance_shader_parameters/factory_liquid_link_index", operands[41])
	node_10.mesh = operands[42]
	node_3.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "ElectricGlow3"
	node_11.layers = operands[43]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_11.material_override = material_8
	if profile_details: Profile.end("liquid_node_material_override")
	node_11.cast_shadow = operands[44]
	node_11.custom_aabb = operands[45]
	node_11.set("instance_shader_parameters/factory_liquid_link_index", operands[46])
	node_11.mesh = operands[47]
	node_3.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "ElectricCore4"
	node_12.layers = operands[48]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_12.material_override = material_9
	if profile_details: Profile.end("liquid_node_material_override")
	node_12.cast_shadow = operands[49]
	node_12.custom_aabb = operands[50]
	node_12.set("instance_shader_parameters/factory_liquid_link_index", operands[51])
	node_12.mesh = operands[52]
	node_3.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "ElectricGlow4"
	node_13.layers = operands[53]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_13.material_override = material_10
	if profile_details: Profile.end("liquid_node_material_override")
	node_13.cast_shadow = operands[54]
	node_13.custom_aabb = operands[55]
	node_13.set("instance_shader_parameters/factory_liquid_link_index", operands[56])
	node_13.mesh = operands[57]
	node_3.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "ElectricCore5"
	node_14.layers = operands[58]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_14.material_override = material_11
	if profile_details: Profile.end("liquid_node_material_override")
	node_14.cast_shadow = operands[59]
	node_14.custom_aabb = operands[60]
	node_14.set("instance_shader_parameters/factory_liquid_link_index", operands[61])
	node_14.mesh = operands[62]
	node_3.add_child(node_14)
	var node_15 := MeshInstance3D.new()
	node_15.name = "ElectricGlow5"
	node_15.layers = operands[63]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_15.material_override = material_12
	if profile_details: Profile.end("liquid_node_material_override")
	node_15.cast_shadow = operands[64]
	node_15.custom_aabb = operands[65]
	node_15.set("instance_shader_parameters/factory_liquid_link_index", operands[66])
	node_15.mesh = operands[67]
	node_3.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "ElectricCore6"
	node_16.layers = operands[68]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_16.material_override = material_13
	if profile_details: Profile.end("liquid_node_material_override")
	node_16.cast_shadow = operands[69]
	node_16.custom_aabb = operands[70]
	node_16.set("instance_shader_parameters/factory_liquid_link_index", operands[71])
	node_16.mesh = operands[72]
	node_3.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "ElectricGlow6"
	node_17.layers = operands[73]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_17.material_override = material_14
	if profile_details: Profile.end("liquid_node_material_override")
	node_17.cast_shadow = operands[74]
	node_17.custom_aabb = operands[75]
	node_17.set("instance_shader_parameters/factory_liquid_link_index", operands[76])
	node_17.mesh = operands[77]
	node_3.add_child(node_17)
	var node_18 := MeshInstance3D.new()
	node_18.name = "ElectricCore7"
	node_18.layers = operands[78]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_18.material_override = material_15
	if profile_details: Profile.end("liquid_node_material_override")
	node_18.cast_shadow = operands[79]
	node_18.custom_aabb = operands[80]
	node_18.set("instance_shader_parameters/factory_liquid_link_index", operands[81])
	node_18.mesh = operands[82]
	node_3.add_child(node_18)
	var node_19 := MeshInstance3D.new()
	node_19.name = "ElectricGlow7"
	node_19.layers = operands[83]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_19.material_override = material_16
	if profile_details: Profile.end("liquid_node_material_override")
	node_19.cast_shadow = operands[84]
	node_19.custom_aabb = operands[85]
	node_19.set("instance_shader_parameters/factory_liquid_link_index", operands[86])
	node_19.mesh = operands[87]
	node_3.add_child(node_19)
	var node_20 := MeshInstance3D.new()
	node_20.name = "ElectricCore8"
	node_20.layers = operands[88]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_20.material_override = material_17
	if profile_details: Profile.end("liquid_node_material_override")
	node_20.cast_shadow = operands[89]
	node_20.custom_aabb = operands[90]
	node_20.set("instance_shader_parameters/factory_liquid_link_index", operands[91])
	node_20.mesh = operands[92]
	node_3.add_child(node_20)
	var node_21 := MeshInstance3D.new()
	node_21.name = "ElectricGlow8"
	node_21.layers = operands[93]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_21.material_override = material_18
	if profile_details: Profile.end("liquid_node_material_override")
	node_21.cast_shadow = operands[94]
	node_21.custom_aabb = operands[95]
	node_21.set("instance_shader_parameters/factory_liquid_link_index", operands[96])
	node_21.mesh = operands[97]
	node_3.add_child(node_21)
	var node_22 := MeshInstance3D.new()
	node_22.name = "ElectricCore9"
	node_22.layers = operands[98]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_22.material_override = material_19
	if profile_details: Profile.end("liquid_node_material_override")
	node_22.cast_shadow = operands[99]
	node_22.custom_aabb = operands[100]
	node_22.set("instance_shader_parameters/factory_liquid_link_index", operands[101])
	node_22.mesh = operands[102]
	node_3.add_child(node_22)
	var node_23 := MeshInstance3D.new()
	node_23.name = "ElectricGlow9"
	node_23.layers = operands[103]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_23.material_override = material_20
	if profile_details: Profile.end("liquid_node_material_override")
	node_23.cast_shadow = operands[104]
	node_23.custom_aabb = operands[105]
	node_23.set("instance_shader_parameters/factory_liquid_link_index", operands[106])
	node_23.mesh = operands[107]
	node_3.add_child(node_23)
	var node_24 := MeshInstance3D.new()
	node_24.name = "ElectricCore10"
	node_24.layers = operands[108]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_24.material_override = material_21
	if profile_details: Profile.end("liquid_node_material_override")
	node_24.cast_shadow = operands[109]
	node_24.custom_aabb = operands[110]
	node_24.set("instance_shader_parameters/factory_liquid_link_index", operands[111])
	node_24.mesh = operands[112]
	node_3.add_child(node_24)
	var node_25 := MeshInstance3D.new()
	node_25.name = "ElectricGlow10"
	node_25.layers = operands[113]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_25.material_override = material_22
	if profile_details: Profile.end("liquid_node_material_override")
	node_25.cast_shadow = operands[114]
	node_25.custom_aabb = operands[115]
	node_25.set("instance_shader_parameters/factory_liquid_link_index", operands[116])
	node_25.mesh = operands[117]
	node_3.add_child(node_25)
	var node_26 := MeshInstance3D.new()
	node_26.name = "ElectricCore11"
	node_26.layers = operands[118]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_26.material_override = material_23
	if profile_details: Profile.end("liquid_node_material_override")
	node_26.cast_shadow = operands[119]
	node_26.custom_aabb = operands[120]
	node_26.set("instance_shader_parameters/factory_liquid_link_index", operands[121])
	node_26.mesh = operands[122]
	node_3.add_child(node_26)
	var node_27 := MeshInstance3D.new()
	node_27.name = "ElectricGlow11"
	node_27.layers = operands[123]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_27.material_override = material_24
	if profile_details: Profile.end("liquid_node_material_override")
	node_27.cast_shadow = operands[124]
	node_27.custom_aabb = operands[125]
	node_27.set("instance_shader_parameters/factory_liquid_link_index", operands[126])
	node_27.mesh = operands[127]
	node_3.add_child(node_27)
	var node_28 := MeshInstance3D.new()
	node_28.name = "MeasuredContactArcs0"
	node_28.visible = operands[128]
	node_28.layers = operands[129]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_28.material_override = material_25
	if profile_details: Profile.end("liquid_node_material_override")
	node_28.cast_shadow = operands[130]
	node_28.custom_aabb = operands[131]
	node_28.mesh = operands[132]
	node_3.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "SourceHandCoils"
	node_29.layers = operands[133]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_29.material_override = material_26
	if profile_details: Profile.end("liquid_node_material_override")
	node_29.cast_shadow = operands[134]
	node_29.custom_aabb = operands[135]
	node_29.mesh = operands[136]
	node_3.add_child(node_29)
	var node_30 := MeshInstance3D.new()
	node_30.name = "FactoryGenerated_0026_MeshInstance3D"
	node_30.layers = operands[137]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_30.material_override = material_27
	if profile_details: Profile.end("liquid_node_material_override")
	node_30.cast_shadow = operands[138]
	node_30.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[139])
	node_30.mesh = operands[140]
	node_3.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "FactoryGenerated_0027_MeshInstance3D"
	node_31.layers = operands[141]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_31.material_override = material_28
	if profile_details: Profile.end("liquid_node_material_override")
	node_31.cast_shadow = operands[142]
	node_31.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[143])
	node_31.mesh = operands[144]
	node_3.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "FactoryGenerated_0028_MeshInstance3D"
	node_32.layers = operands[145]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_32.material_override = material_29
	if profile_details: Profile.end("liquid_node_material_override")
	node_32.cast_shadow = operands[146]
	node_32.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[147])
	node_32.mesh = operands[148]
	node_3.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "FactoryGenerated_0029_MeshInstance3D"
	node_33.layers = operands[149]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_33.material_override = material_30
	if profile_details: Profile.end("liquid_node_material_override")
	node_33.cast_shadow = operands[150]
	node_33.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[151])
	node_33.mesh = operands[152]
	node_3.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "FactoryGenerated_0030_MeshInstance3D"
	node_34.layers = operands[153]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_34.material_override = material_31
	if profile_details: Profile.end("liquid_node_material_override")
	node_34.cast_shadow = operands[154]
	node_34.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[155])
	node_34.mesh = operands[156]
	node_3.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "FactoryGenerated_0031_MeshInstance3D"
	node_35.layers = operands[157]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_35.material_override = material_32
	if profile_details: Profile.end("liquid_node_material_override")
	node_35.cast_shadow = operands[158]
	node_35.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[159])
	node_35.mesh = operands[160]
	node_3.add_child(node_35)
	var node_36 := MeshInstance3D.new()
	node_36.name = "FactoryGenerated_0032_MeshInstance3D"
	node_36.layers = operands[161]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_36.material_override = material_33
	if profile_details: Profile.end("liquid_node_material_override")
	node_36.cast_shadow = operands[162]
	node_36.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[163])
	node_36.mesh = operands[164]
	node_3.add_child(node_36)
	var node_37 := MeshInstance3D.new()
	node_37.name = "FactoryGenerated_0033_MeshInstance3D"
	node_37.layers = operands[165]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_37.material_override = material_34
	if profile_details: Profile.end("liquid_node_material_override")
	node_37.cast_shadow = operands[166]
	node_37.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[167])
	node_37.mesh = operands[168]
	node_3.add_child(node_37)
	var node_38 := MeshInstance3D.new()
	node_38.name = "FactoryGenerated_0034_MeshInstance3D"
	node_38.layers = operands[169]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_38.material_override = material_35
	if profile_details: Profile.end("liquid_node_material_override")
	node_38.cast_shadow = operands[170]
	node_38.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[171])
	node_38.mesh = operands[172]
	node_3.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "FactoryGenerated_0035_MeshInstance3D"
	node_39.layers = operands[173]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_39.material_override = material_36
	if profile_details: Profile.end("liquid_node_material_override")
	node_39.cast_shadow = operands[174]
	node_39.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[175])
	node_39.mesh = operands[176]
	node_3.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "FactoryGenerated_0036_MeshInstance3D"
	node_40.layers = operands[177]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_40.material_override = material_37
	if profile_details: Profile.end("liquid_node_material_override")
	node_40.cast_shadow = operands[178]
	node_40.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[179])
	node_40.mesh = operands[180]
	node_3.add_child(node_40)
	var node_41 := MeshInstance3D.new()
	node_41.name = "FactoryGenerated_0037_MeshInstance3D"
	node_41.layers = operands[181]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_41.material_override = material_38
	if profile_details: Profile.end("liquid_node_material_override")
	node_41.cast_shadow = operands[182]
	node_41.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[183])
	node_41.mesh = operands[184]
	node_3.add_child(node_41)
	var node_42 := MeshInstance3D.new()
	node_42.name = "FactoryGenerated_0038_MeshInstance3D"
	node_42.layers = operands[185]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_42.material_override = material_39
	if profile_details: Profile.end("liquid_node_material_override")
	node_42.cast_shadow = operands[186]
	node_42.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[187])
	node_42.mesh = operands[188]
	node_3.add_child(node_42)
	var node_43 := MeshInstance3D.new()
	node_43.name = "FactoryGenerated_0039_MeshInstance3D"
	node_43.layers = operands[189]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_43.material_override = material_40
	if profile_details: Profile.end("liquid_node_material_override")
	node_43.cast_shadow = operands[190]
	node_43.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[191])
	node_43.mesh = operands[192]
	node_3.add_child(node_43)
	var node_44 := MeshInstance3D.new()
	node_44.name = "FactoryGenerated_0040_MeshInstance3D"
	node_44.layers = operands[193]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_44.material_override = material_41
	if profile_details: Profile.end("liquid_node_material_override")
	node_44.cast_shadow = operands[194]
	node_44.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[195])
	node_44.mesh = operands[196]
	node_3.add_child(node_44)
	var node_45 := MeshInstance3D.new()
	node_45.name = "FactoryGenerated_0041_MeshInstance3D"
	node_45.layers = operands[197]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_45.material_override = material_42
	if profile_details: Profile.end("liquid_node_material_override")
	node_45.cast_shadow = operands[198]
	node_45.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[199])
	node_45.mesh = operands[200]
	node_3.add_child(node_45)
	var node_46 := MeshInstance3D.new()
	node_46.name = "FactoryGenerated_0042_MeshInstance3D"
	node_46.layers = operands[201]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_46.material_override = material_43
	if profile_details: Profile.end("liquid_node_material_override")
	node_46.cast_shadow = operands[202]
	node_46.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[203])
	node_46.mesh = operands[204]
	node_3.add_child(node_46)
	var node_47 := MeshInstance3D.new()
	node_47.name = "FactoryGenerated_0043_MeshInstance3D"
	node_47.layers = operands[205]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_47.material_override = material_44
	if profile_details: Profile.end("liquid_node_material_override")
	node_47.cast_shadow = operands[206]
	node_47.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[207])
	node_47.mesh = operands[208]
	node_3.add_child(node_47)
	var node_48 := MeshInstance3D.new()
	node_48.name = "FactoryGenerated_0044_MeshInstance3D"
	node_48.layers = operands[209]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_48.material_override = material_45
	if profile_details: Profile.end("liquid_node_material_override")
	node_48.cast_shadow = operands[210]
	node_48.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[211])
	node_48.mesh = operands[212]
	node_3.add_child(node_48)
	var node_49 := MeshInstance3D.new()
	node_49.name = "FactoryGenerated_0045_MeshInstance3D"
	node_49.layers = operands[213]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_49.material_override = material_46
	if profile_details: Profile.end("liquid_node_material_override")
	node_49.cast_shadow = operands[214]
	node_49.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[215])
	node_49.mesh = operands[216]
	node_3.add_child(node_49)
	var node_50 := MeshInstance3D.new()
	node_50.name = "FactoryGenerated_0046_MeshInstance3D"
	node_50.layers = operands[217]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_50.material_override = material_47
	if profile_details: Profile.end("liquid_node_material_override")
	node_50.cast_shadow = operands[218]
	node_50.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[219])
	node_50.mesh = operands[220]
	node_3.add_child(node_50)
	var node_51 := MeshInstance3D.new()
	node_51.name = "FactoryGenerated_0047_MeshInstance3D"
	node_51.layers = operands[221]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_51.material_override = material_48
	if profile_details: Profile.end("liquid_node_material_override")
	node_51.cast_shadow = operands[222]
	node_51.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[223])
	node_51.mesh = operands[224]
	node_3.add_child(node_51)
	var node_52 := MeshInstance3D.new()
	node_52.name = "FactoryGenerated_0048_MeshInstance3D"
	node_52.layers = operands[225]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_52.material_override = material_49
	if profile_details: Profile.end("liquid_node_material_override")
	node_52.cast_shadow = operands[226]
	node_52.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[227])
	node_52.mesh = operands[228]
	node_3.add_child(node_52)
	var node_53 := MeshInstance3D.new()
	node_53.name = "FactoryGenerated_0049_MeshInstance3D"
	node_53.layers = operands[229]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_53.material_override = material_50
	if profile_details: Profile.end("liquid_node_material_override")
	node_53.cast_shadow = operands[230]
	node_53.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[231])
	node_53.mesh = operands[232]
	node_3.add_child(node_53)
	var node_54 := MeshInstance3D.new()
	node_54.name = "FactoryGenerated_0050_MeshInstance3D"
	node_54.layers = operands[233]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_54.material_override = material_51
	if profile_details: Profile.end("liquid_node_material_override")
	node_54.cast_shadow = operands[234]
	node_54.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[235])
	node_54.mesh = operands[236]
	node_3.add_child(node_54)
	var node_55 := MeshInstance3D.new()
	node_55.name = "FactoryGenerated_0051_MeshInstance3D"
	node_55.layers = operands[237]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_55.material_override = material_52
	if profile_details: Profile.end("liquid_node_material_override")
	node_55.cast_shadow = operands[238]
	node_55.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[239])
	node_55.mesh = operands[240]
	node_3.add_child(node_55)
	var node_56 := MeshInstance3D.new()
	node_56.name = "FactoryGenerated_0052_MeshInstance3D"
	node_56.layers = operands[241]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_56.material_override = material_53
	if profile_details: Profile.end("liquid_node_material_override")
	node_56.cast_shadow = operands[242]
	node_56.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[243])
	node_56.mesh = operands[244]
	node_3.add_child(node_56)
	var node_57 := MeshInstance3D.new()
	node_57.name = "FactoryGenerated_0053_MeshInstance3D"
	node_57.layers = operands[245]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_57.material_override = material_54
	if profile_details: Profile.end("liquid_node_material_override")
	node_57.cast_shadow = operands[246]
	node_57.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[247])
	node_57.mesh = operands[248]
	node_3.add_child(node_57)
	var node_58 := MeshInstance3D.new()
	node_58.name = "FactoryGenerated_0054_MeshInstance3D"
	node_58.layers = operands[249]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_58.material_override = material_55
	if profile_details: Profile.end("liquid_node_material_override")
	node_58.cast_shadow = operands[250]
	node_58.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[251])
	node_58.mesh = operands[252]
	node_3.add_child(node_58)
	var node_59 := MeshInstance3D.new()
	node_59.name = "FactoryGenerated_0055_MeshInstance3D"
	node_59.layers = operands[253]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_59.material_override = material_56
	if profile_details: Profile.end("liquid_node_material_override")
	node_59.cast_shadow = operands[254]
	node_59.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[255])
	node_59.mesh = operands[256]
	node_3.add_child(node_59)
	var node_60 := MeshInstance3D.new()
	node_60.name = "FactoryGenerated_0056_MeshInstance3D"
	node_60.layers = operands[257]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_60.material_override = material_57
	if profile_details: Profile.end("liquid_node_material_override")
	node_60.cast_shadow = operands[258]
	node_60.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[259])
	node_60.mesh = operands[260]
	node_3.add_child(node_60)
	var node_61 := MeshInstance3D.new()
	node_61.name = "FactoryGenerated_0057_MeshInstance3D"
	node_61.layers = operands[261]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_61.material_override = material_58
	if profile_details: Profile.end("liquid_node_material_override")
	node_61.cast_shadow = operands[262]
	node_61.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[263])
	node_61.mesh = operands[264]
	node_3.add_child(node_61)
	var node_62 := MeshInstance3D.new()
	node_62.name = "FactoryGenerated_0058_MeshInstance3D"
	node_62.layers = operands[265]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_62.material_override = material_59
	if profile_details: Profile.end("liquid_node_material_override")
	node_62.cast_shadow = operands[266]
	node_62.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[267])
	node_62.mesh = operands[268]
	node_3.add_child(node_62)
	var node_63 := MeshInstance3D.new()
	node_63.name = "FactoryGenerated_0059_MeshInstance3D"
	node_63.layers = operands[269]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_63.material_override = material_60
	if profile_details: Profile.end("liquid_node_material_override")
	node_63.cast_shadow = operands[270]
	node_63.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[271])
	node_63.mesh = operands[272]
	node_3.add_child(node_63)
	var node_64 := MeshInstance3D.new()
	node_64.name = "FactoryGenerated_0060_MeshInstance3D"
	node_64.layers = operands[273]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_64.material_override = material_61
	if profile_details: Profile.end("liquid_node_material_override")
	node_64.cast_shadow = operands[274]
	node_64.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[275])
	node_64.mesh = operands[276]
	node_3.add_child(node_64)
	var node_65 := MeshInstance3D.new()
	node_65.name = "FactoryGenerated_0061_MeshInstance3D"
	node_65.layers = operands[277]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_65.material_override = material_62
	if profile_details: Profile.end("liquid_node_material_override")
	node_65.cast_shadow = operands[278]
	node_65.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[279])
	node_65.mesh = operands[280]
	node_3.add_child(node_65)
	var node_66 := MeshInstance3D.new()
	node_66.name = "MeasuredContactArcs1"
	node_66.visible = operands[281]
	node_66.layers = operands[282]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_66.material_override = material_63
	if profile_details: Profile.end("liquid_node_material_override")
	node_66.cast_shadow = operands[283]
	node_66.custom_aabb = operands[284]
	node_66.mesh = operands[285]
	node_3.add_child(node_66)
	var node_67 := MeshInstance3D.new()
	node_67.name = "MeasuredContactArcs2"
	node_67.visible = operands[286]
	node_67.layers = operands[287]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_67.material_override = material_64
	if profile_details: Profile.end("liquid_node_material_override")
	node_67.cast_shadow = operands[288]
	node_67.custom_aabb = operands[289]
	node_67.mesh = operands[290]
	node_3.add_child(node_67)
	var node_68 := MeshInstance3D.new()
	node_68.name = "MeasuredContactArcs3"
	node_68.visible = operands[291]
	node_68.layers = operands[292]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_68.material_override = material_65
	if profile_details: Profile.end("liquid_node_material_override")
	node_68.cast_shadow = operands[293]
	node_68.custom_aabb = operands[294]
	node_68.mesh = operands[295]
	node_3.add_child(node_68)
	var node_69 := MeshInstance3D.new()
	node_69.name = "MeasuredContactArcs4"
	node_69.visible = operands[296]
	node_69.layers = operands[297]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_69.material_override = material_66
	if profile_details: Profile.end("liquid_node_material_override")
	node_69.cast_shadow = operands[298]
	node_69.custom_aabb = operands[299]
	node_69.mesh = operands[300]
	node_3.add_child(node_69)
	var node_70 := MeshInstance3D.new()
	node_70.name = "MeasuredContactArcs5"
	node_70.visible = operands[301]
	node_70.layers = operands[302]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_70.material_override = material_67
	if profile_details: Profile.end("liquid_node_material_override")
	node_70.cast_shadow = operands[303]
	node_70.custom_aabb = operands[304]
	node_70.mesh = operands[305]
	node_3.add_child(node_70)
	var node_71 := MeshInstance3D.new()
	node_71.name = "MeasuredContactArcs6"
	node_71.visible = operands[306]
	node_71.layers = operands[307]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_71.material_override = material_68
	if profile_details: Profile.end("liquid_node_material_override")
	node_71.cast_shadow = operands[308]
	node_71.custom_aabb = operands[309]
	node_71.mesh = operands[310]
	node_3.add_child(node_71)
	var node_72 := MeshInstance3D.new()
	node_72.name = "MeasuredContactArcs7"
	node_72.visible = operands[311]
	node_72.layers = operands[312]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_72.material_override = material_69
	if profile_details: Profile.end("liquid_node_material_override")
	node_72.cast_shadow = operands[313]
	node_72.custom_aabb = operands[314]
	node_72.mesh = operands[315]
	node_3.add_child(node_72)
	var node_73 := MeshInstance3D.new()
	node_73.name = "MeasuredContactArcs8"
	node_73.visible = operands[316]
	node_73.layers = operands[317]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_73.material_override = material_70
	if profile_details: Profile.end("liquid_node_material_override")
	node_73.cast_shadow = operands[318]
	node_73.custom_aabb = operands[319]
	node_73.mesh = operands[320]
	node_3.add_child(node_73)
	var node_74 := MeshInstance3D.new()
	node_74.name = "MeasuredContactArcs9"
	node_74.visible = operands[321]
	node_74.layers = operands[322]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_74.material_override = material_71
	if profile_details: Profile.end("liquid_node_material_override")
	node_74.cast_shadow = operands[323]
	node_74.custom_aabb = operands[324]
	node_74.mesh = operands[325]
	node_3.add_child(node_74)
	var node_75 := MeshInstance3D.new()
	node_75.name = "MeasuredContactArcs10"
	node_75.visible = operands[326]
	node_75.layers = operands[327]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_75.material_override = material_72
	if profile_details: Profile.end("liquid_node_material_override")
	node_75.cast_shadow = operands[328]
	node_75.custom_aabb = operands[329]
	node_75.mesh = operands[330]
	node_3.add_child(node_75)
	var node_76 := MeshInstance3D.new()
	node_76.name = "MeasuredContactArcs11"
	node_76.visible = operands[331]
	node_76.layers = operands[332]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_76.material_override = material_73
	if profile_details: Profile.end("liquid_node_material_override")
	node_76.cast_shadow = operands[333]
	node_76.custom_aabb = operands[334]
	node_76.mesh = operands[335]
	node_3.add_child(node_76)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_77 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_77.name = "SourceSteam_0"
	node_77.layers = operands[336]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_77.material_override = material_74
	if profile_details: Profile.end("liquid_node_material_override")
	node_77.cast_shadow = operands[337]
	node_77.emitting = operands[338]
	if profile_details: Profile.begin("liquid_node_amount")
	node_77.amount = operands[339]
	if profile_details: Profile.end("liquid_node_amount")
	node_77.lifetime = operands[340]
	node_77.use_fixed_seed = operands[341]
	node_77.seed = operands[342]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_77.fixed_fps = operands[343]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_77.process_material = material_75
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_77.draw_pass_1 = operands[344]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_77)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_78 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_78.name = "SourceSteam_1"
	node_78.layers = operands[345]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_78.material_override = material_76
	if profile_details: Profile.end("liquid_node_material_override")
	node_78.cast_shadow = operands[346]
	node_78.emitting = operands[347]
	if profile_details: Profile.begin("liquid_node_amount")
	node_78.amount = operands[348]
	if profile_details: Profile.end("liquid_node_amount")
	node_78.lifetime = operands[349]
	node_78.use_fixed_seed = operands[350]
	node_78.seed = operands[351]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_78.fixed_fps = operands[352]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_78.process_material = material_77
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_78.draw_pass_1 = operands[353]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_78)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_79 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_79.name = "SourceSteam_2"
	node_79.layers = operands[354]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_79.material_override = material_78
	if profile_details: Profile.end("liquid_node_material_override")
	node_79.cast_shadow = operands[355]
	node_79.emitting = operands[356]
	if profile_details: Profile.begin("liquid_node_amount")
	node_79.amount = operands[357]
	if profile_details: Profile.end("liquid_node_amount")
	node_79.lifetime = operands[358]
	node_79.use_fixed_seed = operands[359]
	node_79.seed = operands[360]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_79.fixed_fps = operands[361]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_79.process_material = material_79
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_79.draw_pass_1 = operands[362]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_79)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_80 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_80.name = "SourceSteam_3"
	node_80.layers = operands[363]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_80.material_override = material_80
	if profile_details: Profile.end("liquid_node_material_override")
	node_80.cast_shadow = operands[364]
	node_80.emitting = operands[365]
	if profile_details: Profile.begin("liquid_node_amount")
	node_80.amount = operands[366]
	if profile_details: Profile.end("liquid_node_amount")
	node_80.lifetime = operands[367]
	node_80.use_fixed_seed = operands[368]
	node_80.seed = operands[369]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_80.fixed_fps = operands[370]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_80.process_material = material_81
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_80.draw_pass_1 = operands[371]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_80)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_81 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_81.name = "SourceSteam_4"
	node_81.layers = operands[372]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_81.material_override = material_82
	if profile_details: Profile.end("liquid_node_material_override")
	node_81.cast_shadow = operands[373]
	node_81.emitting = operands[374]
	if profile_details: Profile.begin("liquid_node_amount")
	node_81.amount = operands[375]
	if profile_details: Profile.end("liquid_node_amount")
	node_81.lifetime = operands[376]
	node_81.use_fixed_seed = operands[377]
	node_81.seed = operands[378]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_81.fixed_fps = operands[379]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_81.process_material = material_83
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_81.draw_pass_1 = operands[380]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_81)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_82 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_82.name = "SourceSteam_5"
	node_82.layers = operands[381]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_82.material_override = material_84
	if profile_details: Profile.end("liquid_node_material_override")
	node_82.cast_shadow = operands[382]
	node_82.emitting = operands[383]
	if profile_details: Profile.begin("liquid_node_amount")
	node_82.amount = operands[384]
	if profile_details: Profile.end("liquid_node_amount")
	node_82.lifetime = operands[385]
	node_82.use_fixed_seed = operands[386]
	node_82.seed = operands[387]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_82.fixed_fps = operands[388]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_82.process_material = material_85
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_82.draw_pass_1 = operands[389]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_82)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_83 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_83.name = "SourceSteam_6"
	node_83.layers = operands[390]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_83.material_override = material_86
	if profile_details: Profile.end("liquid_node_material_override")
	node_83.cast_shadow = operands[391]
	node_83.emitting = operands[392]
	if profile_details: Profile.begin("liquid_node_amount")
	node_83.amount = operands[393]
	if profile_details: Profile.end("liquid_node_amount")
	node_83.lifetime = operands[394]
	node_83.use_fixed_seed = operands[395]
	node_83.seed = operands[396]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_83.fixed_fps = operands[397]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_83.process_material = material_87
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_83.draw_pass_1 = operands[398]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_83)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_84 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_84.name = "SourceSteam_7"
	node_84.layers = operands[399]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_84.material_override = material_88
	if profile_details: Profile.end("liquid_node_material_override")
	node_84.cast_shadow = operands[400]
	node_84.emitting = operands[401]
	if profile_details: Profile.begin("liquid_node_amount")
	node_84.amount = operands[402]
	if profile_details: Profile.end("liquid_node_amount")
	node_84.lifetime = operands[403]
	node_84.use_fixed_seed = operands[404]
	node_84.seed = operands[405]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_84.fixed_fps = operands[406]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_84.process_material = material_89
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_84.draw_pass_1 = operands[407]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_84)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_85 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_85.name = "SourceSteam_8"
	node_85.layers = operands[408]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_85.material_override = material_90
	if profile_details: Profile.end("liquid_node_material_override")
	node_85.cast_shadow = operands[409]
	node_85.emitting = operands[410]
	if profile_details: Profile.begin("liquid_node_amount")
	node_85.amount = operands[411]
	if profile_details: Profile.end("liquid_node_amount")
	node_85.lifetime = operands[412]
	node_85.use_fixed_seed = operands[413]
	node_85.seed = operands[414]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_85.fixed_fps = operands[415]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_85.process_material = material_91
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_85.draw_pass_1 = operands[416]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_85)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_86 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_86.name = "SourceSteam_9"
	node_86.layers = operands[417]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_86.material_override = material_92
	if profile_details: Profile.end("liquid_node_material_override")
	node_86.cast_shadow = operands[418]
	node_86.emitting = operands[419]
	if profile_details: Profile.begin("liquid_node_amount")
	node_86.amount = operands[420]
	if profile_details: Profile.end("liquid_node_amount")
	node_86.lifetime = operands[421]
	node_86.use_fixed_seed = operands[422]
	node_86.seed = operands[423]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_86.fixed_fps = operands[424]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_86.process_material = material_93
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_86.draw_pass_1 = operands[425]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_86)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_87 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_87.name = "SourceSteam_10"
	node_87.layers = operands[426]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_87.material_override = material_94
	if profile_details: Profile.end("liquid_node_material_override")
	node_87.cast_shadow = operands[427]
	node_87.emitting = operands[428]
	if profile_details: Profile.begin("liquid_node_amount")
	node_87.amount = operands[429]
	if profile_details: Profile.end("liquid_node_amount")
	node_87.lifetime = operands[430]
	node_87.use_fixed_seed = operands[431]
	node_87.seed = operands[432]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_87.fixed_fps = operands[433]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_87.process_material = material_95
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_87.draw_pass_1 = operands[434]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_87)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_88 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_88.name = "SourceSteam_11"
	node_88.layers = operands[435]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_88.material_override = material_96
	if profile_details: Profile.end("liquid_node_material_override")
	node_88.cast_shadow = operands[436]
	node_88.emitting = operands[437]
	if profile_details: Profile.begin("liquid_node_amount")
	node_88.amount = operands[438]
	if profile_details: Profile.end("liquid_node_amount")
	node_88.lifetime = operands[439]
	node_88.use_fixed_seed = operands[440]
	node_88.seed = operands[441]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_88.fixed_fps = operands[442]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_88.process_material = material_97
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_88.draw_pass_1 = operands[443]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_88)
	if profile_details: Profile.end("cloud_program_nodes")
	if profile_details: Profile.begin("liquid_private_multimesh")
	var private_multimesh := MultiMesh.new()
	private_multimesh.transform_format = operands[455]
	private_multimesh.use_colors = operands[456]
	private_multimesh.use_custom_data = operands[457]
	private_multimesh.instance_count = operands[458]
	private_multimesh.visible_instance_count = operands[459]
	private_multimesh.mesh = operands[460]
	private_multimesh.buffer = operands[461]
	node_2.multimesh = private_multimesh
	node_2.material_override = material_98
	if profile_details: Profile.end("liquid_private_multimesh")
	if profile_details: Profile.begin("liquid_draw_instance_parameters")
	node_4.set_instance_shader_parameter("factory_liquid_link_index", 0)
	node_5.set_instance_shader_parameter("factory_liquid_link_index", 0)
	node_6.set_instance_shader_parameter("factory_liquid_link_index", 1)
	node_7.set_instance_shader_parameter("factory_liquid_link_index", 1)
	node_8.set_instance_shader_parameter("factory_liquid_link_index", 2)
	node_9.set_instance_shader_parameter("factory_liquid_link_index", 2)
	node_10.set_instance_shader_parameter("factory_liquid_link_index", 3)
	node_11.set_instance_shader_parameter("factory_liquid_link_index", 3)
	node_12.set_instance_shader_parameter("factory_liquid_link_index", 4)
	node_13.set_instance_shader_parameter("factory_liquid_link_index", 4)
	node_14.set_instance_shader_parameter("factory_liquid_link_index", 5)
	node_15.set_instance_shader_parameter("factory_liquid_link_index", 5)
	node_16.set_instance_shader_parameter("factory_liquid_link_index", 6)
	node_17.set_instance_shader_parameter("factory_liquid_link_index", 6)
	node_18.set_instance_shader_parameter("factory_liquid_link_index", 7)
	node_19.set_instance_shader_parameter("factory_liquid_link_index", 7)
	node_20.set_instance_shader_parameter("factory_liquid_link_index", 8)
	node_21.set_instance_shader_parameter("factory_liquid_link_index", 8)
	node_22.set_instance_shader_parameter("factory_liquid_link_index", 9)
	node_23.set_instance_shader_parameter("factory_liquid_link_index", 9)
	node_24.set_instance_shader_parameter("factory_liquid_link_index", 10)
	node_25.set_instance_shader_parameter("factory_liquid_link_index", 10)
	node_26.set_instance_shader_parameter("factory_liquid_link_index", 11)
	node_27.set_instance_shader_parameter("factory_liquid_link_index", 11)
	node_30.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_31.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_32.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_33.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_34.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_35.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_36.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_37.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_38.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_39.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_40.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_41.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_42.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_43.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_44.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_45.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_46.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_47.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_48.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_49.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_50.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_51.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_52.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_53.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_54.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_55.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_56.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_57.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_58.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_59.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_60.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_61.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_62.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_63.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_64.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_65.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	if profile_details: Profile.end("liquid_draw_instance_parameters")
	return {"plane": node_1, "droplets": node_2, "main": material_0, "all_materials": [material_0, material_1, material_2, material_25, material_26, material_27, material_28, material_29, material_74, material_75, material_98], "field_materials": [material_0, material_1, material_2, material_25, material_26, material_98], "clock_materials": [material_0, material_1, material_2, material_25, material_26, material_74], "link_materials": [material_1, material_2], "network": node_3, "ribbons": [{"core": node_4, "glow": node_5}, {"core": node_6, "glow": node_7}, {"core": node_8, "glow": node_9}, {"core": node_10, "glow": node_11}, {"core": node_12, "glow": node_13}, {"core": node_14, "glow": node_15}, {"core": node_16, "glow": node_17}, {"core": node_18, "glow": node_19}, {"core": node_20, "glow": node_21}, {"core": node_22, "glow": node_23}, {"core": node_24, "glow": node_25}, {"core": node_26, "glow": node_27}], "contact_groups": [[node_30, node_31, node_32], [node_33, node_34, node_35], [node_36, node_37, node_38], [node_39, node_40, node_41], [node_42, node_43, node_44], [node_45, node_46, node_47], [node_48, node_49, node_50], [node_51, node_52, node_53], [node_54, node_55, node_56], [node_57, node_58, node_59], [node_60, node_61, node_62], [node_63, node_64, node_65]], "plumes": [node_77, node_78, node_79, node_80, node_81, node_82, node_83, node_84, node_85, node_86, node_87, node_88], "flames": [], "world_process_units": [{"material": material_75, "values": operands[462]}], "root": node_0, "geometry": [node_1, node_2, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_41, node_42, node_43, node_44, node_45, node_46, node_47, node_48, node_49, node_50, node_51, node_52, node_53, node_54, node_55, node_56, node_57, node_58, node_59, node_60, node_61, node_62, node_63, node_64, node_65, node_66, node_67, node_68, node_69, node_70, node_71, node_72, node_73, node_74, node_75, node_76, node_77, node_78, node_79, node_80, node_81, node_82, node_83, node_84, node_85, node_86, node_87, node_88], "materials": [], "cohorts": []}
