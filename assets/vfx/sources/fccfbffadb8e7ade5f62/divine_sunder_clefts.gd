extends "res://assets/vfx/sources/0b4876fb9ba8ecd707ea/sunder_clefts.gd"
## Same owner/event admission, material and five native clefts; GPU support.
const GpuPaths = preload("res://assets/vfx/sources/a14e24228442da522a55/support_paths.gd")
const Prepared = preload("res://assets/vfx/sources/024e3436e16596609d0f/prepared_receiving.gd")
var gpu_paths: RefCounted

static func preparation_resources(input: Dictionary) -> Array:
	return Prepared.resources(input)

static func make_component(input: Dictionary) -> Node3D:
	if input.has("prepared_receiving"):
		var prepared: Node3D = Prepared.make("res://assets/vfx/sources/fccfbffadb8e7ade5f62/divine_sunder_clefts.gd", input, 7)
		return prepared
	var component: Node3D = create("res://assets/vfx/sources/fccfbffadb8e7ade5f62/divine_sunder_clefts.gd", input)
	component.gpu_paths = GpuPaths.new(component, 7)
	return component

func _rebuild() -> void:
	if gpu_paths != null:
		gpu_paths.rebuild()

func source_bindings() -> Dictionary:
	return {"geometry": Array(pieces), "materials": [material], "static_material_topology": true}
