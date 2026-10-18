extends "res://assets/vfx/sources/d092a75e3b0074bcf468/control_status.gd"
## Identical source construction, with named topology established before admission.
const ExcludedLayers = preload("res://assets/vfx/sources/85f84ad1e9ee65bf3908/excluded_layers.gd")


static func make_component(input: Dictionary) -> Node3D:
	var selected := input.duplicate(true)
	selected.preparation_stage = "before_tree"
	return construct("res://assets/vfx/sources/d4482b1575c069f5544f/command.gd", selected)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for child in node.get_children():
		if child is GPUParticles3D and child.layers != 0:
			child.name = "ControlParticles"
		elif child is MeshInstance3D and child.layers != 0:
			if child.material_override is ShaderMaterial and child.material_override.has_meta("command_accent"):
				child.name = "CommandAccent"
			else:
				child.name = "ControlGlyph"
	ExcludedLayers.stop(node, node.find_children("*", "GPUParticles3D", true, false).filter(func(emitter): return emitter.layers == 0))
