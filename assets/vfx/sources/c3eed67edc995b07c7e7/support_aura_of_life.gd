extends "res://assets/vfx/sources/579fe4609d2e4f7aab1b/aura_of_life.gd"
## Original material, owner/event admission and paths; GPU execution derivative.
const GpuPaths = preload("res://assets/vfx/sources/a14e24228442da522a55/support_paths.gd")
var gpu_paths: RefCounted

static func make_component(input: Dictionary) -> Node3D:
	var component: Node3D = construct("res://assets/vfx/sources/c3eed67edc995b07c7e7/support_aura_of_life.gd", input)
	component.gpu_paths = GpuPaths.new(component, 0)
	return component

func _rebuild() -> void:
	if gpu_paths != null:
		gpu_paths.rebuild()

func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.gpu_body_uploads = gpu_paths.uploads
	return result
