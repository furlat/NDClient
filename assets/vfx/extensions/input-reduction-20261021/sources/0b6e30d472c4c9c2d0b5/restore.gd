extends RefCounted
## Shared restoration only. Original source classes still own every live equation.
const Readiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")


static func restore(node: Node3D, input: Dictionary, adapter: String) -> Node3D:
	var path: String = input.prepared_receiving_bank
	assert(Readiness.resources.has(path), "Prepare exact receiving resources before construction")
	var bank: Resource = Readiness.resources[path]
	assert(bank.interface_ready and bank.scene != null and bank.adapter_script == adapter)
	var settings: Dictionary = input.duplicate(true)
	settings.erase("prepared_receiving_bank")
	assert(settings == bank.source_input, "A changed source style needs its own exact bank")
	node.bank = bank
	node.settings = settings
	node.prepared_root = bank.scene.instantiate()
	node.add_child(node.prepared_root)
	for selected: NodePath in bank.piece_paths:
		node.pieces.append(node.prepared_root.get_node(selected))
	for index: int in bank.material_piece_indices:
		node.materials.append(node.pieces[index].material_override)
	return node
