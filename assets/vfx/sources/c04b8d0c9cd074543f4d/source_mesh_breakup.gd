extends RefCounted
## Atomic visual-assembly transfer into world-space native physics.
## Mesh arrays stay exact; convex points bake the same source-to-body affine map.
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")

var physics_root: Node3D
var pieces: Array[Dictionary] = []
var material_pairs: Array[Dictionary] = []
var transferred: bool = false
var retired: bool = false
var source_seed: int = 0
var source_unit_world_scale: float = 0.0


func transfer(owner: Node3D, sources: Array[MeshInstance3D], source_to_world: Transform3D,
		motions: Array[Dictionary], specification: Dictionary) -> void:
	assert(not transferred and not sources.is_empty())
	assert(sources.size() == motions.size())
	for key in ["source_seed", "gravity_source_units_per_second_squared", "linear_damp_per_second",
			"angular_damp_per_second", "friction", "bounce", "contact_margin_source_units",
			"body_collision_layer", "floor_collision_mask"]:
		assert(specification.has(key), "Source breakup requires explicit " + key)
	source_seed = int(specification.source_seed)
	var lengths := Vector3(source_to_world.basis.x.length(), source_to_world.basis.y.length(), source_to_world.basis.z.length())
	assert(lengths.x > 0.0 and is_equal_approx(lengths.x, lengths.y) and is_equal_approx(lengths.x, lengths.z), "Occurrence physics requires explicit uniform source-unit conversion")
	assert(source_to_world.basis.determinant() > 0.0)
	source_unit_world_scale = lengths.x
	assert(absf(source_to_world.basis.x.dot(source_to_world.basis.y)) < .00001 and absf(source_to_world.basis.x.dot(source_to_world.basis.z)) < .00001 and absf(source_to_world.basis.y.dot(source_to_world.basis.z)) < .00001, "Sheared source occurrences require a different explicit physics conversion")
	var orientation: Basis = source_to_world.basis.orthonormalized()
	assert(orientation.y.is_equal_approx(Vector3.UP), "Source gravity conversion supports upright occurrences; tilted gravity requires a different explicit contract")
	var engine_gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	assert(engine_gravity > 0.0)
	var engine_direction: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	assert(engine_direction.normalized().is_equal_approx(Vector3.DOWN))
	physics_root = Node3D.new()
	physics_root.name = "SourceMeshBreakupWorld"
	physics_root.top_level = true
	owner.add_child(physics_root)
	physics_root.global_transform = Transform3D.IDENTITY
	for index in sources.size():
		var source: MeshInstance3D = sources[index]
		var motion: Dictionary = motions[index]
		for key in ["mass_kg", "linear_velocity_source_units_per_second", "angular_velocity_source_radians_per_second"]:
			assert(motion.has(key), "Source body motion requires explicit " + key)
		assert(source.mesh != null and source.mesh.get_surface_count() > 0)
		var before: Transform3D = source.global_transform
		var body_transform := Transform3D(Basis.IDENTITY, before * source.mesh.get_aabb().get_center())
		var visual: MeshInstance3D = source.duplicate(0) as MeshInstance3D
		assert(visual != null and visual.get_child_count() == 0, "Source assembly expects explicit leaf MeshInstances")
		ResourceGraph.isolate_node(visual, {})
		visual.name = "ExactSourceVisual"
		visual.visible = true
		visual.transform = body_transform.affine_inverse() * before
		var body := RigidBody3D.new()
		body.name = "SourceMeshBody_%02d" % index
		body.freeze = true
		body.mass = float(motion.mass_kg)
		body.linear_damp = float(specification.linear_damp_per_second)
		body.angular_damp = float(specification.angular_damp_per_second)
		body.gravity_scale = float(specification.gravity_source_units_per_second_squared) * source_unit_world_scale / engine_gravity
		body.collision_layer = int(specification.body_collision_layer)
		body.collision_mask = int(specification.floor_collision_mask)
		assert((body.collision_layer & body.collision_mask) == 0, "Overlapping source assemblies explicitly exclude peer collision")
		body.continuous_cd = true
		body.contact_monitor = true
		body.max_contacts_reported = 8
		body.physics_material_override = PhysicsMaterial.new()
		body.physics_material_override.friction = float(specification.friction)
		body.physics_material_override.bounce = float(specification.bounce)
		physics_root.add_child(body)
		body.global_transform = body_transform
		body.add_child(visual)
		var points := PackedVector3Array()
		for vertex in visual.mesh.get_faces():
			points.append(visual.transform * vertex)
		assert(points.size() >= 4)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		shape.margin = float(specification.contact_margin_source_units) * source_unit_world_scale
		var collider := CollisionShape3D.new()
		collider.name = "SourceAffineConvexHull"
		collider.shape = shape
		body.add_child(collider)
		var vertex_error: float = 0.0
		var normal_error: float = 0.0
		var arrays_equal: bool = true
		var vertices_checked: int = 0
		for surface in source.mesh.get_surface_count():
			var old_arrays: Array = source.mesh.surface_get_arrays(surface)
			var new_arrays: Array = visual.mesh.surface_get_arrays(surface)
			arrays_equal = arrays_equal and old_arrays == new_arrays
			var vertices: PackedVector3Array = old_arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = old_arrays[Mesh.ARRAY_NORMAL]
			for vertex_index in vertices.size():
				vertex_error = maxf(vertex_error, (before * vertices[vertex_index]).distance_to(visual.global_transform * vertices[vertex_index]))
				vertices_checked += 1
				if normals.size() == vertices.size():
					var old_normal: Vector3 = (before.basis.inverse().transposed() * normals[vertex_index]).normalized()
					var new_normal: Vector3 = (visual.global_basis.inverse().transposed() * normals[vertex_index]).normalized()
					normal_error = maxf(normal_error, old_normal.distance_to(new_normal))
		assert(arrays_equal and vertex_error < .00001 and normal_error < .00001, "Source handoff must preserve all mesh arrays and world-space vertices/normals")
		_record_materials(source, visual)
		pieces.append({"source":source, "visual":visual, "body":body, "collider":collider,
			"before_transform":before, "initial_body_transform":body_transform,
			"source_mesh_id":source.mesh.get_instance_id(), "body_mesh_id":visual.mesh.get_instance_id(),
			"world_vertex_error":vertex_error, "world_normal_error":normal_error,
			"mesh_arrays_equal":arrays_equal, "vertices_checked":vertices_checked,
			"initial_linear_velocity_world_units_per_second":source_to_world.basis * motion.linear_velocity_source_units_per_second,
			"initial_angular_velocity_world_radians_per_second":orientation * motion.angular_velocity_source_radians_per_second})
	# Admit all bodies and hide all source visuals in one sampler operation.
	# No old panel plus replacement overlap is exposed to a rendered frame.
	for piece in pieces:
		piece.source.hide()
	for piece in pieces:
		piece.body.freeze = false
		piece.body.linear_velocity = piece.initial_linear_velocity_world_units_per_second
		piece.body.angular_velocity = piece.initial_angular_velocity_world_radians_per_second
		piece.body.reset_physics_interpolation()
	transferred = true


func _record_materials(source: MeshInstance3D, visual: MeshInstance3D) -> void:
	for surface in source.mesh.get_surface_count():
		var original: Material = source.get_active_material(surface)
		var copied: Material = visual.get_active_material(surface)
		assert(original != null and copied != null and original != copied)
		var already_recorded: bool = material_pairs.any(func(pair: Dictionary) -> bool: return pair.material == copied)
		if not already_recorded:
			material_pairs.append({"source":original, "material":copied})


func sync_uniforms(names: Array[String]) -> void:
	for pair in material_pairs:
		if pair.source is ShaderMaterial and pair.material is ShaderMaterial:
			for uniform in names:
				var value: Variant = pair.source.get_shader_parameter(uniform)
				if value != null:
					pair.material.set_shader_parameter(uniform, value)


func retire() -> void:
	if retired or not transferred:
		return
	retired = true
	physics_root.hide()
	for piece in pieces:
		piece.body.freeze = true
		piece.body.collision_layer = 0
		piece.body.collision_mask = 0


func observation() -> Dictionary:
	var records: Array = []
	for piece in pieces:
		var body: RigidBody3D = piece.body
		records.append({"source_path":str(physics_root.get_parent().get_path_to(piece.source)),
			"source_mesh_id":piece.source_mesh_id, "body_mesh_id":piece.body_mesh_id,
			"mesh_arrays_equal":piece.mesh_arrays_equal, "vertices_checked":piece.vertices_checked,
			"handoff_world_vertex_error":piece.world_vertex_error, "handoff_world_normal_error":piece.world_normal_error,
			"source_hidden":not piece.source.visible, "body_world_position":body.global_position,
			"body_world_basis_lengths":Vector3(body.global_basis.x.length(),body.global_basis.y.length(),body.global_basis.z.length()),
			"linear_velocity_world_units_per_second":body.linear_velocity, "angular_velocity_world_radians_per_second":body.angular_velocity,
			"initial_linear_velocity_world_units_per_second":piece.initial_linear_velocity_world_units_per_second,
			"initial_angular_velocity_world_radians_per_second":piece.initial_angular_velocity_world_radians_per_second,
			"gravity_scale":body.gravity_scale, "native_contact_count":body.get_contact_count(),
			"collision_layer":body.collision_layer, "collision_mask":body.collision_mask})
	return {"transferred":transferred, "retired":retired, "source_seed":source_seed,
		"source_unit_world_scale":source_unit_world_scale, "physics_root_unit_basis":physics_root == null or physics_root.global_basis.is_equal_approx(Basis.IDENTITY),
		"peer_collision":false, "collision_approximation":"independent convex hull per exact source mesh; source assembly overlaps intentionally",
		"native_physics_required":true, "rules_evaluated":false, "pieces":records}
