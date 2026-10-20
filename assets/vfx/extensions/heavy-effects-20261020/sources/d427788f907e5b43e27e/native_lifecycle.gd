extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/92fd8420b6249066d8eb/summon_lifecycle.gd"
## Prepared original manifestation source. Retains every individually sorted
## native mote. Only exact equal-write mote materials share within one owner.
const NativeBankProfile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var source_bank: Resource
var declared_geometry: Array = []

static func preparation_resources(input: Dictionary) -> Array:
	return [input.summoning_bank]

static func make_component(input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_d427788f90.resource(input.summoning_bank)
	assert(bank != null and bank.interface_ready)
	var node: Node3D = VfxPackageIO_d427788f90.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/d427788f907e5b43e27e/native_lifecycle.gd").new()
	node.source_bank = bank
	node.parameters = input.duplicate(true)
	node.parameters.lifecycle_sampling = "analytical"
	node.settings = input.settings.duplicate(true)
	node.side = str(input.side)
	NativeBankProfile.begin("manifestation_scene_instantiate")
	var constructed: Dictionary = bank.construct_subject()
	node.subject = constructed.root if not constructed.is_empty() else bank.scene.instantiate()
	NativeBankProfile.end("manifestation_scene_instantiate")
	node.add_child(node.subject)
	var private_materials := {}
	for index in bank.material_nodes.size():
		var canonical: int = bank.material_canonical_indices[index]
		if not private_materials.has(canonical):
			private_materials[canonical] = constructed.materials[index] if not constructed.is_empty() else bank.private_material(canonical)
			node.materials.append(private_materials[canonical])
		var draw: MeshInstance3D = constructed.geometry[index] if not constructed.is_empty() else node.subject.get_node(bank.material_nodes[index])
		if constructed.is_empty():
			draw.material_override = private_materials[canonical]
		node.declared_geometry.append(draw)
	for path in bank.ribbon_paths:
		var ribbon: MeshInstance3D = node.subject.get_node(path)
		# Bind after its actual private material is assigned. Godot cannot
		# serialize an instance operand whose former material lacked it.
		ribbon.set_instance_shader_parameter("gpu_summon_index",node.ribbons.size())
		node.ribbons.append(ribbon)
		node.gpu_ribbon_templates[node.ribbons.size()-1] = ribbon.mesh
	for path in bank.mote_paths:
		node.motes.append(node.subject.get_node(path))
	if not bank.ground_path.is_empty():
		node.ground = node.subject.get_node(bank.ground_path)
	node.camera_ground = bank.camera_ground
	node.prepared = true
	node.set_meta("summoning_verified_stable_paths",bank.verified_stable_paths)
	return node

func sample(seconds: float) -> void:
	# Preserve original monotonic source advancement and 144-Hz tick-1 pose.
	# The former override recomputed all 12 pure ribbon bounds every render.
	# Exact per-source-age AABBs are compiled in the immutable bank instead.
	if not initialized:
		initialized = true
	var desired := roundi(seconds * float(parameters.simulation_hz))
	if tick < desired:
		sample_analytical_tick(desired)
	update_geometry()
	var frame := maxi(0,roundi(time * float(parameters.simulation_hz)))
	for index in ribbons.size():
		var frames: Array = source_bank.ribbon_bounds[index]
		ribbons[index].custom_aabb = frames[mini(frame,frames.size()-1)]

func source_bindings() -> Dictionary:
	return {"geometry":declared_geometry,"materials":materials,"lights":[],
		"static_material_topology":true,"static_geometry_layers":true}

const VfxPackageIO_d427788f90 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
