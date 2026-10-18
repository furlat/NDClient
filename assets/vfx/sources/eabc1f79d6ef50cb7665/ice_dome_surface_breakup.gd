extends "res://assets/vfx/sources/fe6a0d81ec5daed7ad4a/force_construction.gd"
## Private dome correction: actual shell faces enter unscaled native physics.
const SourceMeshBreakup = preload("res://assets/vfx/sources/c04b8d0c9cd074543f4d/source_mesh_breakup.gd")
const SourceSurfaceChunks = preload("res://assets/vfx/sources/0a2a47734d1d3ac1a201/source_surface_chunks.gd")
var assembly_breakup := SourceMeshBreakup.new()
var surface_chunks := SourceSurfaceChunks.new()
var chunk_sources: Array[MeshInstance3D] = []
var transfer_source_age_seconds: float = -1.0


static func make_component(input: Dictionary) -> Node3D:
	assert(input.settings.shape == "ice-dome" and input.settings.mode == "lifecycle")
	assert(input.side == "full" and input.has("surface_partition") and input.has("source_breakup"))
	return construct("res://assets/vfx/sources/eabc1f79d6ef50cb7665/ice_dome_surface_breakup.gd", input)


func make_ice_shell() -> void:
	super.make_ice_shell()
	# Retain the exact current whole surface and cold layers. Its dormant old
	# rimmed latitude bodies are not the intact render surface and are removed.
	for body in ice_bodies:
		body.free()
	ice_bodies.clear()
	surface_chunks.build(ice_whole, parameters.surface_partition)
	for chunk in surface_chunks.chunks:
		var source := MeshInstance3D.new()
		source.name = "ActualShellSurface_%02d" % chunk_sources.size()
		source.mesh = chunk.mesh
		source.material_override = ice_material
		source.visible = false
		subject.add_child(source)
		chunk_sources.append(source)


func _physics_process(_delta: float) -> void:
	# This fixture's explicit shell break is separate from the old hidden
	# Force projectile/contact probe. Native RigidBodies integrate themselves.
	pass


func _transfer_surface(age: float) -> void:
	var specification: Dictionary = parameters.source_breakup
	for key in ["source_seed", "body_mass_kg", "radial_velocity_source_units_per_second",
			"vertical_velocity_source_units_per_second", "angular_velocity_source_limit_radians_per_second"]:
		assert(specification.has(key), "Dome source physics requires explicit " + key)
	var random := RandomNumberGenerator.new()
	random.seed = int(specification.source_seed)
	var motions: Array[Dictionary] = []
	for source in chunk_sources:
		var centre: Vector3 = source.mesh.get_aabb().get_center()
		var radial := Vector3(centre.x, 0.0, centre.z).normalized()
		var angular_limit: float = float(specification.angular_velocity_source_limit_radians_per_second)
		var angular := Vector3(random.randf_range(-angular_limit, angular_limit),
			random.randf_range(-angular_limit, angular_limit), random.randf_range(-angular_limit, angular_limit))
		motions.append({"mass_kg":specification.body_mass_kg,
			"linear_velocity_source_units_per_second":radial * float(specification.radial_velocity_source_units_per_second)
				+ Vector3.UP * float(specification.vertical_velocity_source_units_per_second),
			"angular_velocity_source_radians_per_second":angular})
	assembly_breakup.transfer(self, chunk_sources, subject.global_transform, motions, specification)
	ice_whole.hide()
	ice_broken = true
	collider.collision_layer = 0
	transfer_source_age_seconds = age


func update_ice(age: float) -> void:
	var break_age: float = age - 4.1
	if not ice_broken and break_age >= 0.0:
		_transfer_surface(age)
	var expiry: float = 1.0 - smoothstep(7.2, 7.95, age)
	ice_material.set_shader_parameter("age", age)
	ice_material.set_shader_parameter("opacity", expiry * (1.0 if not ice_broken else 1.0 - smoothstep(1.5, 2.3, break_age)))
	ice_whole.visible = not ice_broken
	assembly_breakup.sync_uniforms(["age", "opacity", "factory_world_to_source"])
	if age >= 6.4:
		assembly_breakup.retire()
	var air_opacity: float = expiry * smoothstep(0.0, .4, break_age)
	ice_air_material.set_shader_parameter("opacity", air_opacity)
	var clock: float = fposmod(age, 4.0) / 4.0
	for index in ice_flakes.size():
		var phase: float = fposmod(clock + float(index) * .61803398875, 1.0)
		var angle: float = float(index) / 24.0 * TAU
		var phi: float = .25 + float(index % 6) / 6.0 * 1.20
		var point: Vector3 = sphere_position(angle, phi, RADIUS)
		point.y -= .25 * phase
		ice_flakes[index].position = point
		ice_flake_materials[index].set_shader_parameter("opacity",
			air_opacity * .36 * smoothstep(0.0, .14, phase) * (1.0 - smoothstep(.8, 1.0, phase)))


func update_geometry() -> void:
	assembly_breakup.sync_uniforms(["factory_world_to_source"])


func capture_observation() -> Dictionary:
	return {"ice_dome_surface_breakup":assembly_breakup.observation(),
		"source_surface_partition":surface_chunks.observation(),
		"transfer_source_age_seconds":transfer_source_age_seconds,
		"fixture_source_break_seconds":4.1, "fixture_only_no_damage_or_hp_claim":true,
		"original_body_fade_source_interval_seconds":[5.6, 6.4],
		"original_cold_expiry_source_interval_seconds":[7.2, 7.95],
		"original_cold_flakes":ice_flakes.size(), "old_rimmed_grid_bodies":ice_bodies.size(),
		"native_tick":tick, "intact_whole_visible":ice_whole.visible,
		"optical_lights":find_children("*", "Light3D", true, false).size()}
