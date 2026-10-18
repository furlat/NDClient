extends "res://assets/vfx/sources/0a6f9152e753968f33d1/divine.gd"
## Preserve the two authored W1 wisps with shorter, wider particle proportions.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/e05313730c1f6867fb65/healing_word_wisps.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var index: int = 0
	for path in ["verticalflash", "SecondaryAuthoredHealingWisp"]:
		var wisp: GPUParticles3D = node.get_node(path)
		wisp.process_material = wisp.process_material.duplicate(true)
		var process: ParticleProcessMaterial = wisp.process_material
		process.scale_min *= 0.32
		process.scale_max *= 0.32
		if process.scale_curve is CurveXYZTexture:
			var axes: CurveXYZTexture = process.scale_curve
			axes.curve_x = axes.curve_x.duplicate(true)
			axes.curve_y = axes.curve_y.duplicate(true)
			for point in axes.curve_x.point_count:
				axes.curve_x.set_point_value(point, axes.curve_x.get_point_position(point).y * 2.4)
			for point in axes.curve_y.point_count:
				axes.curve_y.set_point_value(point, axes.curve_y.get_point_position(point).y * 0.55)
		wisp.rotation.z = -0.22 if index == 0 else 0.25
		wisp.position.x = -0.18 if index == 0 else 0.18
		wisp.lifetime = 0.75 if index == 0 else 0.60
		index += 1
