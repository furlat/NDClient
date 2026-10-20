extends "res://assets/vfx/sources/c04b8d0c9cd074543f4d/source_mesh_breakup.gd"
## Native rigid physics with offline exact hulls; no hit-time mesh/material scan.
var draws: Array[MeshInstance3D] = []
var private_materials: Array[ShaderMaterial] = []
var templates: Array[Dictionary] = []
var bodies: Array[RID] = []
var display_offsets: Array[Transform3D] = []
var contact_counts: Array[int] = []
var initial_world_transforms: Array[Transform3D] = []
var initial_body_transforms: Array[Transform3D] = []
var birth_records: Array[Dictionary] = []
var initial_linear_velocities: Array[Vector3] = []
var initial_angular_velocities: Array[Vector3] = []
var configured_world := Transform3D.IDENTITY
var motion_operands: Array[Dictionary] = []
var closed := false
var callback_max_us := 0
var callback_calls := 0
var callback_frame := -1
var callback_frame_us := 0
var callback_frame_max_us := 0
var collision_transform_known := false
var collision_source_transform := Transform3D.IDENTITY

func prepare(owner: Node3D, parts: Array[Dictionary], materials: Array[ShaderMaterial]) -> void:
	templates.assign(parts)
	motion_operands.assign(owner.bank.break_motions)
	physics_root = Node3D.new()
	physics_root.name = "PreparedExactSourceBodies"
	physics_root.top_level = true
	owner.add_child(physics_root)
	var material_indices := {}
	for part in parts:
		var index := int(part.material)
		if not material_indices.has(index):
			material_indices[index] = private_materials.size()
			private_materials.append(materials[index].duplicate(false))
			material_pairs.append({"source":materials[index], "material":private_materials.back()})
		var reuse: bool = owner.settings.get("shape", "") == "ice-dome"
		var visual: MeshInstance3D = owner.subject.get_node(part.source_node) if reuse else MeshInstance3D.new()
		if reuse:
			visual.top_level = true
		else:
			visual.name = "ExactSourceVisual%02d" % draws.size()
			visual.mesh = part.mesh
		visual.material_override = private_materials[int(material_indices[index])]
		visual.hide()
		if not reuse:
			physics_root.add_child(visual)
		draws.append(visual)
		var body := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(body, 0)
		PhysicsServer3D.body_set_collision_mask(body, 0)
		PhysicsServer3D.body_add_shape(body, part.shape.get_rid())
		var specification: Dictionary = owner.parameters.source_breakup
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_MASS, float(specification.body_mass_kg))
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_LINEAR_DAMP, float(specification.linear_damp_per_second))
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_ANGULAR_DAMP, float(specification.angular_damp_per_second))
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_FRICTION, float(specification.friction))
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_BOUNCE, float(specification.bounce))
		PhysicsServer3D.body_set_enable_continuous_collision_detection(body, true)
		PhysicsServer3D.body_set_max_contacts_reported(body, 8)
		PhysicsServer3D.body_set_state_sync_callback(body, _sync_state.bind(bodies.size()))
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_SLEEPING, true)
		bodies.append(body)
		display_offsets.append(Transform3D.IDENTITY)
		initial_world_transforms.append(Transform3D.IDENTITY)
		initial_body_transforms.append(Transform3D.IDENTITY)
		initial_linear_velocities.append(Vector3.ZERO)
		initial_angular_velocities.append(Vector3.ZERO)
		var source: MeshInstance3D = owner.runtime_break_sources[birth_records.size()]
		birth_records.append({"source":source, "visual":visual, "body_rid":body,
			"before_transform":Transform3D.IDENTITY, "initial_body_transform":Transform3D.IDENTITY,
			"source_mesh_id":source.mesh.get_instance_id(), "body_mesh_id":visual.mesh.get_instance_id()})
		contact_counts.append(0)

func attach_world(owner: Node3D) -> void:
	physics_root.global_transform = Transform3D.IDENTITY
	for body in bodies:
		PhysicsServer3D.body_set_space(body, owner.get_world_3d().space)
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_SLEEPING, true)

func update_source_transform(transform: Transform3D, specification: Dictionary) -> void:
	if transferred or collision_transform_known and collision_source_transform == transform:
		return
	var lengths := Vector3(transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length())
	assert(lengths.x > 0.0 and is_equal_approx(lengths.x, lengths.y) and is_equal_approx(lengths.x, lengths.z),
		"Retain original explicit uniform source-unit conversion")
	assert(transform.basis.determinant() > 0.0)
	assert(absf(transform.basis.x.dot(transform.basis.y)) < .00001 and absf(transform.basis.x.dot(transform.basis.z)) < .00001 and absf(transform.basis.y.dot(transform.basis.z)) < .00001,
		"Retain original no-shear native physics contract")
	assert(transform.basis.orthonormalized().y.is_equal_approx(Vector3.UP), "Retain original upright native gravity contract")
	collision_transform_known = true
	collision_source_transform = transform
	configured_world = transform
	var scale := transform.basis.x.length()
	var engine_gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var orientation := transform.basis.orthonormalized()
	for index in bodies.size():
		var body := bodies[index]
		PhysicsServer3D.body_set_shape_transform(body, 0, Transform3D(transform.basis, Vector3.ZERO))
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_GRAVITY_SCALE,
			float(specification.gravity_source_units_per_second_squared) * scale / engine_gravity)
		# Godot Physics approximates convex inertia from the hull AABB and
		# ignores collision-shape scale. The original baked world-space hull
		# therefore has a different automatic inertia from an affine instance.
		# Retain that exact original approximation using its real hull vertices.
		var hull: PackedVector3Array = templates[index].hull_vertices
		var bounds := AABB(transform.basis * hull[0], Vector3.ZERO)
		for vertex in hull:
			bounds = bounds.expand(transform.basis * vertex)
		var extent := bounds.size * .5
		var factor := float(specification.body_mass_kg) / 3.0
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_INERTIA,
			Vector3(factor * (extent.y * extent.y + extent.z * extent.z),
				factor * (extent.x * extent.x + extent.z * extent.z),
				factor * (extent.x * extent.x + extent.y * extent.y)))
		# Pre-arm exact initial source operands while both collision channels
		# remain zero and the native body sleeps. Source birth only admits it;
		# no mesh scan or matrix inversion occurs at the hit.
		var before: Transform3D = transform * templates[index].source_transform
		var initial := Transform3D(Basis.IDENTITY, before * templates[index].mesh.get_aabb().get_center())
		initial_world_transforms[index] = before
		draws[index].global_transform = before
		initial_body_transforms[index] = initial
		birth_records[index].before_transform = before
		birth_records[index].initial_body_transform = initial
		initial_linear_velocities[index] = transform.basis * motion_operands[index].linear_velocity_source_units_per_second
		initial_angular_velocities[index] = orientation * motion_operands[index].angular_velocity_source_radians_per_second
		display_offsets[index] = initial.affine_inverse() * before
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, initial)
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_SLEEPING, true)

func transfer(owner: Node3D, sources: Array[MeshInstance3D], source_to_world: Transform3D,
		motions: Array[Dictionary], specification: Dictionary) -> void:
	assert(not transferred and sources.size() == templates.size() and sources.size() == motions.size())
	assert(motions == motion_operands, "Only the exact source-seeded motion operands were pre-armed")
	var lengths := Vector3(source_to_world.basis.x.length(), source_to_world.basis.y.length(), source_to_world.basis.z.length())
	assert(lengths.x > 0.0 and is_equal_approx(lengths.x, lengths.y) and is_equal_approx(lengths.x, lengths.z))
	assert(source_to_world.basis.determinant() > 0.0)
	var orientation := source_to_world.basis.orthonormalized()
	assert(orientation.y.is_equal_approx(Vector3.UP), "Retain original upright native gravity contract")
	source_unit_world_scale = lengths.x
	source_seed = int(specification.source_seed)
	update_source_transform(source_to_world, specification)
	for index in sources.size():
		var source := sources[index]
		var part: Dictionary = templates[index]
		var initial: Transform3D = initial_body_transforms[index]
		var body := bodies[index]
		var motion: Dictionary = motions[index]
		assert(source.mesh == part.mesh, "Only the actual prepared source sculpture can transfer")
		# The hull keeps the exact source affine map. World rotation/scale stays
		# live in its native shape transform, not baked to a replacement mesh.
		assert(float(motion.mass_kg) == float(specification.body_mass_kg))
		# Dormant bodies are truly static, not merely sleeping dynamic bodies:
		# the native renderer/physics schedule can wake sleeping RIDs before
		# admission. Activate and restore the exact birth transform atomically.
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_RIGID)
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, initial)
		PhysicsServer3D.body_set_collision_layer(body, int(specification.body_collision_layer))
		PhysicsServer3D.body_set_collision_mask(body, int(specification.floor_collision_mask))
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_SLEEPING, false)
		# Entering native sleep clears velocities; retain both source operands
		# at the real wake rather than relying on pre-sleep state uploads.
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY,
			initial_linear_velocities[index])
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY,
			initial_angular_velocities[index])
	pieces.assign(birth_records)
	for source in sources:
		source.hide()
	for visual in draws:
		visual.show()
		visual.reset_physics_interpolation()
	transferred = true

func _sync_state(state: PhysicsDirectBodyState3D, index: int) -> void:
	var started := Time.get_ticks_usec()
	if transferred and not retired and not closed and is_instance_valid(draws[index]):
		draws[index].global_transform = state.transform * display_offsets[index]
		contact_counts[index] = state.get_contact_count()
		callback_calls += 1
		var frame := Engine.get_physics_frames()
		if frame != callback_frame:
			callback_frame = frame
			callback_frame_us = 0
		var duration := Time.get_ticks_usec() - started
		callback_max_us = maxi(callback_max_us, duration)
		callback_frame_us += duration
		callback_frame_max_us = maxi(callback_frame_max_us, callback_frame_us)

func retire() -> void:
	if retired or not transferred:
		return
	retired = true
	physics_root.hide()
	for draw in draws:
		draw.hide()
	for body in bodies:
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_SLEEPING, true)
		PhysicsServer3D.body_set_collision_layer(body, 0)
		PhysicsServer3D.body_set_collision_mask(body, 0)

func close() -> void:
	if closed:
		return
	closed = true
	for body in bodies:
		PhysicsServer3D.body_set_state_sync_callback(body, Callable())
		PhysicsServer3D.free_rid(body)
	bodies.clear()

func observation() -> Dictionary:
	return {"transferred":transferred, "retired":retired, "source_seed":source_seed,
		"source_unit_world_scale":source_unit_world_scale, "native_physics_required":true,
		"source_shapes":templates.size(), "native_bodies":bodies.size(),
		"exact_source_meshes":draws.size(), "callback_max_us":callback_max_us,
		"callback_calls":callback_calls, "callback_frame_max_us":callback_frame_max_us,
		"contact_counts":contact_counts, "rules_evaluated":false}
