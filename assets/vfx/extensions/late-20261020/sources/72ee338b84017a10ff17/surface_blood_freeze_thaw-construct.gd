extends RefCounted
## Generated offline from exact captured cloud source specifications.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static func instantiate(operands: Array, profile_details: bool = false) -> Dictionary:
	if profile_details: Profile.begin("liquid_private_materials")
	var material_0: ShaderMaterial = operands[7].duplicate(false)
	var material_1: ShaderMaterial = operands[8].duplicate(false)
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
	if profile_details: Profile.end("cloud_program_nodes")
	if profile_details: Profile.begin("liquid_private_multimesh")
	var private_multimesh := MultiMesh.new()
	private_multimesh.transform_format = operands[9]
	private_multimesh.use_colors = operands[10]
	private_multimesh.use_custom_data = operands[11]
	private_multimesh.instance_count = operands[12]
	private_multimesh.visible_instance_count = operands[13]
	private_multimesh.mesh = operands[14]
	private_multimesh.buffer = operands[15]
	node_2.multimesh = private_multimesh
	node_2.material_override = material_1
	if profile_details: Profile.end("liquid_private_multimesh")
	if profile_details: Profile.begin("liquid_draw_instance_parameters")
	if profile_details: Profile.end("liquid_draw_instance_parameters")
	return {"plane": node_1, "droplets": node_2, "main": material_0, "all_materials": [material_0, material_1], "field_materials": [material_0, material_1], "clock_materials": [material_0], "link_materials": [], "network": null, "ribbons": [], "contact_groups": [], "plumes": [], "flames": [], "world_process_units": [], "root": node_0, "geometry": [node_1, node_2], "materials": [], "cohorts": []}
