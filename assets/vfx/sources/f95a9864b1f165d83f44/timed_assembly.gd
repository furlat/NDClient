extends Node3D
## Explicit component/time/transform assembly, shared by areas and lifecycles.
## No actor selection, stage, camera, export or gameplay lifetime ownership.
const Composition = preload("res://assets/vfx/sources/628b95849d2163ba8eca/contract_composition.gd")
const SourceSpace = preload("res://assets/vfx/sources/6487dfcacdbd7bcc9361/native_source_space.gd")
const ResourceGraph = preload("res://assets/vfx/sources/1d02b6d800655ef86df2/resource_graph.gd")
const NativeOpacity = preload("res://assets/vfx/sources/39f30ee3f172ac269cd6/native_opacity.gd")

var selections: Array = []
var entries: Array = []
var prepared: bool = false
var live_endpoints: Array = []
var opacity_control: bool = false

func set_live_endpoints(value: Array) -> void:
	live_endpoints = value

static func make_component(input: Dictionary) -> Node3D:
	var node := VfxPackageIO_f95a9864b1.resource("res://assets/vfx/sources/f95a9864b1f165d83f44/timed_assembly.gd").new() as Node3D
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node

func _prepare() -> void:
	prepared = true
	for selected in selections:
		var root := Node3D.new()
		root.name = str(selected.id)
		var position_value: Array = selected.get("position", [0,0,0])
		root.position = Vector3(position_value[0], position_value[1], position_value[2])
		root.scale = Vector3.ONE * float(selected.get("scale", 1.0))
		var rotation_value: Array = selected.get("rotation_degrees", [0,0,0])
		root.rotation_degrees = Vector3(rotation_value[0],rotation_value[1],rotation_value[2])
		add_child(root)
		var composition := Composition.new()
		ResourceGraph.native_sampler_scopes += 1
		var error := composition.make(root, selected.composition)
		composition.sample(0.0)
		ResourceGraph.native_sampler_scopes -= 1
		if not error.is_empty():
			set_meta("native_construction_error",error)
			push_error(error)
		if opacity_control:
			NativeOpacity.apply(root)
		var materials := SourceSpace.adapt(root, {}, [])
		entries.append({"root":root,"composition":composition,"definition":selected,"source_materials":materials,
			"origin":root.position,"rotation":root.rotation})

func sample(seconds: float) -> void:
	if not prepared:
		_prepare()
	for entry in entries:
		var selected: Dictionary = entry.definition
		var age := seconds - float(selected.get("begin", 0.0))
		var duration: float = selected.get("seconds", 2.0)
		entry.root.visible = age >= 0.0 and age < duration
		if not entry.root.visible:
			continue
		if selected.has("endpoint_index"):
			var index: int = selected.endpoint_index
			if index >= 0 and index < live_endpoints.size():
				entry.root.position = to_local(live_endpoints[index].point) + entry.origin
		if selected.has("orbit"):
			var orbit: Dictionary = selected.orbit
			var angle := float(orbit.phase) + seconds * float(orbit.speed)
			entry.root.position = entry.origin + Vector3(cos(angle) * float(orbit.radius),0,sin(angle) * float(orbit.radius))
			entry.root.rotation.y = -angle + PI
		ResourceGraph.native_sampler_scopes += 1
		for component in entry.composition.components.values():
			if component.has_method("set_live_endpoints"):
				component.set_live_endpoints(live_endpoints)
		entry.composition.sample(age * float(selected.get("rate", 1.0)))
		ResourceGraph.native_sampler_scopes -= 1
		if not entry.has("last_transform") or entry.last_transform!=entry.root.global_transform:
			entry.last_transform=entry.root.global_transform
			for material in entry.source_materials:
				material.set_shader_parameter("factory_world_to_source", entry.root.global_transform.affine_inverse())

const VfxPackageIO_f95a9864b1 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
