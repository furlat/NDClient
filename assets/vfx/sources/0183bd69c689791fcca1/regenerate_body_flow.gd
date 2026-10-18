extends "res://assets/vfx/sources/9f4940b0a6da8d0eedfb/regenerate_compact.gd"
## Retain Regenerate's source leaves, aura, material, loop and explicit heal pulse.
## Bound upward transport around its recipient rather than building a tall crown.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/0183bd69c689791fcca1/regenerate_body_flow.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var fit: Dictionary = parameters.receiving_buff
	node.position.y *= float(fit.vertical_origin_gain)
	for particles in node.find_children("*", "GPUParticles3D", true, false):
		var process: ParticleProcessMaterial = particles.process_material
		process.directional_velocity_min *= float(fit.vertical_travel_gain)
		process.directional_velocity_max *= float(fit.vertical_travel_gain)
		process.gravity.y = float(fit.vertical_gravity)
