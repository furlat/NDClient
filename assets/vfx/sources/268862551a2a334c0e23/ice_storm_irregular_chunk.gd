extends "res://assets/vfx/sources/c114c68e321f3cb1dcb1/native_ice_chunk.gd"
## Actual donor exterior and the original rigid-body fall/impact remain intact.
## New closed cuts remove the regular block-shaped octant fragments.
const IrregularCells = preload("res://assets/vfx/sources/71bcd368cba17c12b6c9/irregular_ice_cells.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/268862551a2a334c0e23/ice_storm_irregular_chunk.gd", input)


func build_pieces() -> void:
	pieces = IrregularCells.build(original, size, ice, interior,
		628109 + int(settings.variant) * 773, int(parameters.fragment_count))


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for body in bodies:
		body.mass = 2.4 / float(bodies.size())
	var shader := Shader.new()
	shader.code = interior.shader.code.replace("float facet=.34+.66*", "float facet=.56+.44*")
	SourceMaterials.replace_shader(interior, shader)
