extends "res://assets/vfx/sources/1f895c9802b6dd19377e/enhancement.gd"
const GPUGeometry = preload("res://assets/vfx/sources/cdaedeb0c4174f6e02f7/legacy_receiving.gd")
var gpu_prepared := false


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/f28676e1ce853a81f025/legacy_enhancement.gd", input)


func prepare_subject() -> void:
	if prepared:
		return
	super.prepare_subject()
	for index in freedom_ribbons.size():
		GPUGeometry.mesh(freedom_ribbons[index], index, 0.0, false, false)
	for index in aspect_strands.size():
		GPUGeometry.mesh(aspect_strands[index], index, 0.0, true, not str(settings.animal).is_empty())
		aspect_strands[index].material_override.set_shader_parameter("gpu_legacy_present", 0.0)
	gpu_prepared = true


func freedom_mesh(index: int, age: float) -> ArrayMesh:
	if not gpu_prepared:
		return super.freedom_mesh(index, age)
	return GPUGeometry.mesh(freedom_ribbons[index], index, age, false, false)


func aspect_mesh(index: int, age: float) -> ArrayMesh:
	return GPUGeometry.mesh(aspect_strands[index], index, age, true, not str(settings.animal).is_empty())
