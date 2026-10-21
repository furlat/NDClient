extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/18362428a9f99b4e48b3/typed_bank.gd"
## Resolve original saved node/material addresses during immutable readiness.
## Every occurrence still constructs its own exact native hierarchy/controllers.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
const Restore = preload("res://assets/vfx/extensions/spirit-runtime-20261021/sources/ca69e9e47c9d66bb69fd/restore.gd")
var node_slots: Dictionary = {}
var material_slots: Dictionary = {}
var member_slots: Dictionary = {}
var array_slots: Dictionary = {}
var material_member_slots: Dictionary = {}
var material_array_slots: Dictionary = {}
var initial_material_slots := PackedInt32Array()
var world_slots := PackedInt32Array()
var shader_slots := PackedInt32Array()
var emission_slots := PackedInt32Array()
var player_slots := PackedInt32Array()
var light_slots := PackedInt32Array()


func _nodes(paths: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for path in paths:
		assert(node_slots.has(str(path).trim_prefix("./")))
		result.append(node_slots[str(path).trim_prefix("./")])
	return result


func _material(binding: Dictionary) -> int:
	assert(binding.kind == "override" and int(binding.get("next_pass_depth", 0)) == 0)
	var path := str(binding.node).trim_prefix("./")
	assert(material_slots.has(path), "Exact original private override material site")
	return material_slots[path]


func _materials(bindings: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for binding: Dictionary in bindings:
		result.append(_material(binding))
	return result


func _description(value: Dictionary) -> int:
	return -1 - int(value.extra) if value.has("extra") else _material(value.binding)


func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	var state: SceneState = construction_source.scene.get_state()
	var actual_materials: Dictionary = {}
	for index in state.get_node_count():
		var path := str(state.get_node_path(index)).trim_prefix("./")
		node_slots[path] = index
		for property in state.get_node_property_count(index):
			var value: Variant = state.get_node_property_value(index, property)
			if value is ShaderMaterial:
				assert(str(state.get_node_property_name(index, property)) == "material_override")
				if not actual_materials.has(value):
					actual_materials[value] = actual_materials.size()
				material_slots[path] = actual_materials[value]
	initial_material_slots = _materials(material_bindings)
	world_slots = _materials(world_material_bindings)
	shader_slots = _materials(all_shader_bindings)
	emission_slots = _nodes(emission_start_edges)
	player_slots = _nodes(player_paths)
	light_slots = _nodes(light_paths)
	for field: String in node_members:
		member_slots[field] = _nodes([node_members[field]])[0]
	for field: String in node_arrays:
		array_slots[field] = _nodes(node_arrays[field])
	for field: String in material_members:
		material_member_slots[field] = _description(material_members[field])
	for field: String in material_arrays:
		var slots := PackedInt32Array()
		for description: Dictionary in material_arrays[field]:
			slots.append(_description(description))
		material_array_slots[field] = slots
	super.prepare_immutable_interface()


func restore_controller(script_path: String, input: Dictionary) -> Node3D:
	assert(interface_ready and script_path == adapter_script.resource_path)
	var script: Script = adapter_script
	var node: Node3D = null if plain_flow else script.new()
	if not plain_flow:
		node.parameters = input.duplicate(true)
		node.settings = input.settings.duplicate(true)
		node.side = input.side
	Profile.begin("recipient_scene_instantiate")
	var created: Dictionary = construction_program.instantiate(construction_operands)
	var subject: Node3D = created.root
	var nodes: Array = created.nodes
	var materials: Array = created.private_materials
	assert(created.get("material_sites_bound", false))
	subject.set_meta("prepared_typed_geometry", created.geometry)
	Profile.end("recipient_scene_instantiate")
	Profile.begin("recipient_binding_restore")
	if plain_flow:
		node = subject
		node.set_script(script)
		node.duration = float(input.get("seconds", 4.5))
	else:
		node.subject = subject
		for slot: int in emission_slots:
			var emitter: GPUParticles3D = nodes[slot]
			assert(not emitter.is_inside_tree() and emitter.one_shot and emitter.emitting)
			emitter.emitting = false
			emitter.emitting = true
		subject.name = "Donor"
		node.add_child(subject)
		for slot: int in initial_material_slots:
			node.materials.append(materials[slot])
		var world_materials := []
		for slot: int in world_slots:
			world_materials.append(materials[slot])
		node.set_meta("prepared_world_source_materials", world_materials)
		var players := []
		for slot: int in player_slots:
			players.append(nodes[slot])
		node.set_meta("prepared_source_players", players)
		var lights := []
		for slot: int in light_slots:
			lights.append(nodes[slot])
		node.set_meta("prepared_source_lights", lights)
		var immutable_materials := []
		for binding: Dictionary in immutable_material_bindings:
			var material: Material = Restore.resource_material(subject, binding)
			assert(material is StandardMaterial3D)
			immutable_materials.append(material)
		node.set_meta("prepared_immutable_materials", immutable_materials)
		for field: String in member_slots:
			node.set(field, nodes[member_slots[field]])
		node.seeds = seeds.duplicate(true)
		node.prepared = true
		node.set_meta("declared_registration_complete", declared_registration_complete)
		node.set_meta("prepared_stable_source_paths", stable_paths_prepared)
		node.set_meta("prepared_generated_name_bindings", generated_name_bindings)
		node.set_meta("prepared_generated_names_applied", generated_name_bindings.is_empty())
	Profile.end("recipient_binding_restore")
	var extras := []
	for material in extra_materials:
		extras.append(material.duplicate(false))
	for field: String in array_slots:
		var array: Array = node.get(field)
		for slot: int in array_slots[field]:
			array.append(nodes[slot])
	for field: String in value_members:
		var current: Variant = node.get(field)
		if current is Array:
			current.assign(value_members[field])
		else:
			node.set(field, value_members[field])
	for field: String in material_member_slots:
		var slot: int = material_member_slots[field]
		node.set(field, materials[slot] if slot >= 0 else extras[-1 - slot])
	for field: String in material_array_slots:
		var array: Array = node.get(field)
		array.clear()
		for slot: int in material_array_slots[field]:
			array.append(materials[slot] if slot >= 0 else extras[-1 - slot])
	var all_materials := []
	for slot: int in shader_slots:
		all_materials.append(materials[slot])
	node.set_meta("prepared_timed_materials", all_materials)
	node.set_meta("prepared_timed_geometry", created.geometry)
	node.set_meta("prepared_timed_subject", subject)
	node.set_meta("prepared_timed_bank", self)
	return node
