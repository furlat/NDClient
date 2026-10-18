extends "res://assets/vfx/sources/048e2881b9068776f055/clocked_source.gd"
const RibbonReplacement = preload("res://assets/vfx/sources/021a579c092c496193a5/trail_replacement.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/bd83b061fe455bfc4612/trail_source.gd", input)


func apply_scene_edits(node: Node) -> void:
	RibbonReplacement.apply(node)
