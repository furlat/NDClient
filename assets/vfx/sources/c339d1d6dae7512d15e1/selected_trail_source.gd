extends "res://assets/vfx/sources/7360ee11cb120250b00e/selected_projectile.gd"
const RibbonReplacement = preload("res://assets/vfx/sources/021a579c092c496193a5/trail_replacement.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/c339d1d6dae7512d15e1/selected_trail_source.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	RibbonReplacement.apply(node)
