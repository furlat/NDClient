extends "res://assets/vfx/sources/0fbe9e56f12742f3ca05/ice_storm_whole_composition.gd"
## Keep the established whole-source/typed-matrix path. Fragment collision
## shapes change, so do not inherit its historical unchanged-physics claim.


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_617c482d75.resource("res://assets/vfx/sources/617c482d75186521eb0f/ice_storm_irregular_composition.gd").new()
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.source_physics_unchanged = false
	result.fracture = {"type": "seeded_closed_voronoi_donor_cells", "pieces_per_chunk": 12,
		"native_rigid_bodies": true, "original_exterior_uv_and_texture": true,
		"motion_rules": "original gravity, fall, outward release, damping and floor collision",
		"total_chunk_mass": 2.4}
	return result

const VfxPackageIO_617c482d75 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
