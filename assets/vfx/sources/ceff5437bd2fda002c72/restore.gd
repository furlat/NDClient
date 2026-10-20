extends RefCounted
## Typed family restoration, not donor loading or source shader generation.
const Breakup = preload("res://assets/vfx/sources/6e4d9214e2f190871bc1/breakup.gd")

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.solid_bank)]

static func decode(value: Variant, subject: Node3D, materials: Array[ShaderMaterial]) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.has("source_node"):
			return subject.get_node(value.source_node)
		if value.size() == 1 and value.has("source_material"):
			return materials[int(value.source_material)]
		var result := {}
		for key in value:
			result[key] = decode(value[key], subject, materials)
		return result
	if value is Array:
		var result := []
		for entry in value:
			result.append(decode(entry, subject, materials))
		return result
	return value

static func unique_materials(materials: Array) -> Array:
	# Only identity aliases with identical source writes are folded. Separate
	# source roles and each occurrence's private material objects stay distinct.
	var unique := []
	var visited := {}
	for material: ShaderMaterial in materials:
		if not visited.has(material):
			visited[material] = true
			unique.append(material)
	return unique

static func make(script_path: String, input: Dictionary) -> Node3D:
	var bank: Resource = VfxPackageIO_ceff5437bd.resource(str(input.solid_bank))
	assert(bank != null and bank.interface_ready, "Complete native solid immutable readiness first")
	var parameters := input.duplicate(true)
	parameters.erase("solid_bank")
	assert(parameters == bank.parameters, "Changed native source variant needs explicit preparation")
	var node: Node3D = VfxPackageIO_ceff5437bd.resource(script_path).new()
	node.bank = bank
	node.parameters = parameters
	node.settings = parameters.settings.duplicate(true)
	node.side = str(parameters.side)
	node.subject = bank.scene.instantiate()
	node.add_child(node.subject)
	var private_materials: Array[ShaderMaterial] = []
	for source: ShaderMaterial in bank.materials:
		private_materials.append(source.duplicate(false))
	assert(bank.material_bindings.size() == bank.geometry_paths.size())
	for binding in bank.material_bindings:
		var draw: MeshInstance3D = node.subject.get_node(binding.node)
		draw.material_override = private_materials[int(binding.material)]
		if binding.get("flake", false):
			draw.set_instance_shader_parameter("solid_flake_opacity", 0.0)
		node.runtime_geometry.append(draw)
	for key in bank.state:
		var restored: Variant = decode(bank.state[key], node.subject, private_materials)
		var current: Variant = node.get(key)
		if current is Array and restored is Array:
			current.assign(restored)
		else:
			node.set(key, restored)
	if bank.state.has("mats"):
		node.mats.assign(unique_materials(node.mats))
		for index in node.panel_mats.size():
			node.panel_mats[index] = unique_materials(node.panel_mats[index])
	node.prepared = true
	node.initialized = true
	node.runtime_materials.assign(private_materials)
	if not bank.break_parts.is_empty():
		for part in bank.break_parts:
			node.runtime_break_sources.append(node.subject.get_node(part.source_node))
		node.assembly_breakup = Breakup.new()
		node.assembly_breakup.prepare(node, bank.break_parts, private_materials)
		# The dome reuses its already registered native surface partitions;
		# wall bodies own additional visuals. Neither needs an N² identity scan.
		if node.settings.get("shape", "") != "ice-dome":
			node.runtime_geometry.append_array(node.assembly_breakup.draws)
		node.runtime_materials.append_array(node.assembly_breakup.private_materials)
	return node

static func sample_wall(node: Node3D, seconds: float) -> void:
	if not is_finite(seconds):
		return
	var desired := int(round(seconds * float(node.parameters.simulation_hz)))
	update_source_transform(node)
	# Source native physics owns motion between frames. Intermediate pure-time
	# material writes do not integrate bodies; retain the exact transfer tick.
	var event_tick := int(ceil((float(node.break_time) + .13) * float(node.parameters.simulation_hz)))
	if node.tick < event_tick and desired >= event_tick and not node.settings.get("intact_retirement", false):
		node.tick = event_tick - 1
		node.advance_lifecycle(1.0 / float(node.parameters.simulation_hz))
	if node.tick < desired:
		node.tick = desired - 1
		node.advance_lifecycle(1.0 / float(node.parameters.simulation_hz))
	update_source_transform(node)
	node.update_geometry()

static func update_source_transform(node: Node3D) -> void:
	if not node.source_transform_known or node.previous_source_transform != node.global_transform:
		node.source_transform_known = true
		node.previous_source_transform = node.global_transform
		if node.get("assembly_breakup") != null:
			node.assembly_breakup.update_source_transform(node.subject.global_transform, node.parameters.source_breakup)
		for material: ShaderMaterial in node.runtime_materials:
			if material.get_meta("factory_world_space_uniform", false):
				material.set_shader_parameter("factory_world_to_source", Projection(node.global_transform.affine_inverse()))

static func source_bindings(node: Node3D) -> Dictionary:
	return {"geometry":node.runtime_geometry, "materials":node.runtime_materials,
		"lights":[], "static_material_topology":true}

static func flakes_wall(node: Node3D, age: float, ground: Vector2, removal: float) -> void:
	var clock := float(node.tick % 576) / float(node.parameters.simulation_hz)
	for index in node.frost_flakes.size():
		var phase := fposmod(clock / 4.0 + float(index) * .61803398875, 1.0)
		var horizontal := fposmod(float(index) * .754877666, 1.0)
		var depth := fposmod(float(index) * .569840291, 1.0)
		var x: float = (horizontal - .5) * node.WIDTH * .80 + .07 * sin(TAU * phase + float(index) * 1.7)
		var z: float = .5 * node.CELL + (depth - .5) * node.thickness * .68 + .035 * cos(TAU * phase + float(index) * 2.1)
		node.frost_flakes[index].position = Vector3(x, node.HEIGHT * (1.0 - phase), z)
		var fade := smoothstep(0.0, .16, phase) * (1.0 - smoothstep(.78, 1.0, phase))
		node.frost_flakes[index].set_instance_shader_parameter("solid_flake_opacity",
			.34 * fade * smoothstep(2.66, 2.95, age) * removal)
	if not node.flake_mats.is_empty():
		node.flake_mats[0].set_shader_parameter("actor_ground", ground)

static func break_wall(node: Node3D) -> void:
	assert(not node.broken)
	node.assembly_breakup.transfer(node, node.runtime_break_sources,
		node.subject.global_transform, node.bank.break_motions, node.parameters.source_breakup)
	for pair in node.assembly_breakup.material_pairs:
		node.mats.append(pair.material)
	node.transfer_source_age_seconds = float(node.tick) / float(node.parameters.simulation_hz)
	node.broken = true
	var index := 0 if node.settings.get("single_section", false) else 1
	node.panels[index].hide()

const VfxPackageIO_ceff5437bd = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
