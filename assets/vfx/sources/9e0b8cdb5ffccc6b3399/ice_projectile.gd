extends "res://assets/vfx/sources/843204815cdceaac8544/clocked_source.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/9e0b8cdb5ffccc6b3399/ice_projectile.gd", input)


func apply_scene_edits(node: Node) -> void:
	var knife: bool = parameters.scene.contains("IceLance")
	var mesh = node.get_node_or_null("SmRocksStone4002" if knife else "FireTorch_AC")
	if mesh != null:
		mesh.transform = (
			Transform3D(
				Basis.from_scale(Vector3(1.45, 1.45, 2.0) if knife else Vector3(1, 1, 1.7)),
				Vector3.ZERO
			)
			* mesh.transform
		)
	if parameters.scene.contains("RayIceTrail"):
		for child in node.get_children():
			if child is VisualInstance3D:
				child.layers = 0
		var donor = (
			VfxPackageIO_9e0b8cdb5f.resource(
				"res://assets/vfx/sources/8a1e9034ec9bf2cb095f/VFX_IceHit_T1.tscn"
			)
			. instantiate()
		)
		var shards = donor.get_node("debirs").duplicate()
		donor.free()
		shards.name = "AuthoredIceFragments"
		shards.one_shot = false
		shards.explosiveness = 0.0
		shards.amount = 24
		shards.lifetime = 0.55
		shards.local_coords = false
		shards.use_fixed_seed = true
		shards.seed = 47291
		shards.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
		shards.process_material = shards.process_material.duplicate(true)
		shards.process_material.gravity = Vector3(0, -0.6, 0)
		shards.process_material.emission_sphere_radius = 0.6
		shards.process_material.initial_velocity_min = 0.5
		shards.process_material.initial_velocity_max = 1.5
		shards.process_material.radial_velocity_min = 0.0
		shards.process_material.radial_velocity_max = 1.2
		shards.process_material.scale_min = 0.22
		shards.process_material.scale_max = 0.5
		shards.process_material.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
		node.add_child(shards)
		shards.emitting = true

const VfxPackageIO_9e0b8cdb5f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
