extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("liquid_private_materials")
	var material_0: ShaderMaterial = operands[754].duplicate(false)
	var material_1: ShaderMaterial = operands[755].duplicate(false)
	var material_2: ShaderMaterial = operands[756].duplicate(false)
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
	var material_25: ShaderMaterial = material_1
	var material_26: ShaderMaterial = material_2
	var material_27: ShaderMaterial = material_1
	var material_28: ShaderMaterial = material_2
	var material_29: ShaderMaterial = material_1
	var material_30: ShaderMaterial = material_2
	var material_31: ShaderMaterial = material_1
	var material_32: ShaderMaterial = material_2
	var material_33: ShaderMaterial = material_1
	var material_34: ShaderMaterial = material_2
	var material_35: ShaderMaterial = material_1
	var material_36: ShaderMaterial = material_2
	var material_37: ShaderMaterial = material_1
	var material_38: ShaderMaterial = material_2
	var material_39: ShaderMaterial = material_1
	var material_40: ShaderMaterial = material_2
	var material_41: ShaderMaterial = material_1
	var material_42: ShaderMaterial = material_2
	var material_43: ShaderMaterial = material_1
	var material_44: ShaderMaterial = material_2
	var material_45: ShaderMaterial = operands[757].duplicate(false)
	var material_46: ShaderMaterial = operands[758].duplicate(false)
	var material_47: ShaderMaterial = operands[759].duplicate(false)
	var material_48: ShaderMaterial = operands[760].duplicate(false)
	var material_49: ShaderMaterial = operands[761].duplicate(false)
	var material_50: ShaderMaterial = material_47
	var material_51: ShaderMaterial = material_48
	var material_52: ShaderMaterial = material_49
	var material_53: ShaderMaterial = material_47
	var material_54: ShaderMaterial = material_48
	var material_55: ShaderMaterial = material_49
	var material_56: ShaderMaterial = material_47
	var material_57: ShaderMaterial = material_48
	var material_58: ShaderMaterial = material_49
	var material_59: ShaderMaterial = material_47
	var material_60: ShaderMaterial = material_48
	var material_61: ShaderMaterial = material_49
	var material_62: ShaderMaterial = material_47
	var material_63: ShaderMaterial = material_48
	var material_64: ShaderMaterial = material_49
	var material_65: ShaderMaterial = material_47
	var material_66: ShaderMaterial = material_48
	var material_67: ShaderMaterial = material_49
	var material_68: ShaderMaterial = material_47
	var material_69: ShaderMaterial = material_48
	var material_70: ShaderMaterial = material_49
	var material_71: ShaderMaterial = material_47
	var material_72: ShaderMaterial = material_48
	var material_73: ShaderMaterial = material_49
	var material_74: ShaderMaterial = material_47
	var material_75: ShaderMaterial = material_48
	var material_76: ShaderMaterial = material_49
	var material_77: ShaderMaterial = material_47
	var material_78: ShaderMaterial = material_48
	var material_79: ShaderMaterial = material_49
	var material_80: ShaderMaterial = material_47
	var material_81: ShaderMaterial = material_48
	var material_82: ShaderMaterial = material_49
	var material_83: ShaderMaterial = material_47
	var material_84: ShaderMaterial = material_48
	var material_85: ShaderMaterial = material_49
	var material_86: ShaderMaterial = material_47
	var material_87: ShaderMaterial = material_48
	var material_88: ShaderMaterial = material_49
	var material_89: ShaderMaterial = material_47
	var material_90: ShaderMaterial = material_48
	var material_91: ShaderMaterial = material_49
	var material_92: ShaderMaterial = material_47
	var material_93: ShaderMaterial = material_48
	var material_94: ShaderMaterial = material_49
	var material_95: ShaderMaterial = material_47
	var material_96: ShaderMaterial = material_48
	var material_97: ShaderMaterial = material_49
	var material_98: ShaderMaterial = material_47
	var material_99: ShaderMaterial = material_48
	var material_100: ShaderMaterial = material_49
	var material_101: ShaderMaterial = material_45
	var material_102: ShaderMaterial = material_45
	var material_103: ShaderMaterial = material_45
	var material_104: ShaderMaterial = material_45
	var material_105: ShaderMaterial = material_45
	var material_106: ShaderMaterial = material_45
	var material_107: ShaderMaterial = material_45
	var material_108: ShaderMaterial = material_45
	var material_109: ShaderMaterial = material_45
	var material_110: ShaderMaterial = material_45
	var material_111: ShaderMaterial = material_45
	var material_112: ShaderMaterial = material_45
	var material_113: ShaderMaterial = material_45
	var material_114: ShaderMaterial = material_45
	var material_115: ShaderMaterial = material_45
	var material_116: ShaderMaterial = material_45
	var material_117: ShaderMaterial = material_45
	var material_118: ShaderMaterial = operands[762].duplicate(false)
	var material_119: ShaderMaterial = operands[763].duplicate(false)
	var material_120: ShaderMaterial = material_118
	var material_121: ShaderMaterial = material_119
	var material_122: ShaderMaterial = material_118
	var material_123: ShaderMaterial = material_119
	var material_124: ShaderMaterial = material_118
	var material_125: ShaderMaterial = material_119
	var material_126: ShaderMaterial = material_118
	var material_127: ShaderMaterial = material_119
	var material_128: ShaderMaterial = material_118
	var material_129: ShaderMaterial = material_119
	var material_130: ShaderMaterial = material_118
	var material_131: ShaderMaterial = material_119
	var material_132: ShaderMaterial = material_118
	var material_133: ShaderMaterial = material_119
	var material_134: ShaderMaterial = material_118
	var material_135: ShaderMaterial = material_119
	var material_136: ShaderMaterial = material_118
	var material_137: ShaderMaterial = material_119
	var material_138: ShaderMaterial = material_118
	var material_139: ShaderMaterial = material_119
	var material_140: ShaderMaterial = material_118
	var material_141: ShaderMaterial = material_119
	var material_142: ShaderMaterial = material_118
	var material_143: ShaderMaterial = material_119
	var material_144: ShaderMaterial = material_118
	var material_145: ShaderMaterial = material_119
	var material_146: ShaderMaterial = material_118
	var material_147: ShaderMaterial = material_119
	var material_148: ShaderMaterial = material_118
	var material_149: ShaderMaterial = material_119
	var material_150: ShaderMaterial = material_118
	var material_151: ShaderMaterial = material_119
	var material_152: ShaderMaterial = material_118
	var material_153: ShaderMaterial = material_119
	var material_154: ShaderMaterial = material_118
	var material_155: ShaderMaterial = material_119
	var material_156: ShaderMaterial = material_118
	var material_157: ShaderMaterial = material_119
	var material_158: ShaderMaterial = material_118
	var material_159: ShaderMaterial = material_119
	var material_160: ShaderMaterial = material_118
	var material_161: ShaderMaterial = material_119
	var material_162: ShaderMaterial = material_118
	var material_163: ShaderMaterial = material_119
	var material_164: ShaderMaterial = material_118
	var material_165: ShaderMaterial = material_119
	var material_166: ShaderMaterial = operands[764].duplicate(false)
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
	node_28.name = "ElectricCore12"
	node_28.layers = operands[128]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_28.material_override = material_25
	if profile_details: Profile.end("liquid_node_material_override")
	node_28.cast_shadow = operands[129]
	node_28.custom_aabb = operands[130]
	node_28.set("instance_shader_parameters/factory_liquid_link_index", operands[131])
	node_28.mesh = operands[132]
	node_3.add_child(node_28)
	var node_29 := MeshInstance3D.new()
	node_29.name = "ElectricGlow12"
	node_29.layers = operands[133]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_29.material_override = material_26
	if profile_details: Profile.end("liquid_node_material_override")
	node_29.cast_shadow = operands[134]
	node_29.custom_aabb = operands[135]
	node_29.set("instance_shader_parameters/factory_liquid_link_index", operands[136])
	node_29.mesh = operands[137]
	node_3.add_child(node_29)
	var node_30 := MeshInstance3D.new()
	node_30.name = "ElectricCore13"
	node_30.layers = operands[138]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_30.material_override = material_27
	if profile_details: Profile.end("liquid_node_material_override")
	node_30.cast_shadow = operands[139]
	node_30.custom_aabb = operands[140]
	node_30.set("instance_shader_parameters/factory_liquid_link_index", operands[141])
	node_30.mesh = operands[142]
	node_3.add_child(node_30)
	var node_31 := MeshInstance3D.new()
	node_31.name = "ElectricGlow13"
	node_31.layers = operands[143]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_31.material_override = material_28
	if profile_details: Profile.end("liquid_node_material_override")
	node_31.cast_shadow = operands[144]
	node_31.custom_aabb = operands[145]
	node_31.set("instance_shader_parameters/factory_liquid_link_index", operands[146])
	node_31.mesh = operands[147]
	node_3.add_child(node_31)
	var node_32 := MeshInstance3D.new()
	node_32.name = "ElectricCore14"
	node_32.layers = operands[148]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_32.material_override = material_29
	if profile_details: Profile.end("liquid_node_material_override")
	node_32.cast_shadow = operands[149]
	node_32.custom_aabb = operands[150]
	node_32.set("instance_shader_parameters/factory_liquid_link_index", operands[151])
	node_32.mesh = operands[152]
	node_3.add_child(node_32)
	var node_33 := MeshInstance3D.new()
	node_33.name = "ElectricGlow14"
	node_33.layers = operands[153]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_33.material_override = material_30
	if profile_details: Profile.end("liquid_node_material_override")
	node_33.cast_shadow = operands[154]
	node_33.custom_aabb = operands[155]
	node_33.set("instance_shader_parameters/factory_liquid_link_index", operands[156])
	node_33.mesh = operands[157]
	node_3.add_child(node_33)
	var node_34 := MeshInstance3D.new()
	node_34.name = "ElectricCore15"
	node_34.layers = operands[158]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_34.material_override = material_31
	if profile_details: Profile.end("liquid_node_material_override")
	node_34.cast_shadow = operands[159]
	node_34.custom_aabb = operands[160]
	node_34.set("instance_shader_parameters/factory_liquid_link_index", operands[161])
	node_34.mesh = operands[162]
	node_3.add_child(node_34)
	var node_35 := MeshInstance3D.new()
	node_35.name = "ElectricGlow15"
	node_35.layers = operands[163]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_35.material_override = material_32
	if profile_details: Profile.end("liquid_node_material_override")
	node_35.cast_shadow = operands[164]
	node_35.custom_aabb = operands[165]
	node_35.set("instance_shader_parameters/factory_liquid_link_index", operands[166])
	node_35.mesh = operands[167]
	node_3.add_child(node_35)
	var node_36 := MeshInstance3D.new()
	node_36.name = "ElectricCore16"
	node_36.layers = operands[168]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_36.material_override = material_33
	if profile_details: Profile.end("liquid_node_material_override")
	node_36.cast_shadow = operands[169]
	node_36.custom_aabb = operands[170]
	node_36.set("instance_shader_parameters/factory_liquid_link_index", operands[171])
	node_36.mesh = operands[172]
	node_3.add_child(node_36)
	var node_37 := MeshInstance3D.new()
	node_37.name = "ElectricGlow16"
	node_37.layers = operands[173]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_37.material_override = material_34
	if profile_details: Profile.end("liquid_node_material_override")
	node_37.cast_shadow = operands[174]
	node_37.custom_aabb = operands[175]
	node_37.set("instance_shader_parameters/factory_liquid_link_index", operands[176])
	node_37.mesh = operands[177]
	node_3.add_child(node_37)
	var node_38 := MeshInstance3D.new()
	node_38.name = "ElectricCore17"
	node_38.layers = operands[178]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_38.material_override = material_35
	if profile_details: Profile.end("liquid_node_material_override")
	node_38.cast_shadow = operands[179]
	node_38.custom_aabb = operands[180]
	node_38.set("instance_shader_parameters/factory_liquid_link_index", operands[181])
	node_38.mesh = operands[182]
	node_3.add_child(node_38)
	var node_39 := MeshInstance3D.new()
	node_39.name = "ElectricGlow17"
	node_39.layers = operands[183]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_39.material_override = material_36
	if profile_details: Profile.end("liquid_node_material_override")
	node_39.cast_shadow = operands[184]
	node_39.custom_aabb = operands[185]
	node_39.set("instance_shader_parameters/factory_liquid_link_index", operands[186])
	node_39.mesh = operands[187]
	node_3.add_child(node_39)
	var node_40 := MeshInstance3D.new()
	node_40.name = "ElectricCore18"
	node_40.layers = operands[188]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_40.material_override = material_37
	if profile_details: Profile.end("liquid_node_material_override")
	node_40.cast_shadow = operands[189]
	node_40.custom_aabb = operands[190]
	node_40.set("instance_shader_parameters/factory_liquid_link_index", operands[191])
	node_40.mesh = operands[192]
	node_3.add_child(node_40)
	var node_41 := MeshInstance3D.new()
	node_41.name = "ElectricGlow18"
	node_41.layers = operands[193]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_41.material_override = material_38
	if profile_details: Profile.end("liquid_node_material_override")
	node_41.cast_shadow = operands[194]
	node_41.custom_aabb = operands[195]
	node_41.set("instance_shader_parameters/factory_liquid_link_index", operands[196])
	node_41.mesh = operands[197]
	node_3.add_child(node_41)
	var node_42 := MeshInstance3D.new()
	node_42.name = "ElectricCore19"
	node_42.layers = operands[198]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_42.material_override = material_39
	if profile_details: Profile.end("liquid_node_material_override")
	node_42.cast_shadow = operands[199]
	node_42.custom_aabb = operands[200]
	node_42.set("instance_shader_parameters/factory_liquid_link_index", operands[201])
	node_42.mesh = operands[202]
	node_3.add_child(node_42)
	var node_43 := MeshInstance3D.new()
	node_43.name = "ElectricGlow19"
	node_43.layers = operands[203]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_43.material_override = material_40
	if profile_details: Profile.end("liquid_node_material_override")
	node_43.cast_shadow = operands[204]
	node_43.custom_aabb = operands[205]
	node_43.set("instance_shader_parameters/factory_liquid_link_index", operands[206])
	node_43.mesh = operands[207]
	node_3.add_child(node_43)
	var node_44 := MeshInstance3D.new()
	node_44.name = "ElectricCore20"
	node_44.layers = operands[208]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_44.material_override = material_41
	if profile_details: Profile.end("liquid_node_material_override")
	node_44.cast_shadow = operands[209]
	node_44.custom_aabb = operands[210]
	node_44.set("instance_shader_parameters/factory_liquid_link_index", operands[211])
	node_44.mesh = operands[212]
	node_3.add_child(node_44)
	var node_45 := MeshInstance3D.new()
	node_45.name = "ElectricGlow20"
	node_45.layers = operands[213]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_45.material_override = material_42
	if profile_details: Profile.end("liquid_node_material_override")
	node_45.cast_shadow = operands[214]
	node_45.custom_aabb = operands[215]
	node_45.set("instance_shader_parameters/factory_liquid_link_index", operands[216])
	node_45.mesh = operands[217]
	node_3.add_child(node_45)
	var node_46 := MeshInstance3D.new()
	node_46.name = "ElectricCore21"
	node_46.layers = operands[218]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_46.material_override = material_43
	if profile_details: Profile.end("liquid_node_material_override")
	node_46.cast_shadow = operands[219]
	node_46.custom_aabb = operands[220]
	node_46.set("instance_shader_parameters/factory_liquid_link_index", operands[221])
	node_46.mesh = operands[222]
	node_3.add_child(node_46)
	var node_47 := MeshInstance3D.new()
	node_47.name = "ElectricGlow21"
	node_47.layers = operands[223]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_47.material_override = material_44
	if profile_details: Profile.end("liquid_node_material_override")
	node_47.cast_shadow = operands[224]
	node_47.custom_aabb = operands[225]
	node_47.set("instance_shader_parameters/factory_liquid_link_index", operands[226])
	node_47.mesh = operands[227]
	node_3.add_child(node_47)
	var node_48 := MeshInstance3D.new()
	node_48.name = "MeasuredContactArcs0"
	node_48.visible = operands[228]
	node_48.layers = operands[229]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_48.material_override = material_45
	if profile_details: Profile.end("liquid_node_material_override")
	node_48.cast_shadow = operands[230]
	node_48.custom_aabb = operands[231]
	node_48.mesh = operands[232]
	node_3.add_child(node_48)
	var node_49 := MeshInstance3D.new()
	node_49.name = "SourceHandCoils"
	node_49.layers = operands[233]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_49.material_override = material_46
	if profile_details: Profile.end("liquid_node_material_override")
	node_49.cast_shadow = operands[234]
	node_49.custom_aabb = operands[235]
	node_49.mesh = operands[236]
	node_3.add_child(node_49)
	var node_50 := MeshInstance3D.new()
	node_50.name = "FactoryGenerated_0046_MeshInstance3D"
	node_50.layers = operands[237]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_50.material_override = material_47
	if profile_details: Profile.end("liquid_node_material_override")
	node_50.cast_shadow = operands[238]
	node_50.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[239])
	node_50.mesh = operands[240]
	node_3.add_child(node_50)
	var node_51 := MeshInstance3D.new()
	node_51.name = "FactoryGenerated_0047_MeshInstance3D"
	node_51.layers = operands[241]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_51.material_override = material_48
	if profile_details: Profile.end("liquid_node_material_override")
	node_51.cast_shadow = operands[242]
	node_51.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[243])
	node_51.mesh = operands[244]
	node_3.add_child(node_51)
	var node_52 := MeshInstance3D.new()
	node_52.name = "FactoryGenerated_0048_MeshInstance3D"
	node_52.layers = operands[245]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_52.material_override = material_49
	if profile_details: Profile.end("liquid_node_material_override")
	node_52.cast_shadow = operands[246]
	node_52.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[247])
	node_52.mesh = operands[248]
	node_3.add_child(node_52)
	var node_53 := MeshInstance3D.new()
	node_53.name = "FactoryGenerated_0049_MeshInstance3D"
	node_53.layers = operands[249]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_53.material_override = material_50
	if profile_details: Profile.end("liquid_node_material_override")
	node_53.cast_shadow = operands[250]
	node_53.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[251])
	node_53.mesh = operands[252]
	node_3.add_child(node_53)
	var node_54 := MeshInstance3D.new()
	node_54.name = "FactoryGenerated_0050_MeshInstance3D"
	node_54.layers = operands[253]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_54.material_override = material_51
	if profile_details: Profile.end("liquid_node_material_override")
	node_54.cast_shadow = operands[254]
	node_54.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[255])
	node_54.mesh = operands[256]
	node_3.add_child(node_54)
	var node_55 := MeshInstance3D.new()
	node_55.name = "FactoryGenerated_0051_MeshInstance3D"
	node_55.layers = operands[257]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_55.material_override = material_52
	if profile_details: Profile.end("liquid_node_material_override")
	node_55.cast_shadow = operands[258]
	node_55.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[259])
	node_55.mesh = operands[260]
	node_3.add_child(node_55)
	var node_56 := MeshInstance3D.new()
	node_56.name = "FactoryGenerated_0052_MeshInstance3D"
	node_56.layers = operands[261]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_56.material_override = material_53
	if profile_details: Profile.end("liquid_node_material_override")
	node_56.cast_shadow = operands[262]
	node_56.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[263])
	node_56.mesh = operands[264]
	node_3.add_child(node_56)
	var node_57 := MeshInstance3D.new()
	node_57.name = "FactoryGenerated_0053_MeshInstance3D"
	node_57.layers = operands[265]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_57.material_override = material_54
	if profile_details: Profile.end("liquid_node_material_override")
	node_57.cast_shadow = operands[266]
	node_57.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[267])
	node_57.mesh = operands[268]
	node_3.add_child(node_57)
	var node_58 := MeshInstance3D.new()
	node_58.name = "FactoryGenerated_0054_MeshInstance3D"
	node_58.layers = operands[269]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_58.material_override = material_55
	if profile_details: Profile.end("liquid_node_material_override")
	node_58.cast_shadow = operands[270]
	node_58.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[271])
	node_58.mesh = operands[272]
	node_3.add_child(node_58)
	var node_59 := MeshInstance3D.new()
	node_59.name = "FactoryGenerated_0055_MeshInstance3D"
	node_59.layers = operands[273]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_59.material_override = material_56
	if profile_details: Profile.end("liquid_node_material_override")
	node_59.cast_shadow = operands[274]
	node_59.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[275])
	node_59.mesh = operands[276]
	node_3.add_child(node_59)
	var node_60 := MeshInstance3D.new()
	node_60.name = "FactoryGenerated_0056_MeshInstance3D"
	node_60.layers = operands[277]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_60.material_override = material_57
	if profile_details: Profile.end("liquid_node_material_override")
	node_60.cast_shadow = operands[278]
	node_60.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[279])
	node_60.mesh = operands[280]
	node_3.add_child(node_60)
	var node_61 := MeshInstance3D.new()
	node_61.name = "FactoryGenerated_0057_MeshInstance3D"
	node_61.layers = operands[281]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_61.material_override = material_58
	if profile_details: Profile.end("liquid_node_material_override")
	node_61.cast_shadow = operands[282]
	node_61.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[283])
	node_61.mesh = operands[284]
	node_3.add_child(node_61)
	var node_62 := MeshInstance3D.new()
	node_62.name = "FactoryGenerated_0058_MeshInstance3D"
	node_62.layers = operands[285]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_62.material_override = material_59
	if profile_details: Profile.end("liquid_node_material_override")
	node_62.cast_shadow = operands[286]
	node_62.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[287])
	node_62.mesh = operands[288]
	node_3.add_child(node_62)
	var node_63 := MeshInstance3D.new()
	node_63.name = "FactoryGenerated_0059_MeshInstance3D"
	node_63.layers = operands[289]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_63.material_override = material_60
	if profile_details: Profile.end("liquid_node_material_override")
	node_63.cast_shadow = operands[290]
	node_63.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[291])
	node_63.mesh = operands[292]
	node_3.add_child(node_63)
	var node_64 := MeshInstance3D.new()
	node_64.name = "FactoryGenerated_0060_MeshInstance3D"
	node_64.layers = operands[293]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_64.material_override = material_61
	if profile_details: Profile.end("liquid_node_material_override")
	node_64.cast_shadow = operands[294]
	node_64.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[295])
	node_64.mesh = operands[296]
	node_3.add_child(node_64)
	var node_65 := MeshInstance3D.new()
	node_65.name = "FactoryGenerated_0061_MeshInstance3D"
	node_65.layers = operands[297]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_65.material_override = material_62
	if profile_details: Profile.end("liquid_node_material_override")
	node_65.cast_shadow = operands[298]
	node_65.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[299])
	node_65.mesh = operands[300]
	node_3.add_child(node_65)
	var node_66 := MeshInstance3D.new()
	node_66.name = "FactoryGenerated_0062_MeshInstance3D"
	node_66.layers = operands[301]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_66.material_override = material_63
	if profile_details: Profile.end("liquid_node_material_override")
	node_66.cast_shadow = operands[302]
	node_66.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[303])
	node_66.mesh = operands[304]
	node_3.add_child(node_66)
	var node_67 := MeshInstance3D.new()
	node_67.name = "FactoryGenerated_0063_MeshInstance3D"
	node_67.layers = operands[305]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_67.material_override = material_64
	if profile_details: Profile.end("liquid_node_material_override")
	node_67.cast_shadow = operands[306]
	node_67.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[307])
	node_67.mesh = operands[308]
	node_3.add_child(node_67)
	var node_68 := MeshInstance3D.new()
	node_68.name = "FactoryGenerated_0064_MeshInstance3D"
	node_68.layers = operands[309]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_68.material_override = material_65
	if profile_details: Profile.end("liquid_node_material_override")
	node_68.cast_shadow = operands[310]
	node_68.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[311])
	node_68.mesh = operands[312]
	node_3.add_child(node_68)
	var node_69 := MeshInstance3D.new()
	node_69.name = "FactoryGenerated_0065_MeshInstance3D"
	node_69.layers = operands[313]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_69.material_override = material_66
	if profile_details: Profile.end("liquid_node_material_override")
	node_69.cast_shadow = operands[314]
	node_69.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[315])
	node_69.mesh = operands[316]
	node_3.add_child(node_69)
	var node_70 := MeshInstance3D.new()
	node_70.name = "FactoryGenerated_0066_MeshInstance3D"
	node_70.layers = operands[317]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_70.material_override = material_67
	if profile_details: Profile.end("liquid_node_material_override")
	node_70.cast_shadow = operands[318]
	node_70.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[319])
	node_70.mesh = operands[320]
	node_3.add_child(node_70)
	var node_71 := MeshInstance3D.new()
	node_71.name = "FactoryGenerated_0067_MeshInstance3D"
	node_71.layers = operands[321]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_71.material_override = material_68
	if profile_details: Profile.end("liquid_node_material_override")
	node_71.cast_shadow = operands[322]
	node_71.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[323])
	node_71.mesh = operands[324]
	node_3.add_child(node_71)
	var node_72 := MeshInstance3D.new()
	node_72.name = "FactoryGenerated_0068_MeshInstance3D"
	node_72.layers = operands[325]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_72.material_override = material_69
	if profile_details: Profile.end("liquid_node_material_override")
	node_72.cast_shadow = operands[326]
	node_72.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[327])
	node_72.mesh = operands[328]
	node_3.add_child(node_72)
	var node_73 := MeshInstance3D.new()
	node_73.name = "FactoryGenerated_0069_MeshInstance3D"
	node_73.layers = operands[329]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_73.material_override = material_70
	if profile_details: Profile.end("liquid_node_material_override")
	node_73.cast_shadow = operands[330]
	node_73.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[331])
	node_73.mesh = operands[332]
	node_3.add_child(node_73)
	var node_74 := MeshInstance3D.new()
	node_74.name = "FactoryGenerated_0070_MeshInstance3D"
	node_74.layers = operands[333]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_74.material_override = material_71
	if profile_details: Profile.end("liquid_node_material_override")
	node_74.cast_shadow = operands[334]
	node_74.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[335])
	node_74.mesh = operands[336]
	node_3.add_child(node_74)
	var node_75 := MeshInstance3D.new()
	node_75.name = "FactoryGenerated_0071_MeshInstance3D"
	node_75.layers = operands[337]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_75.material_override = material_72
	if profile_details: Profile.end("liquid_node_material_override")
	node_75.cast_shadow = operands[338]
	node_75.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[339])
	node_75.mesh = operands[340]
	node_3.add_child(node_75)
	var node_76 := MeshInstance3D.new()
	node_76.name = "FactoryGenerated_0072_MeshInstance3D"
	node_76.layers = operands[341]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_76.material_override = material_73
	if profile_details: Profile.end("liquid_node_material_override")
	node_76.cast_shadow = operands[342]
	node_76.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[343])
	node_76.mesh = operands[344]
	node_3.add_child(node_76)
	var node_77 := MeshInstance3D.new()
	node_77.name = "FactoryGenerated_0073_MeshInstance3D"
	node_77.layers = operands[345]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_77.material_override = material_74
	if profile_details: Profile.end("liquid_node_material_override")
	node_77.cast_shadow = operands[346]
	node_77.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[347])
	node_77.mesh = operands[348]
	node_3.add_child(node_77)
	var node_78 := MeshInstance3D.new()
	node_78.name = "FactoryGenerated_0074_MeshInstance3D"
	node_78.layers = operands[349]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_78.material_override = material_75
	if profile_details: Profile.end("liquid_node_material_override")
	node_78.cast_shadow = operands[350]
	node_78.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[351])
	node_78.mesh = operands[352]
	node_3.add_child(node_78)
	var node_79 := MeshInstance3D.new()
	node_79.name = "FactoryGenerated_0075_MeshInstance3D"
	node_79.layers = operands[353]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_79.material_override = material_76
	if profile_details: Profile.end("liquid_node_material_override")
	node_79.cast_shadow = operands[354]
	node_79.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[355])
	node_79.mesh = operands[356]
	node_3.add_child(node_79)
	var node_80 := MeshInstance3D.new()
	node_80.name = "FactoryGenerated_0076_MeshInstance3D"
	node_80.layers = operands[357]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_80.material_override = material_77
	if profile_details: Profile.end("liquid_node_material_override")
	node_80.cast_shadow = operands[358]
	node_80.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[359])
	node_80.mesh = operands[360]
	node_3.add_child(node_80)
	var node_81 := MeshInstance3D.new()
	node_81.name = "FactoryGenerated_0077_MeshInstance3D"
	node_81.layers = operands[361]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_81.material_override = material_78
	if profile_details: Profile.end("liquid_node_material_override")
	node_81.cast_shadow = operands[362]
	node_81.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[363])
	node_81.mesh = operands[364]
	node_3.add_child(node_81)
	var node_82 := MeshInstance3D.new()
	node_82.name = "FactoryGenerated_0078_MeshInstance3D"
	node_82.layers = operands[365]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_82.material_override = material_79
	if profile_details: Profile.end("liquid_node_material_override")
	node_82.cast_shadow = operands[366]
	node_82.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[367])
	node_82.mesh = operands[368]
	node_3.add_child(node_82)
	var node_83 := MeshInstance3D.new()
	node_83.name = "FactoryGenerated_0079_MeshInstance3D"
	node_83.layers = operands[369]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_83.material_override = material_80
	if profile_details: Profile.end("liquid_node_material_override")
	node_83.cast_shadow = operands[370]
	node_83.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[371])
	node_83.mesh = operands[372]
	node_3.add_child(node_83)
	var node_84 := MeshInstance3D.new()
	node_84.name = "FactoryGenerated_0080_MeshInstance3D"
	node_84.layers = operands[373]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_84.material_override = material_81
	if profile_details: Profile.end("liquid_node_material_override")
	node_84.cast_shadow = operands[374]
	node_84.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[375])
	node_84.mesh = operands[376]
	node_3.add_child(node_84)
	var node_85 := MeshInstance3D.new()
	node_85.name = "FactoryGenerated_0081_MeshInstance3D"
	node_85.layers = operands[377]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_85.material_override = material_82
	if profile_details: Profile.end("liquid_node_material_override")
	node_85.cast_shadow = operands[378]
	node_85.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[379])
	node_85.mesh = operands[380]
	node_3.add_child(node_85)
	var node_86 := MeshInstance3D.new()
	node_86.name = "FactoryGenerated_0082_MeshInstance3D"
	node_86.layers = operands[381]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_86.material_override = material_83
	if profile_details: Profile.end("liquid_node_material_override")
	node_86.cast_shadow = operands[382]
	node_86.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[383])
	node_86.mesh = operands[384]
	node_3.add_child(node_86)
	var node_87 := MeshInstance3D.new()
	node_87.name = "FactoryGenerated_0083_MeshInstance3D"
	node_87.layers = operands[385]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_87.material_override = material_84
	if profile_details: Profile.end("liquid_node_material_override")
	node_87.cast_shadow = operands[386]
	node_87.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[387])
	node_87.mesh = operands[388]
	node_3.add_child(node_87)
	var node_88 := MeshInstance3D.new()
	node_88.name = "FactoryGenerated_0084_MeshInstance3D"
	node_88.layers = operands[389]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_88.material_override = material_85
	if profile_details: Profile.end("liquid_node_material_override")
	node_88.cast_shadow = operands[390]
	node_88.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[391])
	node_88.mesh = operands[392]
	node_3.add_child(node_88)
	var node_89 := MeshInstance3D.new()
	node_89.name = "FactoryGenerated_0085_MeshInstance3D"
	node_89.layers = operands[393]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_89.material_override = material_86
	if profile_details: Profile.end("liquid_node_material_override")
	node_89.cast_shadow = operands[394]
	node_89.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[395])
	node_89.mesh = operands[396]
	node_3.add_child(node_89)
	var node_90 := MeshInstance3D.new()
	node_90.name = "FactoryGenerated_0086_MeshInstance3D"
	node_90.layers = operands[397]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_90.material_override = material_87
	if profile_details: Profile.end("liquid_node_material_override")
	node_90.cast_shadow = operands[398]
	node_90.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[399])
	node_90.mesh = operands[400]
	node_3.add_child(node_90)
	var node_91 := MeshInstance3D.new()
	node_91.name = "FactoryGenerated_0087_MeshInstance3D"
	node_91.layers = operands[401]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_91.material_override = material_88
	if profile_details: Profile.end("liquid_node_material_override")
	node_91.cast_shadow = operands[402]
	node_91.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[403])
	node_91.mesh = operands[404]
	node_3.add_child(node_91)
	var node_92 := MeshInstance3D.new()
	node_92.name = "FactoryGenerated_0088_MeshInstance3D"
	node_92.layers = operands[405]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_92.material_override = material_89
	if profile_details: Profile.end("liquid_node_material_override")
	node_92.cast_shadow = operands[406]
	node_92.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[407])
	node_92.mesh = operands[408]
	node_3.add_child(node_92)
	var node_93 := MeshInstance3D.new()
	node_93.name = "FactoryGenerated_0089_MeshInstance3D"
	node_93.layers = operands[409]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_93.material_override = material_90
	if profile_details: Profile.end("liquid_node_material_override")
	node_93.cast_shadow = operands[410]
	node_93.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[411])
	node_93.mesh = operands[412]
	node_3.add_child(node_93)
	var node_94 := MeshInstance3D.new()
	node_94.name = "FactoryGenerated_0090_MeshInstance3D"
	node_94.layers = operands[413]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_94.material_override = material_91
	if profile_details: Profile.end("liquid_node_material_override")
	node_94.cast_shadow = operands[414]
	node_94.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[415])
	node_94.mesh = operands[416]
	node_3.add_child(node_94)
	var node_95 := MeshInstance3D.new()
	node_95.name = "FactoryGenerated_0091_MeshInstance3D"
	node_95.layers = operands[417]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_95.material_override = material_92
	if profile_details: Profile.end("liquid_node_material_override")
	node_95.cast_shadow = operands[418]
	node_95.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[419])
	node_95.mesh = operands[420]
	node_3.add_child(node_95)
	var node_96 := MeshInstance3D.new()
	node_96.name = "FactoryGenerated_0092_MeshInstance3D"
	node_96.layers = operands[421]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_96.material_override = material_93
	if profile_details: Profile.end("liquid_node_material_override")
	node_96.cast_shadow = operands[422]
	node_96.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[423])
	node_96.mesh = operands[424]
	node_3.add_child(node_96)
	var node_97 := MeshInstance3D.new()
	node_97.name = "FactoryGenerated_0093_MeshInstance3D"
	node_97.layers = operands[425]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_97.material_override = material_94
	if profile_details: Profile.end("liquid_node_material_override")
	node_97.cast_shadow = operands[426]
	node_97.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[427])
	node_97.mesh = operands[428]
	node_3.add_child(node_97)
	var node_98 := MeshInstance3D.new()
	node_98.name = "FactoryGenerated_0094_MeshInstance3D"
	node_98.layers = operands[429]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_98.material_override = material_95
	if profile_details: Profile.end("liquid_node_material_override")
	node_98.cast_shadow = operands[430]
	node_98.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[431])
	node_98.mesh = operands[432]
	node_3.add_child(node_98)
	var node_99 := MeshInstance3D.new()
	node_99.name = "FactoryGenerated_0095_MeshInstance3D"
	node_99.layers = operands[433]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_99.material_override = material_96
	if profile_details: Profile.end("liquid_node_material_override")
	node_99.cast_shadow = operands[434]
	node_99.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[435])
	node_99.mesh = operands[436]
	node_3.add_child(node_99)
	var node_100 := MeshInstance3D.new()
	node_100.name = "FactoryGenerated_0096_MeshInstance3D"
	node_100.layers = operands[437]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_100.material_override = material_97
	if profile_details: Profile.end("liquid_node_material_override")
	node_100.cast_shadow = operands[438]
	node_100.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[439])
	node_100.mesh = operands[440]
	node_3.add_child(node_100)
	var node_101 := MeshInstance3D.new()
	node_101.name = "FactoryGenerated_0097_MeshInstance3D"
	node_101.layers = operands[441]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_101.material_override = material_98
	if profile_details: Profile.end("liquid_node_material_override")
	node_101.cast_shadow = operands[442]
	node_101.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[443])
	node_101.mesh = operands[444]
	node_3.add_child(node_101)
	var node_102 := MeshInstance3D.new()
	node_102.name = "FactoryGenerated_0098_MeshInstance3D"
	node_102.layers = operands[445]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_102.material_override = material_99
	if profile_details: Profile.end("liquid_node_material_override")
	node_102.cast_shadow = operands[446]
	node_102.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[447])
	node_102.mesh = operands[448]
	node_3.add_child(node_102)
	var node_103 := MeshInstance3D.new()
	node_103.name = "FactoryGenerated_0099_MeshInstance3D"
	node_103.layers = operands[449]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_103.material_override = material_100
	if profile_details: Profile.end("liquid_node_material_override")
	node_103.cast_shadow = operands[450]
	node_103.set("instance_shader_parameters/factory_liquid_contact_alpha", operands[451])
	node_103.mesh = operands[452]
	node_3.add_child(node_103)
	var node_104 := MeshInstance3D.new()
	node_104.name = "MeasuredContactArcs1"
	node_104.visible = operands[453]
	node_104.layers = operands[454]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_104.material_override = material_101
	if profile_details: Profile.end("liquid_node_material_override")
	node_104.cast_shadow = operands[455]
	node_104.custom_aabb = operands[456]
	node_104.mesh = operands[457]
	node_3.add_child(node_104)
	var node_105 := MeshInstance3D.new()
	node_105.name = "MeasuredContactArcs2"
	node_105.visible = operands[458]
	node_105.layers = operands[459]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_105.material_override = material_102
	if profile_details: Profile.end("liquid_node_material_override")
	node_105.cast_shadow = operands[460]
	node_105.custom_aabb = operands[461]
	node_105.mesh = operands[462]
	node_3.add_child(node_105)
	var node_106 := MeshInstance3D.new()
	node_106.name = "MeasuredContactArcs3"
	node_106.visible = operands[463]
	node_106.layers = operands[464]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_106.material_override = material_103
	if profile_details: Profile.end("liquid_node_material_override")
	node_106.cast_shadow = operands[465]
	node_106.custom_aabb = operands[466]
	node_106.mesh = operands[467]
	node_3.add_child(node_106)
	var node_107 := MeshInstance3D.new()
	node_107.name = "MeasuredContactArcs4"
	node_107.visible = operands[468]
	node_107.layers = operands[469]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_107.material_override = material_104
	if profile_details: Profile.end("liquid_node_material_override")
	node_107.cast_shadow = operands[470]
	node_107.custom_aabb = operands[471]
	node_107.mesh = operands[472]
	node_3.add_child(node_107)
	var node_108 := MeshInstance3D.new()
	node_108.name = "MeasuredContactArcs5"
	node_108.visible = operands[473]
	node_108.layers = operands[474]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_108.material_override = material_105
	if profile_details: Profile.end("liquid_node_material_override")
	node_108.cast_shadow = operands[475]
	node_108.custom_aabb = operands[476]
	node_108.mesh = operands[477]
	node_3.add_child(node_108)
	var node_109 := MeshInstance3D.new()
	node_109.name = "MeasuredContactArcs6"
	node_109.visible = operands[478]
	node_109.layers = operands[479]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_109.material_override = material_106
	if profile_details: Profile.end("liquid_node_material_override")
	node_109.cast_shadow = operands[480]
	node_109.custom_aabb = operands[481]
	node_109.mesh = operands[482]
	node_3.add_child(node_109)
	var node_110 := MeshInstance3D.new()
	node_110.name = "MeasuredContactArcs7"
	node_110.visible = operands[483]
	node_110.layers = operands[484]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_110.material_override = material_107
	if profile_details: Profile.end("liquid_node_material_override")
	node_110.cast_shadow = operands[485]
	node_110.custom_aabb = operands[486]
	node_110.mesh = operands[487]
	node_3.add_child(node_110)
	var node_111 := MeshInstance3D.new()
	node_111.name = "MeasuredContactArcs8"
	node_111.visible = operands[488]
	node_111.layers = operands[489]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_111.material_override = material_108
	if profile_details: Profile.end("liquid_node_material_override")
	node_111.cast_shadow = operands[490]
	node_111.custom_aabb = operands[491]
	node_111.mesh = operands[492]
	node_3.add_child(node_111)
	var node_112 := MeshInstance3D.new()
	node_112.name = "MeasuredContactArcs9"
	node_112.visible = operands[493]
	node_112.layers = operands[494]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_112.material_override = material_109
	if profile_details: Profile.end("liquid_node_material_override")
	node_112.cast_shadow = operands[495]
	node_112.custom_aabb = operands[496]
	node_112.mesh = operands[497]
	node_3.add_child(node_112)
	var node_113 := MeshInstance3D.new()
	node_113.name = "MeasuredContactArcs10"
	node_113.visible = operands[498]
	node_113.layers = operands[499]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_113.material_override = material_110
	if profile_details: Profile.end("liquid_node_material_override")
	node_113.cast_shadow = operands[500]
	node_113.custom_aabb = operands[501]
	node_113.mesh = operands[502]
	node_3.add_child(node_113)
	var node_114 := MeshInstance3D.new()
	node_114.name = "MeasuredContactArcs11"
	node_114.visible = operands[503]
	node_114.layers = operands[504]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_114.material_override = material_111
	if profile_details: Profile.end("liquid_node_material_override")
	node_114.cast_shadow = operands[505]
	node_114.custom_aabb = operands[506]
	node_114.mesh = operands[507]
	node_3.add_child(node_114)
	var node_115 := MeshInstance3D.new()
	node_115.name = "MeasuredContactArcs12"
	node_115.visible = operands[508]
	node_115.layers = operands[509]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_115.material_override = material_112
	if profile_details: Profile.end("liquid_node_material_override")
	node_115.cast_shadow = operands[510]
	node_115.custom_aabb = operands[511]
	node_115.mesh = operands[512]
	node_3.add_child(node_115)
	var node_116 := MeshInstance3D.new()
	node_116.name = "MeasuredContactArcs13"
	node_116.visible = operands[513]
	node_116.layers = operands[514]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_116.material_override = material_113
	if profile_details: Profile.end("liquid_node_material_override")
	node_116.cast_shadow = operands[515]
	node_116.custom_aabb = operands[516]
	node_116.mesh = operands[517]
	node_3.add_child(node_116)
	var node_117 := MeshInstance3D.new()
	node_117.name = "MeasuredContactArcs14"
	node_117.visible = operands[518]
	node_117.layers = operands[519]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_117.material_override = material_114
	if profile_details: Profile.end("liquid_node_material_override")
	node_117.cast_shadow = operands[520]
	node_117.custom_aabb = operands[521]
	node_117.mesh = operands[522]
	node_3.add_child(node_117)
	var node_118 := MeshInstance3D.new()
	node_118.name = "MeasuredContactArcs15"
	node_118.visible = operands[523]
	node_118.layers = operands[524]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_118.material_override = material_115
	if profile_details: Profile.end("liquid_node_material_override")
	node_118.cast_shadow = operands[525]
	node_118.custom_aabb = operands[526]
	node_118.mesh = operands[527]
	node_3.add_child(node_118)
	var node_119 := MeshInstance3D.new()
	node_119.name = "MeasuredContactArcs16"
	node_119.visible = operands[528]
	node_119.layers = operands[529]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_119.material_override = material_116
	if profile_details: Profile.end("liquid_node_material_override")
	node_119.cast_shadow = operands[530]
	node_119.custom_aabb = operands[531]
	node_119.mesh = operands[532]
	node_3.add_child(node_119)
	var node_120 := MeshInstance3D.new()
	node_120.name = "MeasuredContactArcs17"
	node_120.visible = operands[533]
	node_120.layers = operands[534]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_120.material_override = material_117
	if profile_details: Profile.end("liquid_node_material_override")
	node_120.cast_shadow = operands[535]
	node_120.custom_aabb = operands[536]
	node_120.mesh = operands[537]
	node_3.add_child(node_120)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_121 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_121.name = "SourceSteam_0"
	node_121.layers = operands[538]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_121.material_override = material_118
	if profile_details: Profile.end("liquid_node_material_override")
	node_121.cast_shadow = operands[539]
	node_121.emitting = operands[540]
	if profile_details: Profile.begin("liquid_node_amount")
	node_121.amount = operands[541]
	if profile_details: Profile.end("liquid_node_amount")
	node_121.lifetime = operands[542]
	node_121.use_fixed_seed = operands[543]
	node_121.seed = operands[544]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_121.fixed_fps = operands[545]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_121.process_material = material_119
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_121.draw_pass_1 = operands[546]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_121)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_122 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_122.name = "SourceSteam_1"
	node_122.layers = operands[547]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_122.material_override = material_120
	if profile_details: Profile.end("liquid_node_material_override")
	node_122.cast_shadow = operands[548]
	node_122.emitting = operands[549]
	if profile_details: Profile.begin("liquid_node_amount")
	node_122.amount = operands[550]
	if profile_details: Profile.end("liquid_node_amount")
	node_122.lifetime = operands[551]
	node_122.use_fixed_seed = operands[552]
	node_122.seed = operands[553]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_122.fixed_fps = operands[554]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_122.process_material = material_121
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_122.draw_pass_1 = operands[555]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_122)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_123 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_123.name = "SourceSteam_2"
	node_123.layers = operands[556]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_123.material_override = material_122
	if profile_details: Profile.end("liquid_node_material_override")
	node_123.cast_shadow = operands[557]
	node_123.emitting = operands[558]
	if profile_details: Profile.begin("liquid_node_amount")
	node_123.amount = operands[559]
	if profile_details: Profile.end("liquid_node_amount")
	node_123.lifetime = operands[560]
	node_123.use_fixed_seed = operands[561]
	node_123.seed = operands[562]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_123.fixed_fps = operands[563]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_123.process_material = material_123
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_123.draw_pass_1 = operands[564]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_123)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_124 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_124.name = "SourceSteam_3"
	node_124.layers = operands[565]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_124.material_override = material_124
	if profile_details: Profile.end("liquid_node_material_override")
	node_124.cast_shadow = operands[566]
	node_124.emitting = operands[567]
	if profile_details: Profile.begin("liquid_node_amount")
	node_124.amount = operands[568]
	if profile_details: Profile.end("liquid_node_amount")
	node_124.lifetime = operands[569]
	node_124.use_fixed_seed = operands[570]
	node_124.seed = operands[571]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_124.fixed_fps = operands[572]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_124.process_material = material_125
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_124.draw_pass_1 = operands[573]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_124)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_125 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_125.name = "SourceSteam_4"
	node_125.layers = operands[574]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_125.material_override = material_126
	if profile_details: Profile.end("liquid_node_material_override")
	node_125.cast_shadow = operands[575]
	node_125.emitting = operands[576]
	if profile_details: Profile.begin("liquid_node_amount")
	node_125.amount = operands[577]
	if profile_details: Profile.end("liquid_node_amount")
	node_125.lifetime = operands[578]
	node_125.use_fixed_seed = operands[579]
	node_125.seed = operands[580]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_125.fixed_fps = operands[581]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_125.process_material = material_127
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_125.draw_pass_1 = operands[582]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_125)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_126 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_126.name = "SourceSteam_5"
	node_126.layers = operands[583]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_126.material_override = material_128
	if profile_details: Profile.end("liquid_node_material_override")
	node_126.cast_shadow = operands[584]
	node_126.emitting = operands[585]
	if profile_details: Profile.begin("liquid_node_amount")
	node_126.amount = operands[586]
	if profile_details: Profile.end("liquid_node_amount")
	node_126.lifetime = operands[587]
	node_126.use_fixed_seed = operands[588]
	node_126.seed = operands[589]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_126.fixed_fps = operands[590]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_126.process_material = material_129
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_126.draw_pass_1 = operands[591]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_126)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_127 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_127.name = "SourceSteam_6"
	node_127.layers = operands[592]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_127.material_override = material_130
	if profile_details: Profile.end("liquid_node_material_override")
	node_127.cast_shadow = operands[593]
	node_127.emitting = operands[594]
	if profile_details: Profile.begin("liquid_node_amount")
	node_127.amount = operands[595]
	if profile_details: Profile.end("liquid_node_amount")
	node_127.lifetime = operands[596]
	node_127.use_fixed_seed = operands[597]
	node_127.seed = operands[598]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_127.fixed_fps = operands[599]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_127.process_material = material_131
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_127.draw_pass_1 = operands[600]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_127)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_128 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_128.name = "SourceSteam_7"
	node_128.layers = operands[601]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_128.material_override = material_132
	if profile_details: Profile.end("liquid_node_material_override")
	node_128.cast_shadow = operands[602]
	node_128.emitting = operands[603]
	if profile_details: Profile.begin("liquid_node_amount")
	node_128.amount = operands[604]
	if profile_details: Profile.end("liquid_node_amount")
	node_128.lifetime = operands[605]
	node_128.use_fixed_seed = operands[606]
	node_128.seed = operands[607]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_128.fixed_fps = operands[608]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_128.process_material = material_133
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_128.draw_pass_1 = operands[609]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_128)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_129 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_129.name = "SourceSteam_8"
	node_129.layers = operands[610]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_129.material_override = material_134
	if profile_details: Profile.end("liquid_node_material_override")
	node_129.cast_shadow = operands[611]
	node_129.emitting = operands[612]
	if profile_details: Profile.begin("liquid_node_amount")
	node_129.amount = operands[613]
	if profile_details: Profile.end("liquid_node_amount")
	node_129.lifetime = operands[614]
	node_129.use_fixed_seed = operands[615]
	node_129.seed = operands[616]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_129.fixed_fps = operands[617]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_129.process_material = material_135
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_129.draw_pass_1 = operands[618]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_129)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_130 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_130.name = "SourceSteam_9"
	node_130.layers = operands[619]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_130.material_override = material_136
	if profile_details: Profile.end("liquid_node_material_override")
	node_130.cast_shadow = operands[620]
	node_130.emitting = operands[621]
	if profile_details: Profile.begin("liquid_node_amount")
	node_130.amount = operands[622]
	if profile_details: Profile.end("liquid_node_amount")
	node_130.lifetime = operands[623]
	node_130.use_fixed_seed = operands[624]
	node_130.seed = operands[625]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_130.fixed_fps = operands[626]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_130.process_material = material_137
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_130.draw_pass_1 = operands[627]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_130)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_131 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_131.name = "SourceSteam_10"
	node_131.layers = operands[628]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_131.material_override = material_138
	if profile_details: Profile.end("liquid_node_material_override")
	node_131.cast_shadow = operands[629]
	node_131.emitting = operands[630]
	if profile_details: Profile.begin("liquid_node_amount")
	node_131.amount = operands[631]
	if profile_details: Profile.end("liquid_node_amount")
	node_131.lifetime = operands[632]
	node_131.use_fixed_seed = operands[633]
	node_131.seed = operands[634]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_131.fixed_fps = operands[635]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_131.process_material = material_139
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_131.draw_pass_1 = operands[636]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_131)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_132 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_132.name = "SourceSteam_11"
	node_132.layers = operands[637]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_132.material_override = material_140
	if profile_details: Profile.end("liquid_node_material_override")
	node_132.cast_shadow = operands[638]
	node_132.emitting = operands[639]
	if profile_details: Profile.begin("liquid_node_amount")
	node_132.amount = operands[640]
	if profile_details: Profile.end("liquid_node_amount")
	node_132.lifetime = operands[641]
	node_132.use_fixed_seed = operands[642]
	node_132.seed = operands[643]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_132.fixed_fps = operands[644]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_132.process_material = material_141
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_132.draw_pass_1 = operands[645]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_132)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_133 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_133.name = "SourceSteam_12"
	node_133.layers = operands[646]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_133.material_override = material_142
	if profile_details: Profile.end("liquid_node_material_override")
	node_133.cast_shadow = operands[647]
	node_133.emitting = operands[648]
	if profile_details: Profile.begin("liquid_node_amount")
	node_133.amount = operands[649]
	if profile_details: Profile.end("liquid_node_amount")
	node_133.lifetime = operands[650]
	node_133.use_fixed_seed = operands[651]
	node_133.seed = operands[652]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_133.fixed_fps = operands[653]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_133.process_material = material_143
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_133.draw_pass_1 = operands[654]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_133)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_134 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_134.name = "SourceSteam_13"
	node_134.layers = operands[655]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_134.material_override = material_144
	if profile_details: Profile.end("liquid_node_material_override")
	node_134.cast_shadow = operands[656]
	node_134.emitting = operands[657]
	if profile_details: Profile.begin("liquid_node_amount")
	node_134.amount = operands[658]
	if profile_details: Profile.end("liquid_node_amount")
	node_134.lifetime = operands[659]
	node_134.use_fixed_seed = operands[660]
	node_134.seed = operands[661]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_134.fixed_fps = operands[662]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_134.process_material = material_145
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_134.draw_pass_1 = operands[663]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_134)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_135 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_135.name = "SourceSteam_14"
	node_135.layers = operands[664]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_135.material_override = material_146
	if profile_details: Profile.end("liquid_node_material_override")
	node_135.cast_shadow = operands[665]
	node_135.emitting = operands[666]
	if profile_details: Profile.begin("liquid_node_amount")
	node_135.amount = operands[667]
	if profile_details: Profile.end("liquid_node_amount")
	node_135.lifetime = operands[668]
	node_135.use_fixed_seed = operands[669]
	node_135.seed = operands[670]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_135.fixed_fps = operands[671]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_135.process_material = material_147
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_135.draw_pass_1 = operands[672]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_135)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_136 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_136.name = "SourceSteam_15"
	node_136.layers = operands[673]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_136.material_override = material_148
	if profile_details: Profile.end("liquid_node_material_override")
	node_136.cast_shadow = operands[674]
	node_136.emitting = operands[675]
	if profile_details: Profile.begin("liquid_node_amount")
	node_136.amount = operands[676]
	if profile_details: Profile.end("liquid_node_amount")
	node_136.lifetime = operands[677]
	node_136.use_fixed_seed = operands[678]
	node_136.seed = operands[679]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_136.fixed_fps = operands[680]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_136.process_material = material_149
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_136.draw_pass_1 = operands[681]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_136)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_137 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_137.name = "SourceSteam_16"
	node_137.layers = operands[682]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_137.material_override = material_150
	if profile_details: Profile.end("liquid_node_material_override")
	node_137.cast_shadow = operands[683]
	node_137.emitting = operands[684]
	if profile_details: Profile.begin("liquid_node_amount")
	node_137.amount = operands[685]
	if profile_details: Profile.end("liquid_node_amount")
	node_137.lifetime = operands[686]
	node_137.use_fixed_seed = operands[687]
	node_137.seed = operands[688]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_137.fixed_fps = operands[689]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_137.process_material = material_151
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_137.draw_pass_1 = operands[690]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_137)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_138 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_138.name = "SourceSteam_17"
	node_138.layers = operands[691]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_138.material_override = material_152
	if profile_details: Profile.end("liquid_node_material_override")
	node_138.cast_shadow = operands[692]
	node_138.emitting = operands[693]
	if profile_details: Profile.begin("liquid_node_amount")
	node_138.amount = operands[694]
	if profile_details: Profile.end("liquid_node_amount")
	node_138.lifetime = operands[695]
	node_138.use_fixed_seed = operands[696]
	node_138.seed = operands[697]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_138.fixed_fps = operands[698]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_138.process_material = material_153
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_138.draw_pass_1 = operands[699]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_138)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_139 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_139.name = "SourceSteam_18"
	node_139.layers = operands[700]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_139.material_override = material_154
	if profile_details: Profile.end("liquid_node_material_override")
	node_139.cast_shadow = operands[701]
	node_139.emitting = operands[702]
	if profile_details: Profile.begin("liquid_node_amount")
	node_139.amount = operands[703]
	if profile_details: Profile.end("liquid_node_amount")
	node_139.lifetime = operands[704]
	node_139.use_fixed_seed = operands[705]
	node_139.seed = operands[706]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_139.fixed_fps = operands[707]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_139.process_material = material_155
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_139.draw_pass_1 = operands[708]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_139)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_140 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_140.name = "SourceSteam_19"
	node_140.layers = operands[709]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_140.material_override = material_156
	if profile_details: Profile.end("liquid_node_material_override")
	node_140.cast_shadow = operands[710]
	node_140.emitting = operands[711]
	if profile_details: Profile.begin("liquid_node_amount")
	node_140.amount = operands[712]
	if profile_details: Profile.end("liquid_node_amount")
	node_140.lifetime = operands[713]
	node_140.use_fixed_seed = operands[714]
	node_140.seed = operands[715]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_140.fixed_fps = operands[716]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_140.process_material = material_157
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_140.draw_pass_1 = operands[717]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_140)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_141 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_141.name = "SourceSteam_20"
	node_141.layers = operands[718]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_141.material_override = material_158
	if profile_details: Profile.end("liquid_node_material_override")
	node_141.cast_shadow = operands[719]
	node_141.emitting = operands[720]
	if profile_details: Profile.begin("liquid_node_amount")
	node_141.amount = operands[721]
	if profile_details: Profile.end("liquid_node_amount")
	node_141.lifetime = operands[722]
	node_141.use_fixed_seed = operands[723]
	node_141.seed = operands[724]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_141.fixed_fps = operands[725]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_141.process_material = material_159
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_141.draw_pass_1 = operands[726]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_141)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_142 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_142.name = "SourceSteam_21"
	node_142.layers = operands[727]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_142.material_override = material_160
	if profile_details: Profile.end("liquid_node_material_override")
	node_142.cast_shadow = operands[728]
	node_142.emitting = operands[729]
	if profile_details: Profile.begin("liquid_node_amount")
	node_142.amount = operands[730]
	if profile_details: Profile.end("liquid_node_amount")
	node_142.lifetime = operands[731]
	node_142.use_fixed_seed = operands[732]
	node_142.seed = operands[733]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_142.fixed_fps = operands[734]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_142.process_material = material_161
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_142.draw_pass_1 = operands[735]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_142)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_143 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_143.name = "SourceSteam_22"
	node_143.layers = operands[736]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_143.material_override = material_162
	if profile_details: Profile.end("liquid_node_material_override")
	node_143.cast_shadow = operands[737]
	node_143.emitting = operands[738]
	if profile_details: Profile.begin("liquid_node_amount")
	node_143.amount = operands[739]
	if profile_details: Profile.end("liquid_node_amount")
	node_143.lifetime = operands[740]
	node_143.use_fixed_seed = operands[741]
	node_143.seed = operands[742]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_143.fixed_fps = operands[743]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_143.process_material = material_163
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_143.draw_pass_1 = operands[744]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_143)
	if profile_details: Profile.begin("liquid_gpu_node_new")
	var node_144 := GPUParticles3D.new()
	if profile_details: Profile.end("liquid_gpu_node_new")
	node_144.name = "SourceSteam_23"
	node_144.layers = operands[745]
	if profile_details: Profile.begin("liquid_node_material_override")
	node_144.material_override = material_164
	if profile_details: Profile.end("liquid_node_material_override")
	node_144.cast_shadow = operands[746]
	node_144.emitting = operands[747]
	if profile_details: Profile.begin("liquid_node_amount")
	node_144.amount = operands[748]
	if profile_details: Profile.end("liquid_node_amount")
	node_144.lifetime = operands[749]
	node_144.use_fixed_seed = operands[750]
	node_144.seed = operands[751]
	if profile_details: Profile.begin("liquid_node_fixed_fps")
	node_144.fixed_fps = operands[752]
	if profile_details: Profile.end("liquid_node_fixed_fps")
	if profile_details: Profile.begin("liquid_node_process_material")
	node_144.process_material = material_165
	if profile_details: Profile.end("liquid_node_process_material")
	if profile_details: Profile.begin("liquid_node_draw_pass_1")
	node_144.draw_pass_1 = operands[753]
	if profile_details: Profile.end("liquid_node_draw_pass_1")
	node_0.add_child(node_144)
	if profile_details: Profile.end("cloud_program_nodes")
	if profile_details: Profile.begin("liquid_private_multimesh")
	var private_multimesh := MultiMesh.new()
	private_multimesh.transform_format = operands[765]
	private_multimesh.use_colors = operands[766]
	private_multimesh.use_custom_data = operands[767]
	private_multimesh.instance_count = operands[768]
	private_multimesh.visible_instance_count = operands[769]
	private_multimesh.mesh = operands[770]
	private_multimesh.buffer = operands[771]
	node_2.multimesh = private_multimesh
	node_2.material_override = material_166
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
	node_28.set_instance_shader_parameter("factory_liquid_link_index", 12)
	node_29.set_instance_shader_parameter("factory_liquid_link_index", 12)
	node_30.set_instance_shader_parameter("factory_liquid_link_index", 13)
	node_31.set_instance_shader_parameter("factory_liquid_link_index", 13)
	node_32.set_instance_shader_parameter("factory_liquid_link_index", 14)
	node_33.set_instance_shader_parameter("factory_liquid_link_index", 14)
	node_34.set_instance_shader_parameter("factory_liquid_link_index", 15)
	node_35.set_instance_shader_parameter("factory_liquid_link_index", 15)
	node_36.set_instance_shader_parameter("factory_liquid_link_index", 16)
	node_37.set_instance_shader_parameter("factory_liquid_link_index", 16)
	node_38.set_instance_shader_parameter("factory_liquid_link_index", 17)
	node_39.set_instance_shader_parameter("factory_liquid_link_index", 17)
	node_40.set_instance_shader_parameter("factory_liquid_link_index", 18)
	node_41.set_instance_shader_parameter("factory_liquid_link_index", 18)
	node_42.set_instance_shader_parameter("factory_liquid_link_index", 19)
	node_43.set_instance_shader_parameter("factory_liquid_link_index", 19)
	node_44.set_instance_shader_parameter("factory_liquid_link_index", 20)
	node_45.set_instance_shader_parameter("factory_liquid_link_index", 20)
	node_46.set_instance_shader_parameter("factory_liquid_link_index", 21)
	node_47.set_instance_shader_parameter("factory_liquid_link_index", 21)
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
	node_66.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_67.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_68.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_69.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_70.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_71.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_72.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_73.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_74.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_75.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_76.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_77.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_78.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_79.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_80.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_81.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_82.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_83.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_84.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_85.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_86.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_87.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_88.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_89.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_90.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_91.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_92.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_93.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_94.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_95.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_96.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_97.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_98.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_99.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_100.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_101.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_102.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	node_103.set_instance_shader_parameter("factory_liquid_contact_alpha", 0.0)
	if profile_details: Profile.end("liquid_draw_instance_parameters")
	return {"plane": node_1, "droplets": node_2, "main": material_0, "all_materials": [material_0, material_1, material_2, material_45, material_46, material_47, material_48, material_49, material_118, material_119, material_166], "field_materials": [material_0, material_1, material_2, material_45, material_46, material_166], "clock_materials": [material_0, material_1, material_2, material_45, material_46, material_118], "link_materials": [material_1, material_2], "network": node_3, "ribbons": [{"core": node_4, "glow": node_5}, {"core": node_6, "glow": node_7}, {"core": node_8, "glow": node_9}, {"core": node_10, "glow": node_11}, {"core": node_12, "glow": node_13}, {"core": node_14, "glow": node_15}, {"core": node_16, "glow": node_17}, {"core": node_18, "glow": node_19}, {"core": node_20, "glow": node_21}, {"core": node_22, "glow": node_23}, {"core": node_24, "glow": node_25}, {"core": node_26, "glow": node_27}, {"core": node_28, "glow": node_29}, {"core": node_30, "glow": node_31}, {"core": node_32, "glow": node_33}, {"core": node_34, "glow": node_35}, {"core": node_36, "glow": node_37}, {"core": node_38, "glow": node_39}, {"core": node_40, "glow": node_41}, {"core": node_42, "glow": node_43}, {"core": node_44, "glow": node_45}, {"core": node_46, "glow": node_47}], "contact_groups": [[node_50, node_51, node_52], [node_53, node_54, node_55], [node_56, node_57, node_58], [node_59, node_60, node_61], [node_62, node_63, node_64], [node_65, node_66, node_67], [node_68, node_69, node_70], [node_71, node_72, node_73], [node_74, node_75, node_76], [node_77, node_78, node_79], [node_80, node_81, node_82], [node_83, node_84, node_85], [node_86, node_87, node_88], [node_89, node_90, node_91], [node_92, node_93, node_94], [node_95, node_96, node_97], [node_98, node_99, node_100], [node_101, node_102, node_103]], "plumes": [node_121, node_122, node_123, node_124, node_125, node_126, node_127, node_128, node_129, node_130, node_131, node_132, node_133, node_134, node_135, node_136, node_137, node_138, node_139, node_140, node_141, node_142, node_143, node_144], "flames": [], "world_process_units": [{"material": material_119, "values": operands[772]}], "root": node_0, "geometry": [node_1, node_2, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17, node_18, node_19, node_20, node_21, node_22, node_23, node_24, node_25, node_26, node_27, node_28, node_29, node_30, node_31, node_32, node_33, node_34, node_35, node_36, node_37, node_38, node_39, node_40, node_41, node_42, node_43, node_44, node_45, node_46, node_47, node_48, node_49, node_50, node_51, node_52, node_53, node_54, node_55, node_56, node_57, node_58, node_59, node_60, node_61, node_62, node_63, node_64, node_65, node_66, node_67, node_68, node_69, node_70, node_71, node_72, node_73, node_74, node_75, node_76, node_77, node_78, node_79, node_80, node_81, node_82, node_83, node_84, node_85, node_86, node_87, node_88, node_89, node_90, node_91, node_92, node_93, node_94, node_95, node_96, node_97, node_98, node_99, node_100, node_101, node_102, node_103, node_104, node_105, node_106, node_107, node_108, node_109, node_110, node_111, node_112, node_113, node_114, node_115, node_116, node_117, node_118, node_119, node_120, node_121, node_122, node_123, node_124, node_125, node_126, node_127, node_128, node_129, node_130, node_131, node_132, node_133, node_134, node_135, node_136, node_137, node_138, node_139, node_140, node_141, node_142, node_143, node_144], "materials": [], "cohorts": []}
