extends Node3D
## Complete source partitions, native GPU puffs/crystals and original flare poses.
## Source parameter atlases and shader programs are immutable; clocks are private.
static var banks: Dictionary = {}
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var source: Node3D
var draw_materials: Array[ShaderMaterial] = []
var process_materials: Array[ShaderMaterial] = []
var geometry: Array = []
var flare_nodes: Array = []
var simulation_hz := 144.0
var tick := 0
var source_transform_known := false
var previous_source_transform: Transform3D

static func preparation_resources(input: Dictionary) -> Array:
	return [input.prepared_cone_bank]

static func make_component(input: Dictionary) -> Node3D:
	var path: String = input.prepared_cone_bank
	if not banks.has(path):
		Profile.begin("cone_immutable_interface_publication")
		banks[path] = VfxPackageIO_f9090a7c6d.resource(path)
		banks[path].prepare_immutable_interface()
		Profile.end("cone_immutable_interface_publication")
	var bank: Resource = banks[path]
	assert(bank != null and bank.scene != null, "Cone particle source bank is not prepared")
	var component: Node3D = VfxPackageIO_f9090a7c6d.resource("res://assets/vfx/sources/f9090a7c6dfd95af5ae7/particle_cone_frost.gd").new()
	Profile.begin("cone_private_scene_instantiation")
	component.source = bank.scene.instantiate()
	Profile.end("cone_private_scene_instantiation")
	component.add_child(component.source)
	component.simulation_hz = bank.simulation_hz
	Profile.begin("cone_direct_source_bindings")
	for node_path in bank.material_paths:
		component.draw_materials.append(component.source.get_node(node_path).material_override)
	for node_path in bank.process_paths:
		component.process_materials.append(component.source.get_node(node_path).process_material)
	for node_path in bank.geometry_paths:
		component.geometry.append(component.source.get_node(node_path))
	for definition in bank.flares:
		component.flare_nodes.append({"node": component.source.get_node(definition.node), "index": definition.index})
	Profile.end("cone_direct_source_bindings")
	return component

func sample(seconds: float) -> void:
	var desired_tick := int(round(seconds * simulation_hz))
	if desired_tick > tick:
		tick = desired_tick
		var age := float(tick) / simulation_hz
		for material in draw_materials:
			material.set_shader_parameter("cold_age", age)
		for material in process_materials:
			material.set_shader_parameter("cone_source_age", age)
		for flare in flare_nodes:
			var index: int = flare.index
			var envelope := smoothstep(0.0, 0.10, age) * (1.0 - smoothstep(0.38, 0.66, age))
			flare.node.scale = Vector3(0.35 * envelope * (1.0 + 0.3 * index),
				1.6 + 0.6 * index, 0.35 * envelope * (1.0 + 0.3 * index))
			flare.node.visible = envelope > 0.01
	if not source_transform_known or previous_source_transform != global_transform:
		previous_source_transform = global_transform
		source_transform_known = true
		var inverse := Projection(global_transform.affine_inverse())
		for material in draw_materials:
			if material.get_meta("factory_world_space_uniform", false):
				material.set_shader_parameter("factory_world_to_source", inverse)

func source_bindings() -> Dictionary:
	return {"geometry": geometry, "materials": Array(draw_materials), "static_material_topology": true}

func capture_observation() -> Dictionary:
	return {"native_tick": tick, "geometry": geometry.size(), "gpu_systems": process_materials.size(),
		"source_draw_materials": draw_materials.size(), "source_partitions": 4,
		"source_particles": 3 * (88 + 108), "source_layer_removed": false,
		"source_clock_hz": simulation_hz, "gpu_geometry_verified": false}

const VfxPackageIO_f9090a7c6d = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
