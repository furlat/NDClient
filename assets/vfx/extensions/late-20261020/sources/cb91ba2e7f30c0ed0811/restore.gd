extends RefCounted
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")

static func instantiate(bank: Resource, owner: Node3D) -> Dictionary:
	assert(bank != null and bank.interface_ready and bank.scene != null,
		"Payload immutable preparation must finish before occurrence admission")
	Profile.begin("payload_scene_instantiate")
	var root: Node3D = bank.scene.instantiate()
	Profile.end("payload_scene_instantiate")
	Profile.begin("payload_private_material_restore")
	var geometry := []
	var materials := []
	for index in bank.material_paths.size():
		var draw: GeometryInstance3D = root.get_node(bank.material_paths[index])
		var material: ShaderMaterial = bank.private_material(index)
		draw.material_override = material
		geometry.append(draw)
		materials.append(material)
	owner.add_child(root)
	Profile.end("payload_private_material_restore")
	return {"root": root, "geometry": geometry, "materials": materials}

static func bindings(owner: Node3D) -> Dictionary:
	return {"geometry": owner.prepared_geometry, "materials": owner.prepared_materials,
		"players": owner.prepared_players, "lights": [],
		"static_material_topology": true, "static_geometry_layers": true}

static func layers(owner: Node3D, mask: int) -> void:
	assert(not owner.is_inside_tree() and mask > 0)
	for draw: GeometryInstance3D in owner.prepared_geometry:
		if draw.layers != 0 and draw.layers != mask: draw.layers = mask
