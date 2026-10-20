extends Node3D
## Indexed exact recorded geometry/material playback. No particle VAT/history.
const Values = preload("res://assets/vfx/extensions/followup-20261020/sources/982094992f0fc8016d1d/values.gd")
const Readiness = preload("res://assets/vfx/extensions/followup-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const LightUnits = preload("res://assets/vfx/extensions/followup-20261020/sources/568b297c87464dcefeda/native_light_units.gd")
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var bank: Resource
var subject: Node3D
var materials: Array[Material] = []
var geometry: Array = []
var lights: Array = []
var decals: Array = []
var nodes: Array = []
var node_targets: Array = []
var node_values: Array = []
var material_values: Array = []
var light_units: Dictionary = {}
var last_frame := 0
var last_age := 0.0
var sampled := false

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.recorded_geometry_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var path := str(input.recorded_geometry_bank)
	assert(Readiness.resources.has(path),"Prepare exact recording resources before constructing an occurrence")
	var prepared: Resource = Readiness.resources[path]
	assert(prepared.interface_ready and prepared.provenance.zero_systems_no_history,
		"Only the inspected no-system/no-history recording cohort is admitted")
	var effect: Node3D = VfxPackageIO_2cd710be32.resource("res://assets/vfx/extensions/followup-20261020/sources/2cd710be3201c544db8f/field.gd").new()
	return restore(effect,prepared)

static func restore(effect: Node3D, prepared: Resource) -> Node3D:
	# A particle specialization must independently admit and restore its actual
	# prepared process state. This helper owns only the shared scene/track data.
	assert(prepared.interface_ready and prepared.provenance.get("fixed_static_no_history",
		prepared.provenance.get("zero_systems_no_history",false)),"Only explicit inspected fixed banks may be restored")
	effect.bank = prepared
	Profile.begin("fixed_recorded_scene")
	effect.subject = prepared.scene.instantiate()
	effect.subject.name = "Recorded"
	effect.add_child(effect.subject)
	Profile.end("fixed_recorded_scene")
	for relative in prepared.runtime_paths:
		effect.nodes.append(effect.subject.get_node(relative))
	effect.materials.resize(prepared.materials.size())
	for site in prepared.material_roots:
		var draw: GeometryInstance3D = effect.nodes[int(site.node_index)]
		effect.materials[int(site.material)] = draw.material_override if site.kind == "override" else draw.get_surface_override_material(int(site.surface))
	for index in prepared.geometry_indices:
		effect.geometry.append(effect.nodes[index])
	for index in prepared.light_indices:
		var light: Light3D = effect.nodes[index]
		effect.lights.append(light)
		if light is OmniLight3D:
			effect.light_units[light.get_instance_id()] = LightUnits.prepare(light)
	for index in prepared.decal_indices:
		effect.decals.append(effect.nodes[index])
	for track in prepared.node_tracks:
		effect.node_targets.append(effect.nodes[int(track.node_index)])
	effect.node_values = prepared.initial_node_values.duplicate(false)
	effect.material_values = prepared.initial_material_values.duplicate(false)
	return effect

func has_verified_stable_paths() -> bool:
	return bool(bank.provenance.stable_source_paths_verified)

func prepare_source_layer_mask(value: int) -> void:
	for draw: GeometryInstance3D in geometry:
		if draw.layers != 0:
			draw.layers = value
	for light: Light3D in lights:
		light.light_cull_mask = value
		light.layers = value
	for decal: Decal in decals:
		# The actual recorded player deliberately uses the ground mask1.
		decal.cull_mask = 1

func source_bindings() -> Dictionary:
	# This component owns recorded light-unit restoration, including its actual
	# recorded root transform. Do not also register a second unit converter.
	return {"geometry":geometry,"materials":materials,"lights":[],"players":[],
		"static_material_topology":true,"static_geometry_layers":true}

func refresh_live_inputs(_seconds: float) -> void:
	LightUnits.rescale(light_units,absf(subject.global_basis.get_scale().x))

func sample(seconds: float) -> void:
	if (sampled and is_equal_approx(seconds,last_age)) or (not sampled and seconds == 0.0):
		sampled = true
		if is_inside_tree():
			LightUnits.rescale(light_units,absf(subject.global_basis.get_scale().x))
		return
	LightUnits.restore(light_units)
	var frame := clampf(seconds*bank.rate,0.0,float(bank.frames-1))
	var low := int(frame)
	var high := mini(low+1,bank.frames-1)
	var weight := frame-float(low)
	var sequential := low == last_frame or low == last_frame+1
	var node_indices: PackedInt32Array = bank.frame_node_indices[low] if sequential else bank.all_node_indices
	for index in node_indices:
		var track: Dictionary = bank.node_tracks[index]
		var value: Variant = Values.at(track,low,high,weight)
		if Values.different(value,node_values[index]):
			node_targets[index].set(track.property,value)
			node_values[index] = value
	var material_indices: PackedInt32Array = bank.frame_material_indices[low] if sequential else bank.all_material_indices
	for index in material_indices:
		var track: Dictionary = bank.material_tracks[index]
		var value: Variant = Values.at(track,low,high,weight)
		if Values.different(value,material_values[index]):
			var material: Material = materials[int(track.material)]
			if material is ShaderMaterial:
				material.set_shader_parameter(track.property,value)
			else:
				material.set(track.property,value)
			material_values[index] = value
	if is_inside_tree():
		LightUnits.apply(light_units,absf(subject.global_basis.get_scale().x))
	last_frame = low
	last_age = seconds
	sampled = true

const VfxPackageIO_2cd710be32 = preload("res://assets/vfx/extensions/followup-20261020/scoped_resource_io.gd")
