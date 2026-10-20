extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(owner: Node3D, operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("electric_private_materials")
	var material_0: ShaderMaterial = operands[66].duplicate(false)
	var material_1: ShaderMaterial = operands[67].duplicate(false)
	var material_2: ShaderMaterial = operands[68].duplicate(false)
	var material_3: ShaderMaterial = operands[69].duplicate(false)
	var material_4: ShaderMaterial = operands[70].duplicate(false)
	var material_5: ShaderMaterial = operands[71].duplicate(false)
	var material_6: ShaderMaterial = operands[72].duplicate(false)
	var material_7: ShaderMaterial = operands[73].duplicate(false)
	var material_8: ShaderMaterial = operands[74].duplicate(false)
	var material_9: ShaderMaterial = operands[75].duplicate(false)
	var material_10: ShaderMaterial = operands[76].duplicate(false)
	var material_11: ShaderMaterial = operands[77].duplicate(false)
	var material_12: ShaderMaterial = operands[78].duplicate(false)
	var material_13: ShaderMaterial = operands[79].duplicate(false)
	var material_14: ShaderMaterial = operands[80].duplicate(false)
	var material_15: ShaderMaterial = operands[81].duplicate(false)
	var material_16: ShaderMaterial = operands[82].duplicate(false)
	if profile_details: Profile.end("electric_private_materials")
	if profile_details: Profile.begin("cloud_program_nodes")
	var node_0: Node3D = owner
	node_0.name = "network"
	var node_1 := MeshInstance3D.new()
	node_1.name = "ElectricCore0"
	node_1.visible = operands[0]
	node_1.layers = operands[1]
	node_1.material_override = material_0
	node_1.cast_shadow = operands[2]
	node_1.custom_aabb = operands[3]
	node_1.mesh = operands[4]
	node_0.add_child(node_1)
	var node_2 := MeshInstance3D.new()
	node_2.name = "ElectricGlow0"
	node_2.visible = operands[5]
	node_2.layers = operands[6]
	node_2.material_override = material_1
	node_2.cast_shadow = operands[7]
	node_2.custom_aabb = operands[8]
	node_2.mesh = operands[9]
	node_0.add_child(node_2)
	var node_3 := MeshInstance3D.new()
	node_3.name = "ElectricCore1"
	node_3.visible = operands[10]
	node_3.layers = operands[11]
	node_3.material_override = material_2
	node_3.cast_shadow = operands[12]
	node_3.custom_aabb = operands[13]
	node_3.mesh = operands[14]
	node_0.add_child(node_3)
	var node_4 := MeshInstance3D.new()
	node_4.name = "ElectricGlow1"
	node_4.visible = operands[15]
	node_4.layers = operands[16]
	node_4.material_override = material_3
	node_4.cast_shadow = operands[17]
	node_4.custom_aabb = operands[18]
	node_4.mesh = operands[19]
	node_0.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "MeasuredContactArcs0"
	node_5.visible = operands[20]
	node_5.layers = operands[21]
	node_5.material_override = material_4
	node_5.cast_shadow = operands[22]
	node_5.custom_aabb = operands[23]
	node_5.mesh = operands[24]
	node_0.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "SourceHandCoils"
	node_6.layers = operands[25]
	node_6.material_override = material_5
	node_6.cast_shadow = operands[26]
	node_6.custom_aabb = operands[27]
	node_6.mesh = operands[28]
	node_0.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "FactoryGenerated_0006_MeshInstance3D"
	node_7.layers = operands[29]
	node_7.material_override = material_6
	node_7.cast_shadow = operands[30]
	node_7.mesh = operands[31]
	node_0.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "FactoryGenerated_0007_MeshInstance3D"
	node_8.layers = operands[32]
	node_8.material_override = material_7
	node_8.cast_shadow = operands[33]
	node_8.mesh = operands[34]
	node_0.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "FactoryGenerated_0008_MeshInstance3D"
	node_9.layers = operands[35]
	node_9.material_override = material_8
	node_9.cast_shadow = operands[36]
	node_9.mesh = operands[37]
	node_0.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "FactoryGenerated_0009_MeshInstance3D"
	node_10.layers = operands[38]
	node_10.material_override = material_9
	node_10.cast_shadow = operands[39]
	node_10.mesh = operands[40]
	node_0.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "FactoryGenerated_0010_MeshInstance3D"
	node_11.layers = operands[41]
	node_11.material_override = material_10
	node_11.cast_shadow = operands[42]
	node_11.mesh = operands[43]
	node_0.add_child(node_11)
	var node_12 := MeshInstance3D.new()
	node_12.name = "FactoryGenerated_0011_MeshInstance3D"
	node_12.layers = operands[44]
	node_12.material_override = material_11
	node_12.cast_shadow = operands[45]
	node_12.mesh = operands[46]
	node_0.add_child(node_12)
	var node_13 := MeshInstance3D.new()
	node_13.name = "FactoryGenerated_0012_MeshInstance3D"
	node_13.layers = operands[47]
	node_13.material_override = material_12
	node_13.cast_shadow = operands[48]
	node_13.mesh = operands[49]
	node_0.add_child(node_13)
	var node_14 := MeshInstance3D.new()
	node_14.name = "FactoryGenerated_0013_MeshInstance3D"
	node_14.layers = operands[50]
	node_14.material_override = material_13
	node_14.cast_shadow = operands[51]
	node_14.mesh = operands[52]
	node_0.add_child(node_14)
	var node_15 := MeshInstance3D.new()
	node_15.name = "FactoryGenerated_0014_MeshInstance3D"
	node_15.layers = operands[53]
	node_15.material_override = material_14
	node_15.cast_shadow = operands[54]
	node_15.mesh = operands[55]
	node_0.add_child(node_15)
	var node_16 := MeshInstance3D.new()
	node_16.name = "MeasuredContactArcs1"
	node_16.visible = operands[56]
	node_16.layers = operands[57]
	node_16.material_override = material_15
	node_16.cast_shadow = operands[58]
	node_16.custom_aabb = operands[59]
	node_16.mesh = operands[60]
	node_0.add_child(node_16)
	var node_17 := MeshInstance3D.new()
	node_17.name = "MeasuredContactArcs2"
	node_17.visible = operands[61]
	node_17.layers = operands[62]
	node_17.material_override = material_16
	node_17.cast_shadow = operands[63]
	node_17.custom_aabb = operands[64]
	node_17.mesh = operands[65]
	node_0.add_child(node_17)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"all_materials":[material_0,material_1,material_2,material_3,material_4,material_5,material_6,material_7,material_8,material_9,material_10,material_11,material_12,material_13,material_14,material_15,material_16],"source_materials":[material_0,material_1,material_2,material_3,material_4,material_5,material_15,material_16],"ribbons":[{"core":node_1,"glow":node_2},{"core":node_3,"glow":node_4}],"contact_draws":[[node_7,node_8,node_9],[node_10,node_11,node_12],[node_13,node_14,node_15]],"contact_arcs":node_5,"hand_arcs":node_6,"body_draws":[node_5,node_16,node_17],"root": node_0, "geometry": [node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11, node_12, node_13, node_14, node_15, node_16, node_17], "materials": [], "cohorts": []}
