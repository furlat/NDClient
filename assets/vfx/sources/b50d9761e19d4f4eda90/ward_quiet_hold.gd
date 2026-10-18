extends "res://assets/vfx/sources/c9b08b288e56a08b0458/ward.gd"
## Retain the native ward application/trigger. Only the long-lived star is
## compacted; this is not another room-sized radial burst during the hold.

static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/b50d9761e19d4f4eda90/ward_quiet_hold.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	if settings.id != "ward_hold":
		return
	var star := node.get_node("MeshInstance3D") as MeshInstance3D
	# The donor's billboard constructs MODELVIEW_MATRIX from camera basis,
	# discarding model scale. Resize its private QuadMesh, not its ignored basis.
	var quad := star.mesh.duplicate() as QuadMesh
	quad.size *= float(settings.get("sustain_star_scale", 0.40))
	star.mesh = quad
	star.scale = Vector3.ONE
	var aura := node.get_node("Aura") as GPUParticles3D
	var process := aura.process_material as ParticleProcessMaterial
	process.scale_min *= 0.65
	process.scale_max *= 0.65
	process.emission_sphere_radius *= 0.70

