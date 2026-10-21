extends RefCounted
## Reuse the qualified recipient restore, retaining complete curse topology.
const RecipientRestore = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/ca69e9e47c9d66bb69fd/restore.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const PrivateProcess = preload("res://assets/vfx/extensions/followup-20261020/sources/03c6c60becba37a1fcaf/private_particle_process.gd")


static func make(script_path: String, input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_35243558c7.resource(input.prepared_recipient_bank)
	assert(bank != null and bank.interface_ready and bank.scene != null)
	var script: Script = VfxPackageIO_35243558c7.resource(script_path)
	assert(script.get_base_script().resource_path == bank.source_script)
	var node: Node3D = script.new()
	node.parameters = input.duplicate(true)
	node.settings = input.settings.duplicate(true)
	node.side = input.side
	Profile.begin("curse_scene_instantiate")
	node.subject = bank.scene.instantiate()
	Profile.end("curse_scene_instantiate")
	Profile.begin("curse_private_material_restore")
	var meshes := {}
	var bound := {}
	for index in bank.material_specs.size():
		var specification: Dictionary = bank.material_specs[index]
		var material: ShaderMaterial = bank.private_material(index)
		_bind(node.subject,specification.binding,material,meshes)
		bound[specification.binding] = material
	for index in bank.process_specs.size():
		var emitter: GPUParticles3D = node.subject.get_node(bank.process_specs[index].path)
		emitter.process_material = bank.private_process(index)
	for binding: Dictionary in bank.material_bindings:
		node.materials.append(bound[binding])
	var world_materials := []
	for binding: Dictionary in bank.world_material_bindings:
		world_materials.append(bound[binding])
	node.set_meta("prepared_world_source_materials",world_materials)
	var players := []
	for path: String in bank.player_paths:
		players.append(node.subject.get_node(path))
	node.set_meta("prepared_source_players",players)
	node.set_meta("prepared_source_lights",[])
	node.set_meta("prepared_immutable_materials",[])
	for field: String in bank.node_members:
		node.set(field,node.subject.get_node(bank.node_members[field]))
	node.seeds = bank.seeds.duplicate(true)
	node.prepared = true
	node.set_meta("declared_registration_complete",bank.declared_registration_complete)
	node.set_meta("prepared_stable_source_paths",bank.stable_paths_prepared)
	node.set_meta("prepared_generated_name_bindings",bank.generated_name_bindings)
	node.set_meta("prepared_generated_names_applied",bank.generated_name_bindings.is_empty())
	node.set_meta("prepared_curse_bank",bank)
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
	for index in bank.unit_snapshots.size():
		var snapshot: Resource = bank.unit_snapshots[index]
		if snapshot.source_fields.is_empty():
			continue
		var emitter: GPUParticles3D = node.subject.get_node(bank.process_specs[index].path)
		assert(snapshot.proof.all_stored_properties_restore_exact and snapshot.proof.descendants_immutable_no_animation_or_script_writers)
		assert(PrivateProcess.claim_unit_ready(emitter,node,snapshot.source_fields),
			"Only exact compiled post-native-copy fields and this actual private owner can skip a second duplicate")
	Profile.end("curse_original_array_and_birth_handles")
	return node


static func _bind(subject: Node3D, binding: Dictionary, material: ShaderMaterial, meshes: Dictionary) -> void:
	assert(int(binding.get("next_pass_depth",0)) == 0)
	var node: GeometryInstance3D = subject.get_node(binding.node)
	if binding.kind == "override":
		node.material_override = material
		return
	if binding.kind == "surface_override":
		node.set_surface_override_material(int(binding.surface),material)
		return
	var original: Mesh = node.mesh if binding.kind == "mesh_surface" else node.get_draw_pass_mesh(int(binding["pass"]))
	if not meshes.has(original):
		meshes[original] = original.duplicate(false)
	var mesh: Mesh = meshes[original]
	if mesh is ArrayMesh:
		mesh.surface_set_material(int(binding.surface),material)
	else:
		assert(mesh is PrimitiveMesh and int(binding.surface) == 0)
		mesh.material = material
	if binding.kind == "mesh_surface": node.mesh = mesh
	else:
		assert(binding.kind == "particle_surface")
		node.set_draw_pass_mesh(int(binding["pass"]),mesh)


static func start_native(node: Node3D) -> void:
	# The original creates its donor inside an already-entered source tree,
	# then issues restart/play. Match that birth edge after actual tree entry.
	assert(node.is_inside_tree())
	var bank: Resource = node.get_meta("prepared_curse_bank")
	for path: NodePath in bank.restart_paths:
		var emitter: GPUParticles3D = node.subject.get_node(path)
		emitter.restart()
	for record: Dictionary in bank.player_states:
		var player: AnimationPlayer = node.subject.get_node(record.path)
		assert(record.position == 0.0)
		if record.playing:
			player.clear_caches()
			player.play(record.animation)
		elif not str(record.animation).is_empty():
			player.assigned_animation = record.animation


static func bindings(node: Node3D) -> Dictionary:
	return RecipientRestore.declared_bindings(node,true)


static func stable_paths(node: Node3D) -> bool:
	return RecipientRestore.has_verified_stable_paths(node)

const VfxPackageIO_35243558c7 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
