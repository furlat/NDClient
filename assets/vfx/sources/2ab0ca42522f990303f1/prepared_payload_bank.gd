extends "res://assets/vfx/sources/9625d3b6646b9289c628/immutable_draws.gd"
## Exact authored ward geometry/programs, prepared without event or owner state.
## Only read-only GPU interfaces are warmed; materials remain occurrence-private.
var interface_ready := false

func prepare_immutable_interface() -> void:
	if interface_ready:
		return
	for material in materials:
		material.shader.get_shader_uniform_list()
		material.get_property_list()
		material.get_rid()
	for mesh in meshes:
		mesh.get_rid()
	interface_ready = true
