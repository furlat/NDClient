extends "res://assets/vfx/extensions/followup-20261020/sources/bcc9990ad324ef767239/dispel_evil_and_good.gd"
## Original material, owner/event admission and paths; GPU execution derivative.
const GpuPaths = preload("res://assets/vfx/extensions/followup-20261020/sources/a14e24228442da522a55/support_paths.gd")
const Prepared = preload("res://assets/vfx/extensions/followup-20261020/sources/024e3436e16596609d0f/prepared_receiving.gd")
var gpu_paths: RefCounted

static func preparation_resources(input: Dictionary) -> Array:
	return Prepared.resources(input)

static func make_component(input: Dictionary) -> Node3D:
	if input.has("prepared_receiving"):
		return Prepared.make("res://assets/vfx/extensions/followup-20261020/sources/204c9407d2b9d37cadd4/support_dispel_evil_and_good.gd", input, 3)
	var component: Node3D = construct("res://assets/vfx/extensions/followup-20261020/sources/204c9407d2b9d37cadd4/support_dispel_evil_and_good.gd", input)
	component.gpu_paths = GpuPaths.new(component, 3)
	return component

func _rebuild() -> void:
	if gpu_paths != null:
		gpu_paths.rebuild()

func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.gpu_body_uploads = gpu_paths.uploads
	return result

func source_bindings() -> Dictionary:
	return {"geometry": Array(pieces), "materials": [material], "static_material_topology": true}
