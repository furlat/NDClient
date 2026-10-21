extends Node3D
## Existing code/data compositions in native world space, without capture halves.
const Composition = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/628b95849d2163ba8eca/contract_composition.gd")
const SourceSpace = preload("res://assets/vfx/sources/6487dfcacdbd7bcc9361/native_source_space.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")

var definition: Dictionary = {}
var composition: RefCounted
var prepared: bool = false
var adapted: bool = false
var source_materials: Array = []
var live_endpoints: Array = []
var delivery_timing: Array = []
var last_source_transform: Transform3D
var source_transform_known:=false

func set_delivery_timing(launch: float, travel: float) -> void:
	delivery_timing = [launch, travel]

func set_live_endpoints(value: Array) -> void:
	live_endpoints = value

func capture_observation() -> Dictionary:
	var observations: Dictionary = {}
	if composition != null:
		for id in composition.components:
			var component: Node = composition.components[id]
			if component.has_method("capture_observation"):
				observations[id] = component.capture_observation()
	return {"components": observations}

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_0738ff2d24.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/0738ff2d24aa41b1b963/native_review_composition.gd").new() as Node3D
	node.definition = input.duplicate(true)
	return node

func prepare_source_interfaces() -> Array:
	if definition.get("opacity_control", false):
		NativeOpacity.apply(self)
	return SourceSpace.adapt(self, {}, [])

func sample(seconds: float) -> void:
	if not prepared:
		prepared = true
		composition = Composition.new()
		ResourceGraph.native_sampler_scopes += 1
		var error: String = composition.make(self, definition)
		ResourceGraph.native_sampler_scopes -= 1
		if not error.is_empty():
			set_meta("native_construction_error", error)
			push_error(error)
			return
	ResourceGraph.native_sampler_scopes += 1
	for component in composition.components.values():
		if component.has_method("set_live_endpoints"):
			component.set_live_endpoints(live_endpoints)
		if not delivery_timing.is_empty() and component.has_method("set_delivery_timing"):
			component.set_delivery_timing(delivery_timing[0], delivery_timing[1])
	composition.sample(seconds)
	ResourceGraph.native_sampler_scopes -= 1
	if not adapted:
		source_materials = prepare_source_interfaces()
		for role in definition.get("light_roles", []):
			for light in find_children("*", role["class"], true, false):
				light.set_meta("factory_light_role", role.role)
		adapted = true
	if not source_transform_known or last_source_transform!=global_transform:
		last_source_transform=global_transform
		source_transform_known=true
		for material in source_materials:
			material.set_shader_parameter("factory_world_to_source", Projection(global_transform.affine_inverse()))

const VfxPackageIO_0738ff2d24 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
