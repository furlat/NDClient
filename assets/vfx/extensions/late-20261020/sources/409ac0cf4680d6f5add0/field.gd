extends Node3D
## Finite native geometry/material recording, with live occurrence placement.
## No rigid bodies, donor loading, fracture generation or shader compilation.
const Profile = preload("res://assets/vfx/sources/5e6062cb1efe781a65b7/construction_profile.gd")
var bank: Resource
var subject: Node3D
var materials: Array[ShaderMaterial] = []
var geometry: Array = []
var node_targets: Array = []
var node_values: Array = []
var material_values: Array = []
var last_frame := 0
var last_age := 0.0
var last_transform := Transform3D.IDENTITY
var transform_known := true
var live_endpoints: Array = []

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.ice_storm_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var retained: Resource = VfxPackageIO_409ac0cf46.resource(str(input.ice_storm_bank))
	assert(retained != null and retained.interface_ready, "Complete exact Ice Storm immutable readiness first")
	assert(retained.provenance.get("clip_id") == "assembled/ice_storm_native")
	assert(retained.provenance.get("actual_frame_zero_committed",false) and not retained.runtime_node_paths.is_empty(),
		"Prepare current exact frame-zero state and actual node index bindings")
	assert(retained.provenance.get("only_materials_scene_local",false) and retained.frame_node_indices.size() == retained.frames,
		"Prepare exact material-only scene alias ownership and source frame dispatch")
	var node: Node3D = VfxPackageIO_409ac0cf46.resource("res://assets/vfx/extensions/late-20261020/sources/409ac0cf4680d6f5add0/field.gd").new()
	node.bank = retained
	Profile.begin("ice_storm_recorded_scene")
	node.subject = retained.scene.instantiate()
	node.subject.name = "Recorded"
	node.add_child(node.subject)
	Profile.end("ice_storm_recorded_scene")
	var runtime_nodes := []
	for path in retained.runtime_node_paths:
		runtime_nodes.append(node.subject.get_node(path))
	Profile.begin("ice_storm_private_materials")
	# PackedScene's native local-resource map privately clones only these30
	# ShaderMaterials and preserves their260 aliases. Meshes/textures/programs
	# are explicitly nonlocal; no vertex buffers are duplicated or read back.
	node.materials.resize(retained.materials.size())
	for site in retained.material_roots:
		var index := int(site.material)
		var draw: GeometryInstance3D = runtime_nodes[int(site.node_index)]
		var actual: ShaderMaterial = draw.material_override if site.kind == "override" else draw.get_surface_override_material(int(site.surface))
		assert(actual != null and actual != retained.materials[index], "Actual occurrence material must be private")
		node.materials[index] = actual
	Profile.end("ice_storm_private_materials")
	for index: int in retained.geometry_indices:
		node.geometry.append(runtime_nodes[index])
	for track in retained.node_tracks:
		node.node_targets.append(runtime_nodes[int(track.node_index)])
	node.node_values = retained.initial_node_values.duplicate(false)
	node.material_values = retained.initial_material_values.duplicate(false)
	return node

func prepare_source_layer_mask(value: int) -> void:
	for draw: GeometryInstance3D in geometry:
		if draw.layers != 0:
			draw.layers = value

func has_verified_stable_paths() -> bool:
	return bool(bank.provenance.get("stable_source_paths_verified", false))

func set_live_endpoints(value: Array) -> void:
	# Retain the actual selected source's public receiver. The exact ten-entry
	# admission proof shows that this assembly consumes no target layout.
	live_endpoints = value

func set_root_path(_value: Transform3D) -> void:
	_update_source_transform()

func refresh_live_inputs(_seconds: float) -> void:
	_update_source_transform()

func source_bindings() -> Dictionary:
	return {"geometry":geometry,"materials":materials,"lights":[],"players":[],
		"static_material_topology":true,"static_geometry_layers":true}

func _update_source_transform() -> void:
	if not is_inside_tree():
		return
	var current := global_transform
	if transform_known and current == last_transform:
		return
	var inverse := Projection(current.affine_inverse())
	for index in materials.size():
		if bank.source_matrices[index] is Projection:
			materials[index].set_shader_parameter("factory_world_to_source",bank.source_matrices[index] * inverse)
	last_transform = current
	transform_known = true

static func _value(track: Dictionary, low: int, high: int, weight: float) -> Variant:
	var first: Variant = track.values[low]
	if not track.blend or low == high or weight == 0.0:
		return first
	var last: Variant = track.values[high]
	if first is Transform3D:
		if is_zero_approx(first.basis.determinant()) or is_zero_approx(last.basis.determinant()):
			return Transform3D(Basis(first.basis.x.lerp(last.basis.x,weight),first.basis.y.lerp(last.basis.y,weight),
				first.basis.z.lerp(last.basis.z,weight)),first.origin.lerp(last.origin,weight))
		return first.interpolate_with(last,weight)
	return lerp(first,last,weight)

func sample(seconds: float) -> void:
	_update_source_transform()
	if seconds == last_age:
		return
	var frame := clampf(seconds * bank.rate,0.0,float(bank.frames-1))
	var low := int(frame)
	var high := mini(low+1,bank.frames-1)
	var weight := frame-float(low)
	var sequential := low == last_frame or low == last_frame+1
	var node_indices: PackedInt32Array = bank.frame_node_indices[low] if sequential else bank.all_node_indices
	for index: int in node_indices:
		var track: Dictionary = bank.node_tracks[index]
		var value: Variant = _value(track,low,high,weight)
		if value != node_values[index]:
			node_targets[index].set(track.property,value)
			node_values[index] = value
	var material_indices: PackedInt32Array = bank.frame_material_indices[low] if sequential else bank.all_material_indices
	for index: int in material_indices:
		var track: Dictionary = bank.material_tracks[index]
		var value: Variant = _value(track,low,high,weight)
		if value != material_values[index]:
			materials[int(track.material)].set_shader_parameter(track.property,value)
			material_values[index] = value
	last_age = seconds
	last_frame = low

const VfxPackageIO_409ac0cf46 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
