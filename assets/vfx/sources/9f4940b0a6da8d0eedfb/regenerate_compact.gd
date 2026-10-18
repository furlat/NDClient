extends "res://assets/vfx/sources/2bc32a498b43894b5603/conditions.gd"
## Private receiving-body fit; original nature/leaf layers, curves and clock remain.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/9f4940b0a6da8d0eedfb/regenerate_compact.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var fit: Dictionary = parameters.receiving_buff
	# Undo only the inherited Regenerate-specific horizontal enlargement.
	node.scale.x /= 1.25
	node.scale.z /= 1.25
	for particle in node.find_children("*", "GPUParticles3D", true, false):
		var process: ParticleProcessMaterial = particle.process_material
		var size_gain: float = float(fit.aura_size_gain if particle.name == "Aura" else fit.leaf_size_gain)
		process.scale_min *= size_gain
		process.scale_max *= size_gain
		process.emission_shape_scale.y *= .6
		process.gravity.y *= .45
		process.emission_shape_scale.x *= float(fit.radial_extent_gain)
		process.emission_shape_scale.z *= float(fit.radial_extent_gain)
		process.radial_velocity_min *= float(fit.radial_travel_gain)
		process.radial_velocity_max *= float(fit.radial_travel_gain)
		process.radial_accel_min *= float(fit.radial_travel_gain)
		process.radial_accel_max *= float(fit.radial_travel_gain)


func advance_lifecycle(delta: float) -> void:
	super.advance_lifecycle(delta)
	var fit: Dictionary = parameters.receiving_buff
	var age: float = float(tick) / 144.0
	var held_gain: float = lerpf(1.0, float(fit.held_alpha_gain), smoothstep(0.8, 1.6, age))
	for material in materials:
		# Multiply the source envelope, retaining its explicit healing pulse/end.
		var source_alpha: float = float(material.get_shader_parameter("support_envelope"))
		material.set_shader_parameter("support_envelope", source_alpha * held_gain)
