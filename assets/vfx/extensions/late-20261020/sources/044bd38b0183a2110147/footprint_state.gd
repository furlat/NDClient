extends RefCounted
## One exact supplied topology per actual changed event-cell list. No hash,
## area solver, expansion, mesh bake or membership approximation is involved.
const Footprint = preload("res://assets/vfx/extensions/late-20261020/sources/4d63f507234a77da8092/observed_footprint.gd")
var cells: Array = []
var data: Dictionary = {}
var rebuilds := 0

func apply(materials: Array, supplied: Array) -> void:
	if data.is_empty() or supplied != cells:
		data = Footprint.topology(supplied)
		cells = supplied.duplicate(true)
		rebuilds += 1
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("payload_cells", data.points)
		material.set_shader_parameter("payload_open_edges", data.edges)
		material.set_shader_parameter("payload_cell_count", data.count)
