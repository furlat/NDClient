extends RefCounted
## Rehydrate the original fixed draw topology; inherited samplers stay live.
const Readiness = preload("res://assets/vfx/extensions/followup-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")


static func ready_bank(input: Dictionary) -> Resource:
	var path: String = input.prepared_strips_bank
	assert(Readiness.resources.has(path), "Prepare actual immutable strip operands before occurrence construction")
	var bank: Resource = Readiness.resources[path]
	assert(bank.interface_ready and bank.scene != null)
	var actual := {}
	for field: String in bank.material_parameters:
		actual[field] = input[field]
	assert(actual == bank.material_parameters, "New palette/source choices require a separate prepared bank")
	return bank


static func build(node: Node3D, bank: Resource) -> void:
	node.fit = bank.scene.instantiate()
	node.add_child(node.fit)
	for path: NodePath in bank.piece_paths:
		node.pieces.append(node.fit.get_node(path))
	for path: NodePath in bank.mote_paths:
		node.motes.append(node.fit.get_node(path))


static func bindings(node: Node3D) -> Dictionary:
	var geometry: Array = []
	var materials: Array = []
	for group: Array in [node.pieces, node.motes]:
		for draw: MeshInstance3D in group:
			geometry.append(draw)
			materials.append(draw.material_override)
	return {"geometry": geometry, "materials": materials, "lights": [], "players": [],
		"static_material_topology": true, "static_geometry_layers": true}
