extends "res://assets/vfx/sources/2bc32a498b43894b5603/conditions.gd"
const GPUGeometry = preload("res://assets/vfx/sources/cdaedeb0c4174f6e02f7/legacy_receiving.gd")
var gpu_prepared := false


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/69b10bcb55d740216b95/legacy_conditions.gd", input)


func prepare_subject() -> void:
	if prepared:
		return
	super.prepare_subject()
	for index in freedom_ribbons.size():
		GPUGeometry.mesh(freedom_ribbons[index], index, 0.0, false, false)
	gpu_prepared = true


func freedom_mesh(index: int, age: float) -> ArrayMesh:
	if not gpu_prepared:
		return super.freedom_mesh(index, age)
	return GPUGeometry.mesh(freedom_ribbons[index], index, age, false, false)
