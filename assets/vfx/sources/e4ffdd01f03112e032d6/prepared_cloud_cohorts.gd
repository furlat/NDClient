extends "res://assets/vfx/sources/b7e4f5e433685cdff4bb/cloud_cohorts.gd"
## Exact prepared native billows. Draw programs/meshes/textures are immutable;
## instantiated GPU state and source clock/opacity materials remain private.
const MinimalScene = preload("res://assets/vfx/sources/00f461381755eccac670/cloud_minimal_scene.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
static var prepared_banks: Dictionary = {}
var geometry: Array = []
var source_materials: Array = []
var source_transform_known := false
var previous_source_transform: Transform3D
var shared_native_processes := false
var source_art_variant := "original_native_order"
var cohort_successor_sorting_offset_delta := 0.0
var prepared_source_layer_mask := 0
var construction_mode := "packed_scene"

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_cloud_bank]

static func make_component(input: Dictionary) -> Node3D:
	var path: String = input.prepared_cloud_bank
	if not prepared_banks.has(path):
		prepared_banks[path] = VfxPackageIO_e4ffdd01f0.resource(path)
	var bank: Resource = prepared_banks[path]
	assert(bank != null and bank.scene != null, "Cloud source bank is not prepared: " + path)
	Profile.begin("cloud_immutable_interface_preparation")
	bank.prepare_immutable_interface()
	Profile.end("cloud_immutable_interface_preparation")
	for field in bank.parameters:
		assert(input.get(field) == bank.parameters[field], "Cloud source variant needs offline preparation: " + str(field))
	var component: Node3D = VfxPackageIO_e4ffdd01f0.resource("res://assets/vfx/sources/e4ffdd01f03112e032d6/prepared_cloud_cohorts.gd").new()
	component.parameters = input.duplicate(true)
	component.settings = input.settings.duplicate(true)
	component.side = input.side
	component.kind = bank.kind
	component.radius = bank.radius
	component.shared_native_processes = bank.shared_native_processes
	component.source_art_variant = bank.source_art_variant
	component.cohort_successor_sorting_offset_delta = bank.cohort_successor_sorting_offset_delta
	Profile.begin("cloud_private_source_instantiation")
	var constructed: Dictionary = {}
	if not bank.node_specs.is_empty():
		if bank.construction_program != null:
			constructed = bank.construction_program.instantiate(bank.construction_operands, bool(input.get("profile_cloud_construction", false)))
			component.subject = constructed.root
			component.construction_mode = "offline_typed_source_program"
		else:
			# Older, separately measured representations remain reproducible.
			# A bank declaring the new program may never fall back silently.
			assert(bank.construction_program_receipt.is_empty(), "Declared cloud construction program is missing: " + path)
			component.subject = MinimalScene.instantiate(bank.node_specs, bank.material_specs, bool(input.get("profile_cloud_construction", false)))
			component.construction_mode = "interpreted_source_specs_unqualified_for_runtime_budget"
	else:
		component.subject = bank.scene.instantiate()
	Profile.end("cloud_private_source_instantiation")
	component.subject.name = "Donor"
	component.cloud = component.subject
	component.add_child(component.subject)
	if not constructed.is_empty():
		component.geometry = constructed.geometry
		component.mats.assign(constructed.materials)
		component.banks = constructed.cohorts
	else:
		for node_path in bank.geometry_paths:
			component.geometry.append(component.subject.get_node(node_path))
		for binding in bank.material_bindings:
			var node: Node = component.subject.get_node(binding.node)
			var material: ShaderMaterial
			if binding.kind == "override":
				material = node.material_override
			else:
				material = node.get_draw_pass_mesh(int(binding["pass"])).surface_get_material(int(binding.surface))
			assert(material != null, "Prepared cloud material binding is missing: " + str(binding))
			component.mats.append(material)
		for paths in bank.cohort_paths:
			var group := []
			for node_path in paths:
				group.append(component.subject.get_node(NodePath(node_path)))
			component.banks.append(group)
	for material: ShaderMaterial in component.mats:
		if material.get_meta("factory_world_space_uniform", false):
			component.source_materials.append(material)
	for group: Array in component.banks:
		# The source explicitly restarts each first cohort before duplicating its
		# inactive successor. A serialized `emitting = true` is not equivalent:
		# restart also resets the native one-shot emission clock/history.
		group[0].restart(true)
	assert(component.immutable_process_contract_valid(), "Shared native process contract violated")
	component.prepared = true
	component.initialized = true
	return component

func sample(seconds: float) -> void:
	var desired_tick := int(round(seconds * float(parameters.simulation_hz)))
	if desired_tick > tick:
		# Source particle history remains native and sequential. Only redundant
		# draw-material writes between display samples are collapsed. Cohort
		# restart boundaries keep their exact original integer-tick order.
		var interval: int = int(settings.get("cohort_interval_ticks", 405))
		var desired_emission: int = (desired_tick - 1) / interval
		if last_emission < 0:
			_emit_cohort(0)
		if tick < 2 and desired_tick >= 2:
			for group in banks:
				group[0].preprocess = 0.0
		while last_emission < desired_emission:
			_emit_cohort(last_emission + 1)
		tick = desired_tick
		_write_display_clock()
	if not source_transform_known or previous_source_transform != global_transform:
		previous_source_transform = global_transform
		source_transform_known = true
		var inverse := Projection(global_transform.affine_inverse())
		for material in source_materials:
			material.set_shader_parameter("factory_world_to_source", inverse)

func _emit_cohort(emission: int) -> void:
	last_emission = emission
	var cohort_count: int = int(settings.get("cohort_count", 2))
	for group in banks:
		var particle: GPUParticles3D = group[(emission + 1) % cohort_count]
		particle.restart(true)
		particle.emitting = true
		if cohort_count > 2:
			for index in cohort_count:
				group[index].material_override.render_priority = cohort_count - 1 - (((emission + 1) % cohort_count - index + cohort_count) % cohort_count)

func _write_display_clock() -> void:
	var hz := float(parameters.simulation_hz)
	var age := maxf(0.0, float(tick) / hz - float(settings.get("age_offset_seconds", 0.0)))
	var loop_ticks: int = int(settings.get("cloud_loop_ticks", 810))
	for material in mats:
		material.set_shader_parameter("cloud_clock", float(tick % loop_ticks) / hz)
		material.set_shader_parameter("cloud_age", age)
		material.set_shader_parameter("roll_weight", 0.0)
		material.set_shader_parameter("cloud_opacity", 1.0)
		if settings.has("retire_begin_seconds"):
			var retirement := clampf((age - float(settings.retire_begin_seconds)) / float(settings.retire_seconds), 0.0, 1.0)
			material.set_shader_parameter("cloud_retirement", retirement)

func source_bindings() -> Dictionary:
	return {"geometry": geometry, "materials": Array(mats), "static_material_topology": true,
		"prepared_source_layer_mask": prepared_source_layer_mask}

func prepare_source_layer_mask(layer_mask: int) -> void:
	assert(not is_inside_tree(), "Renderer layers must be bound before publication/tree registration")
	assert(layer_mask > 0, "Source layer mask must be supplied explicitly")
	for node: GeometryInstance3D in geometry:
		if node.layers != 0 and node.layers != layer_mask:
			node.layers = layer_mask
	prepared_source_layer_mask = layer_mask

static func accepts_immutable_process(emitter: GPUParticles3D) -> bool:
	return emitter.local_coords and emitter.process_material is ShaderMaterial and emitter.process_material.get_meta("factory_immutable_native_process", "") == "local_coords_static_native_operands"

func immutable_process_contract_valid() -> bool:
	if not shared_native_processes:
		return true
	for group in banks:
		for emitter: GPUParticles3D in group:
			if not accepts_immutable_process(emitter):
				return false
	return true

func capture_observation() -> Dictionary:
	return {"native_tick": tick, "cohort_emission": last_emission,
		"cohort_banks": banks.size(), "geometry": geometry.size(),
		"private_materials": mats.size(), "prepared_source": true,
		"construction_mode": construction_mode,
		"source_art_variant": source_art_variant, "cohort_successor_sorting_offset_delta": cohort_successor_sorting_offset_delta,
		"shared_immutable_native_process": shared_native_processes, "immutable_process_contract_valid": immutable_process_contract_valid(),
		"arbitrary_particle_seeking_qualified": false}


const VfxPackageIO_e4ffdd01f0 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
