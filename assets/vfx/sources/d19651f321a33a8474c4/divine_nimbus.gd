extends "res://assets/vfx/sources/718a4b1998b3c764d9a8/nimbus.gd"
## Original shoulder rays, mechanically admitted lights and live actor support.
const GpuPaths = preload("res://assets/vfx/sources/a14e24228442da522a55/support_paths.gd")
const Prepared = preload("res://assets/vfx/sources/024e3436e16596609d0f/prepared_receiving.gd")
var gpu_paths: RefCounted

static func preparation_resources(input: Dictionary) -> Array:
	return Prepared.resources(input)

static func make_component(input: Dictionary) -> Node3D:
	if input.has("prepared_receiving"):
		var prepared: Node3D = Prepared.make("res://assets/vfx/sources/d19651f321a33a8474c4/divine_nimbus.gd", input, 6)
		prepared.bright_light = prepared._make_light("ActualBrightLight", float(input.light.bright_radius_cells), .28)
		prepared.dim_light = prepared._make_light("ActualDimLight", float(input.light.dim_radius_cells), .10)
		return prepared
	var component: Node3D = create("res://assets/vfx/sources/d19651f321a33a8474c4/divine_nimbus.gd", input)
	component.bright_light = component._make_light("ActualBrightLight", float(input.light.bright_radius_cells), .28)
	component.dim_light = component._make_light("ActualDimLight", float(input.light.dim_radius_cells), .10)
	component.gpu_paths = GpuPaths.new(component, 6)
	return component

func _rebuild() -> void:
	if gpu_paths != null:
		gpu_paths.rebuild()

func source_bindings() -> Dictionary:
	return {"geometry": Array(pieces), "materials": [material], "static_material_topology": true, "lights": [bright_light, dim_light]}
