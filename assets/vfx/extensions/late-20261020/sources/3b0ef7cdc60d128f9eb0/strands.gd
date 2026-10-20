extends "res://assets/vfx/extensions/late-20261020/sources/0c856fb8d39af4bbf481/summoning_strands.gd"
## Inherit the original 144-Hz quantized age/envelope and live placement.
## Only immutable donor construction is performed offline.
var source_geometry: Array = []
var source_world_materials: Array = []
var source_bank: Resource
const SummonProfile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")

static func preparation_resources(input: Dictionary) -> Array:
	return [input.summoning_bank]

static func make_component(input: Dictionary) -> Node3D:
	return construct_prepared(input, "res://assets/vfx/extensions/late-20261020/sources/3b0ef7cdc60d128f9eb0/strands.gd")

static func construct_prepared(input: Dictionary, script_path: String) -> Node3D:
	var bank: Resource = VfxPackageIO_3b0ef7cdc6.resource(input.summoning_bank)
	assert(bank != null and bank.interface_ready)
	var node: Node3D = VfxPackageIO_3b0ef7cdc6.resource(script_path).new()
	node.source_bank = bank
	node.parameters = input.duplicate(true)
	node.settings = input.settings.duplicate(true)
	node.side = str(input.side)
	SummonProfile.begin("summoning_scene_instantiate")
	node.subject = bank.scene.instantiate()
	SummonProfile.end("summoning_scene_instantiate")
	SummonProfile.begin("summoning_handle_restore")
	node.add_child(node.subject)
	for index in bank.material_nodes.size():
		var draw: GeometryInstance3D = node.subject.get_node(bank.material_nodes[index])
		var private_material: ShaderMaterial = bank.private_material(index)
		draw.material_override = private_material
		node.materials.append(private_material)
		node.source_geometry.append(draw)
	for index in bank.world_material_indices:
		node.source_world_materials.append(node.materials[index])
	for path in bank.ribbon_paths:
		var draw: MeshInstance3D = node.subject.get_node(path)
		node.ribbons.append(draw)
		node.gpu_summon_meshes.append(draw.mesh)
	if not bank.ground_path.is_empty(): node.ground = node.subject.get_node(bank.ground_path)
	node.gpu_motes = node.subject.get_node(bank.mote_path)
	node.gpu_mote_material = node.gpu_motes.material_override
	node.camera_ground = bank.camera_ground
	node.prepared = true
	node.set_meta("summoning_verified_stable_paths", bank.verified_stable_paths)
	SummonProfile.end("summoning_handle_restore")
	return node

func source_bindings() -> Dictionary:
	return {"geometry": source_geometry, "materials": materials, "lights": [],
		"static_material_topology": true, "static_geometry_layers": true}

const VfxPackageIO_3b0ef7cdc6 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
