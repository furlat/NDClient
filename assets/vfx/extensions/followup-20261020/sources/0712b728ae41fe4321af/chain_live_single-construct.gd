extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(owner: Node3D, operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("cloud_program_materials")
	if profile_details: Profile.end("cloud_program_materials")
	if profile_details: Profile.begin("electric_private_materials")
	var material_0: ShaderMaterial = operands[42].duplicate(false)
	var material_1: ShaderMaterial = operands[43].duplicate(false)
	var material_2: ShaderMaterial = operands[44].duplicate(false)
	var material_3: ShaderMaterial = operands[45].duplicate(false)
	var material_4: ShaderMaterial = operands[46].duplicate(false)
	var material_5: ShaderMaterial = operands[47].duplicate(false)
	var material_6: ShaderMaterial = operands[48].duplicate(false)
	var material_7: ShaderMaterial = operands[49].duplicate(false)
	var material_8: ShaderMaterial = operands[50].duplicate(false)
	var material_9: ShaderMaterial = operands[51].duplicate(false)
	var material_10: ShaderMaterial = operands[52].duplicate(false)
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
	node_3.name = "MeasuredContactArcs0"
	node_3.visible = operands[10]
	node_3.layers = operands[11]
	node_3.material_override = material_2
	node_3.cast_shadow = operands[12]
	node_3.custom_aabb = operands[13]
	node_3.mesh = operands[14]
	node_0.add_child(node_3)
	var node_4 := MeshInstance3D.new()
	node_4.name = "SourceHandCoils"
	node_4.layers = operands[15]
	node_4.material_override = material_3
	node_4.cast_shadow = operands[16]
	node_4.custom_aabb = operands[17]
	node_4.mesh = operands[18]
	node_0.add_child(node_4)
	var node_5 := MeshInstance3D.new()
	node_5.name = "FactoryGenerated_0004_MeshInstance3D"
	node_5.layers = operands[19]
	node_5.material_override = material_4
	node_5.cast_shadow = operands[20]
	node_5.mesh = operands[21]
	node_0.add_child(node_5)
	var node_6 := MeshInstance3D.new()
	node_6.name = "FactoryGenerated_0005_MeshInstance3D"
	node_6.layers = operands[22]
	node_6.material_override = material_5
	node_6.cast_shadow = operands[23]
	node_6.mesh = operands[24]
	node_0.add_child(node_6)
	var node_7 := MeshInstance3D.new()
	node_7.name = "FactoryGenerated_0006_MeshInstance3D"
	node_7.layers = operands[25]
	node_7.material_override = material_6
	node_7.cast_shadow = operands[26]
	node_7.mesh = operands[27]
	node_0.add_child(node_7)
	var node_8 := MeshInstance3D.new()
	node_8.name = "FactoryGenerated_0007_MeshInstance3D"
	node_8.layers = operands[28]
	node_8.material_override = material_7
	node_8.cast_shadow = operands[29]
	node_8.mesh = operands[30]
	node_0.add_child(node_8)
	var node_9 := MeshInstance3D.new()
	node_9.name = "FactoryGenerated_0008_MeshInstance3D"
	node_9.layers = operands[31]
	node_9.material_override = material_8
	node_9.cast_shadow = operands[32]
	node_9.mesh = operands[33]
	node_0.add_child(node_9)
	var node_10 := MeshInstance3D.new()
	node_10.name = "FactoryGenerated_0009_MeshInstance3D"
	node_10.layers = operands[34]
	node_10.material_override = material_9
	node_10.cast_shadow = operands[35]
	node_10.mesh = operands[36]
	node_0.add_child(node_10)
	var node_11 := MeshInstance3D.new()
	node_11.name = "MeasuredContactArcs1"
	node_11.visible = operands[37]
	node_11.layers = operands[38]
	node_11.material_override = material_10
	node_11.cast_shadow = operands[39]
	node_11.custom_aabb = operands[40]
	node_11.mesh = operands[41]
	node_0.add_child(node_11)
	if profile_details: Profile.end("cloud_program_nodes")
	return {"all_materials":[material_0,material_1,material_2,material_3,material_4,material_5,material_6,material_7,material_8,material_9,material_10],"source_materials":[material_0,material_1,material_2,material_3,material_10],"ribbons":[{"core":node_1,"glow":node_2}],"contact_draws":[[node_5,node_6,node_7],[node_8,node_9,node_10]],"contact_arcs":node_3,"hand_arcs":node_4,"body_draws":[node_3,node_11],"root": node_0, "geometry": [node_1, node_2, node_3, node_4, node_5, node_6, node_7, node_8, node_9, node_10, node_11], "materials": [], "cohorts": []}
