extends Resource
## The exact existing six-petal GPU program, without encounter-owned operands.
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
@export var program: Resource
@export var art_settings: Dictionary = {}
var interface_prepared := false


func prepare_immutable_interface() -> void:
	if interface_prepared:
		return
	assert(program != null and program.family == 0 and program.active_piece_count == 6)
	assert(program.meshes.size() == 6 and program.material is ShaderMaterial)
	program.material.get_rid()
	Materials.declared_uniforms(program.material.shader)
	for mesh: Mesh in program.meshes:
		mesh.get_rid()
	interface_prepared = true
