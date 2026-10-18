extends "res://assets/vfx/sources/5f4f2cab205638c25d81/ice_storm.gd"
## Same donor triangles, closed octants and impact material. Native fragments
## exist before renderer registration and use correct parent-local transforms.

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/c114c68e321f3cb1dcb1/native_ice_chunk.gd", input)

func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for part in pieces:
		var body := RigidBody3D.new()
		body.mass = .30
		body.gravity_scale = GRAVITY / 9.8
		body.linear_damp = 1.1
		body.angular_damp = 2.0
		body.continuous_cd = true
		body.freeze = true
		var physics := PhysicsMaterial.new()
		physics.friction = .86
		physics.bounce = .12
		body.physics_material_override = physics
		node.add_child(body)
		var collision := CollisionShape3D.new()
		collision.shape = part.mesh.create_convex_shape()
		body.add_child(collision)
		var draw := MeshInstance3D.new()
		draw.mesh = part.mesh
		draw.visible = false
		node.add_child(draw)
		bodies.append(body)
		visuals.append(draw)

func shatter(_node: Node) -> void:
	shattered = true
	chunk.visible = false
	var selected_basis := pose(hit_time)
	var selected_centre := centre(hit_time)
	for index in pieces.size():
		var part: Dictionary = pieces[index]
		var body: RigidBody3D = bodies[index]
		body.transform = Transform3D(selected_basis, selected_centre + selected_basis * part.pivot)
		body.freeze = false
		var outward: Vector3 = selected_basis * part.pivot
		outward.y = 0.0
		outward = outward.normalized()
		body.linear_velocity = outward * (.40 + rng.randf() * .65) + Vector3(0.,.55 + rng.randf() * .9,0.)
		body.angular_velocity = Vector3(rng.randf_range(-2.,2.),rng.randf_range(-2.,2.),rng.randf_range(-2.,2.))
		visuals[index].visible = true

func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	for index in bodies.size():
		var local_pose := (visuals[index].get_parent() as Node3D).global_transform.affine_inverse() * bodies[index].global_transform
		visuals[index].transform = local_pose.scaled(Vector3(1.,YC,1.))
