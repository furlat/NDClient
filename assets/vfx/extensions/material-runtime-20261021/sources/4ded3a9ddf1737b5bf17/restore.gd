extends RefCounted
## Exact native leaf restore with shared immutable display/private instance state.
const OriginalRestore = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/35243558c7ef77ec849b/restore.gd")
const NativeUnits = preload("res://assets/vfx/extensions/followup-20261020/sources/7a626a58244915b1d09e/native_units.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")


static func make(script_path: String, input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_4ded3a9ddf.resource(input.prepared_recipient_bank)
	assert(bank != null and bank.interface_ready and bank.scene != null)
	assert(bank.native_processes.size() == bank.process_specs.size())
	var script: Script = VfxPackageIO_4ded3a9ddf.resource(script_path)
	assert(script.get_base_script().get_base_script().resource_path == bank.source_script)
	var node: Node3D = script.new()
	node.parameters = input.duplicate(true)
	node.settings = input.settings.duplicate(true)
	node.side = input.side
	Profile.begin("curse_scene_instantiate")
	node.subject = bank.scene.instantiate()
	Profile.end("curse_scene_instantiate")
	# The compiler admits a fixed native child topology and all callbacks were
	# audited not to add geometry. Store actual private Nodes only on this owner.
	node.set_meta("prepared_native_curse_geometry",
		node.subject.find_children("*", "GeometryInstance3D", true, false))
	Profile.begin("curse_private_material_restore")
	var meshes := {}
	Profile.begin("curse_display_materials")
	for index in bank.material_specs.size():
		var specification: Dictionary = bank.material_specs[index]
		var material: ShaderMaterial = bank.shared_display(index)
		OriginalRestore._bind(node.subject, specification.binding, material, meshes)
	Profile.end("curse_display_materials")
	var operators: Array[RefCounted] = []
	Profile.begin("curse_native_process_materials")
	for index in bank.native_processes.size():
		var specification: Dictionary = bank.native_processes[index]
		var emitter: GPUParticles3D = node.subject.get_node(specification.path)
		var material: ShaderMaterial = bank.private_shader_process(index)
		emitter.process_material = material
		if not specification.units.is_empty():
			operators.append(NativeUnits.new(material, specification.units))
	Profile.end("curse_native_process_materials")
	node.set_meta("prepared_curse_native_units", operators)
	node.display.bind(node.subject, bank.material_specs)
	# Original lifecycle loops are empty because every mutable display operand
	# now has an actual private GeometryInstance owner, never a proxy Material.
	node.set_meta("prepared_world_source_materials", [])
	var players := []
	for path: String in bank.player_paths:
		players.append(node.subject.get_node(path))
	node.set_meta("prepared_source_players", players)
	node.set_meta("prepared_source_lights", [])
	node.set_meta("prepared_immutable_materials", [])
	for field: String in bank.node_members:
		node.set(field, node.subject.get_node(bank.node_members[field]))
	node.seeds = bank.seeds.duplicate(true)
	node.prepared = true
	node.set_meta("declared_registration_complete", bank.declared_registration_complete)
	node.set_meta("prepared_stable_source_paths", bank.stable_paths_prepared)
	node.set_meta("prepared_generated_name_bindings", bank.generated_name_bindings)
	node.set_meta("prepared_generated_names_applied", bank.generated_name_bindings.is_empty())
	node.set_meta("prepared_curse_bank", bank)
	node.subject.name = "Donor"
	node.add_child(node.subject)
	Profile.end("curse_private_material_restore")
	Profile.begin("curse_original_array_and_birth_handles")
	for field: String in bank.node_arrays:
		var target: Array = node.get(field)
		for path in bank.node_arrays[field]:
			target.append(node.subject.get_node(path))
	for pose: Dictionary in bank.fold_poses:
		var fold: MeshInstance3D = node.subject.get_node(pose.path)
		fold.rotation = pose.rotation
		fold.scale = pose.scale
		fold.position = pose.position
	Profile.end("curse_original_array_and_birth_handles")
	return node


static func bindings(node: Node3D) -> Dictionary:
	if not node.get_meta("declared_registration_complete", false):
		return {}
	return {"geometry":node.get_meta("prepared_native_curse_geometry"),
		"materials":node.materials, "players":node.get_meta("prepared_source_players"),
		"lights":node.get_meta("prepared_source_lights"),
		"static_material_topology":true, "static_geometry_layers":true}

const VfxPackageIO_4ded3a9ddf = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
