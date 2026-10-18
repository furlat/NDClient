extends "res://assets/vfx/sources/41bda60be893f43ae18e/solid_wall.gd"
## Private Ice correction: transfer actual source assembly, keep its cold layers.
const SourceMeshBreakup = preload("res://assets/vfx/sources/c04b8d0c9cd074543f4d/source_mesh_breakup.gd")
var assembly_breakup := SourceMeshBreakup.new()
var transfer_source_age_seconds: float = -1.0


static func make_component(input: Dictionary) -> Node3D:
	assert(input.settings.kind == "ice" and input.settings.shape == "straight")
	assert(input.side == "full" and input.has("source_breakup"))
	assert(not input.has("finishing"), "Preserve the current native Ice material without a new export palette")
	return construct("res://assets/vfx/sources/51beb78aeb4520031c07/ice_wall_assembly_breakup.gd", input)


func shatter() -> void:
	assert(not broken)
	var specification: Dictionary = parameters.source_breakup
	for key in ["source_seed", "body_mass_kg", "velocity_side_source_units_per_second", "velocity_rise_source_units_per_second",
			"velocity_rise_step_source_units_per_second", "velocity_forward_source_units_per_second",
			"velocity_forward_step_source_units_per_second", "angular_velocity_source_radians_per_second", "seeded_yaw"]:
		assert(specification.has(key), "Ice source motion requires explicit " + key)
	var broken_index: int = 0 if settings.get("single_section", false) else 1
	var sources: Array[MeshInstance3D] = []
	for child in panels[broken_index].get_children():
		assert(child is MeshInstance3D, "Transfer the actual Ice section leaf MeshInstances")
		sources.append(child)
	# This assembly has ten source shapes, not the old 24 unrelated particles.
	# Original velocity/spin magnitudes remain; seeded yaw is a disclosed new path.
	var random := RandomNumberGenerator.new()
	random.seed = int(specification.source_seed)
	var yaw: float = random.randf_range(0.0, TAU) if bool(specification.seeded_yaw) else 0.0
	var velocity_rotation := Basis(Vector3.UP, yaw)
	var angular: Array = specification.angular_velocity_source_radians_per_second
	assert(angular.size() == 3)
	var motions: Array[Dictionary] = []
	for index in sources.size():
		var direction: float = -1.0 if index % 2 == 0 else 1.0
		var linear := Vector3(float(specification.velocity_side_source_units_per_second) * sin(float(index) * 2.399),
			float(specification.velocity_rise_source_units_per_second) + float(index % 3) * float(specification.velocity_rise_step_source_units_per_second),
			direction * (float(specification.velocity_forward_source_units_per_second) + float(index % 4) * float(specification.velocity_forward_step_source_units_per_second)))
		var spin := Vector3(float(angular[0]) * sin(float(index) * 1.7), float(angular[1]) * cos(float(index) * 2.1), float(angular[2]) * sin(float(index) * .7))
		motions.append({"mass_kg":specification.body_mass_kg,
			"linear_velocity_source_units_per_second":velocity_rotation * linear,
			"angular_velocity_source_radians_per_second":velocity_rotation * spin})
	assembly_breakup.transfer(self, sources, subject.global_transform, motions, specification)
	for pair in assembly_breakup.material_pairs:
		if pair.material is ShaderMaterial:
			mats.append(pair.material)
	transfer_source_age_seconds = float(tick) / float(parameters.simulation_hz)
	broken = true
	panels[broken_index].hide()


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	if assembly_breakup.transferred:
		var broken_index: int = 0 if settings.get("single_section", false) else 1
		panels[broken_index].hide()
		assembly_breakup.sync_uniforms(["opacity", "wall_clock", "actor_ground", "factory_world_to_source"])
		if float(tick) / float(parameters.simulation_hz) >= 6.85:
			assembly_breakup.retire()


func update_geometry() -> void:
	super.update_geometry()
	if assembly_breakup.transferred:
		assembly_breakup.sync_uniforms(["factory_world_to_source"])


func capture_observation() -> Dictionary:
	return {"ice_assembly_breakup":assembly_breakup.observation(),
		"transfer_source_age_seconds":transfer_source_age_seconds,
		"original_shatter_threshold_source_seconds":break_time + .13,
		"retirement_source_interval_seconds":[6.0, 6.85], "native_tick":tick,
		"actual_source_sculpture_pillars_boulders":true, "original_native_side":side,
		"original_ice_material":true, "source_air_layers":air.size(),
		"source_frost_flakes":frost_flakes.size(),
		"optical_lights":find_children("*", "Light3D", true, false).size()}
