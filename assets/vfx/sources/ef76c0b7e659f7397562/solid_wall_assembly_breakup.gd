extends "res://assets/vfx/sources/f57d0f975305d2695061/solid_wall_palette_join.gd"
## Private corrective: actual broken sculpture/pillars/boulders enter physics.
const SourceMeshBreakup = preload("res://assets/vfx/sources/c04b8d0c9cd074543f4d/source_mesh_breakup.gd")
var assembly_breakup := SourceMeshBreakup.new()
var transfer_source_age_seconds: float = -1.0


static func make_component(input: Dictionary) -> Node3D:
	assert(input.settings.kind == "stone" and input.side == "whole")
	assert(input.has("source_breakup"))
	return construct("res://assets/vfx/sources/ef76c0b7e659f7397562/solid_wall_assembly_breakup.gd", input)


func shatter() -> void:
	assert(not broken)
	var specification: Dictionary = parameters.source_breakup
	for key in ["source_seed", "body_mass_kg", "velocity_side_source_units_per_second", "velocity_rise_source_units_per_second",
			"velocity_rise_step_source_units_per_second", "velocity_forward_source_units_per_second",
			"velocity_forward_step_source_units_per_second", "angular_velocity_source_radians_per_second", "seeded_yaw"]:
		assert(specification.has(key), "Stone source motion requires explicit " + key)
	var broken_index: int = 0 if settings.get("single_section", false) else 1
	var sources: Array[MeshInstance3D] = []
	for child in panels[broken_index].get_children():
		assert(child is MeshInstance3D, "The actual broken section contains explicit source MeshInstances")
		sources.append(child)
	# Retain original source velocity/spin magnitudes. A disclosed seeded yaw
	# gives this new assembly transfer deterministic azimuth, not old debris paths.
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
	return {"stone_assembly_breakup":assembly_breakup.observation(),
		"transfer_source_age_seconds":transfer_source_age_seconds,
		"original_shatter_threshold_source_seconds":break_time + .13,
		"retirement_source_interval_seconds":[6.0,6.85], "native_tick":tick,
		"original_sculpture_pillars_boulders":true, "whole_native_geometry":side == "whole",
		"source_brown_finish":parameters.finishing, "optical_lights":find_children("*","Light3D",true,false).size()}
