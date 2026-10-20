extends RefCounted
## Known typed native operands only; no source graph/reflection/default scan.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")

static func restore(field: Node3D) -> void:
	var bank: Resource = field.bank
	assert(bank.native_standard_indices.size() == bank.native_standard_specs.size())
	Profile.begin("fixed_recorded_native_material_restore")
	for index in bank.native_standard_indices.size():
		var material_index: int = bank.native_standard_indices[index]
		assert(material_index in bank.private_materials)
		field.materials[material_index] = bank.native_standard_specs[index].make_material()
	for site: Dictionary in bank.native_standard_sites:
		var node: GeometryInstance3D = field.nodes[int(site.node_index)]
		var material: Material = field.materials[int(site.material)]
		if int(site.surface) < 0:
			node.material_override = material
		else:
			assert(node is MeshInstance3D)
			node.set_surface_override_material(int(site.surface),material)
	Profile.end("fixed_recorded_native_material_restore")
