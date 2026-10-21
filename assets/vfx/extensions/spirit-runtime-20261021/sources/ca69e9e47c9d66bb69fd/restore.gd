extends RefCounted
## Restore the exact private subject and original lifecycle's explicit handles.
## Exact recipe validation belongs to offline preparation/import. Runtime only
## restores required resources; no per-occurrence serialization or hash pass.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")

static func resource_material(subject: Node3D, binding: Dictionary) -> Material:
	var node: Node = subject.get_node(binding.node)
	var value: Material
	match binding.kind:
		"override":
			value = node.material_override
		"surface_override":
			value = node.get_surface_override_material(int(binding.surface))
		"mesh_surface":
			value = node.mesh.surface_get_material(int(binding.surface))
		"particle_surface":
			value = node.get_draw_pass_mesh(int(binding["pass"])).surface_get_material(int(binding.surface))
		_:
			assert(false, "Unknown prepared source material binding")
	for index in int(binding.get("next_pass_depth", 0)):
		value = value.next_pass
	return value

static func material(subject: Node3D, binding: Dictionary) -> ShaderMaterial:
	var value: Material = resource_material(subject, binding)
	assert(value is ShaderMaterial)
	return value

static func make(script_path: String, input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_ca69e9e47c.resource(input.prepared_recipient_bank)
	assert(bank != null and bank.scene != null, "Prepared recipient bank is required")
	var script: Script = VfxPackageIO_ca69e9e47c.resource(script_path)
	assert(script.get_base_script().resource_path == bank.source_script)
	var node: Node3D = script.new()
	node.parameters = input.duplicate(true)
	node.settings = input.settings.duplicate(true)
	node.side = input.side
	Profile.begin("recipient_scene_instantiate")
	node.subject = bank.instantiate_subject()
	Profile.end("recipient_scene_instantiate")
	Profile.begin("recipient_binding_restore")
	for path: NodePath in bank.emission_start_edges:
		var emitter: GPUParticles3D = node.subject.get_node(path)
		assert(not emitter.is_inside_tree() and emitter.one_shot and emitter.emitting,
			"Prepared constructor emission edge requires its exact pre-tree source state")
		# Preserve an explicit original constructor false->true setter edge.
		# A saved true default cannot represent that native one-shot birth state.
		emitter.emitting = false
		emitter.emitting = true
	node.subject.name = "Donor"
	node.add_child(node.subject)
	for binding in bank.material_bindings:
		node.materials.append(material(node.subject, binding))
	var world_materials := []
	for binding in bank.world_material_bindings:
		world_materials.append(material(node.subject, binding))
	node.set_meta("prepared_world_source_materials", world_materials)
	var players := []
	for path in bank.player_paths:
		players.append(node.subject.get_node(path))
	node.set_meta("prepared_source_players", players)
	var lights := []
	for path in bank.light_paths:
		lights.append(node.subject.get_node(path))
	node.set_meta("prepared_source_lights", lights)
	var immutable_materials := []
	for binding in bank.immutable_material_bindings:
		var value: Material = resource_material(node.subject, binding)
		assert(value is StandardMaterial3D)
		immutable_materials.append(value)
	node.set_meta("prepared_immutable_materials", immutable_materials)
	for field: String in bank.node_members:
		node.set(field, node.subject.get_node(bank.node_members[field]))
	node.seeds = bank.seeds.duplicate(true)
	node.prepared = true
	node.set_meta("declared_registration_complete", bank.declared_registration_complete)
	node.set_meta("prepared_stable_source_paths", bank.stable_paths_prepared)
	node.set_meta("prepared_generated_name_bindings", bank.generated_name_bindings)
	node.set_meta("prepared_generated_names_applied", bank.generated_name_bindings.is_empty())
	Profile.end("recipient_binding_restore")
	return node

static func has_verified_stable_paths(node: Node3D) -> bool:
	if not node.get_meta("prepared_stable_source_paths", false):
		return false
	if node.get_meta("prepared_generated_names_applied", false):
		return true
	for binding in node.get_meta("prepared_generated_name_bindings"):
		var parent: Node = node.subject.get_node(binding.parent)
		var matches := []
		for child in parent.get_children(true):
			if child.get_class() == binding.node_class and child not in parent.get_children():
				matches.append(child)
		assert(matches.size() == 1, "Prepared internal-engine node identity changed")
		var child: Node = matches[0]
		var stable_name := "FactoryGenerated_%04d_%s" % [child.get_index(true), child.get_class()]
		assert(String(child.name).begins_with("@") or String(child.name) == stable_name,
			"Do not rename an unknown authored node")
		child.name = stable_name
	node.set_meta("prepared_generated_names_applied", true)
	return true

static func declared_bindings(node: Node3D, static_geometry_layers: bool) -> Dictionary:
	if not node.get_meta("declared_registration_complete", false):
		return {}
	return {"geometry": node.subject.find_children("*", "GeometryInstance3D", true, false),
		"materials": node.materials, "players": node.get_meta("prepared_source_players"),
		"lights": node.get_meta("prepared_source_lights"),
		"static_material_topology": true, "static_geometry_layers": static_geometry_layers}

const VfxPackageIO_ca69e9e47c = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
