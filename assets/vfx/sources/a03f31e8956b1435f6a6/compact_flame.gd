extends "res://assets/vfx/sources/eccdd7fc27b746bb3958/compact_flame.gd"
## Source projectile and emitters exist before the renderer enumerates them.


static func make_component(input: Dictionary) -> Node3D:
	var selected := input.duplicate(true)
	selected.preparation_stage = "before_tree"
	return construct("res://assets/vfx/sources/a03f31e8956b1435f6a6/compact_flame.gd", selected)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	root.name = "PalmSource"
	asset.name = "Flame"
	if settings.kind == "produce":
		# The held palm explicitly excludes these source layers. The production
		# path-trail template makes recognised ribbons visible, so keep this
		# unused node as an inert ordinary emitter, not a live path ribbon.
		asset.get_node("GPUTrail3D").set_script(null)
		for path in ["GPUTrail3D", "smallparticles_constant8"]:
			var emitter: GPUParticles3D = asset.get_node(path)
			emitter.emitting = false
			emitter.speed_scale = 0.0
