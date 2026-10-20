extends "res://assets/vfx/sources/9741d79e4578df647fec/intervention.gd"
## Original distinct Intervention paths and actual supplied outcomes.
const GpuPaths = preload("res://assets/vfx/sources/a14e24228442da522a55/support_paths.gd")
const Prepared = preload("res://assets/vfx/sources/024e3436e16596609d0f/prepared_receiving.gd")
var gpu_paths: RefCounted

static func preparation_resources(input: Dictionary) -> Array:
	return Prepared.resources(input)

static func make_component(input: Dictionary) -> Node3D:
	if input.has("prepared_receiving"):
		var prepared: Node3D = Prepared.make("res://assets/vfx/sources/0d1b2fcaa1a9a00de8d7/divine_intervention.gd", input, 5)
		return prepared
	var component: Node3D = create("res://assets/vfx/sources/0d1b2fcaa1a9a00de8d7/divine_intervention.gd", input)
	component.gpu_paths = GpuPaths.new(component, 5)
	return component

func _rebuild() -> void:
	if gpu_paths != null:
		gpu_paths.rebuild()

func source_bindings() -> Dictionary:
	return {"geometry": Array(pieces), "materials": [material], "static_material_topology": true}
