extends "res://assets/vfx/sources/bcc9990ad324ef767239/dispel_evil_and_good.gd"
## Original material, owner/event admission and paths; GPU execution derivative.
const GpuPaths = preload("res://assets/vfx/sources/a14e24228442da522a55/support_paths.gd")
var gpu_paths: RefCounted

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = construct("res://assets/vfx/sources/204c9407d2b9d37cadd4/support_dispel_evil_and_good.gd", input)
	component.gpu_paths = GpuPaths.new(component, 3)
	return component

func _rebuild() -> void:
	if gpu_paths != null:
		gpu_paths.rebuild()

func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.gpu_body_uploads = gpu_paths.uploads
	return result
