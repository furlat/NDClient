extends "res://assets/vfx/sources/732c0fdb5f3590e9c5df/approved_aoe_whole.gd"
## Retain all three approved flame meshes and their source particles. Allow
## their velocity cone more vertical spread instead of a nearly flat fan.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/6a0e630617b8d7cbec14/flame_cone_volume.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	var changed := 0
	for particles in node.find_children("*", "GPUParticles3D", true, false):
		if not str(particles.name).begins_with("fire"):
			continue
		particles.process_material.flatness = float(parameters.flame_flatness)
		changed += 1
	assert(changed == 3, "Approved flame component set changed")
