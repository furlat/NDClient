extends "res://assets/vfx/extensions/late-20261020/sources/409ac0cf4680d6f5add0/field.gd"
## The same finite recorded source and live root, with direct native handles.
var node_tracks: Array
var material_tracks: Array
var node_samples: Array
var node_kinds: PackedByteArray
var node_blend: PackedByteArray
var node_degenerate: Array

static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.ice_storm_bank)]

static func make_component(input: Dictionary) -> Node3D:
	var retained: Resource = VfxPackageIO_0abf4d3b11.resource(str(input.ice_storm_bank))
	assert(retained.interface_ready and retained.construction_program != null)
	var node: Node3D = VfxPackageIO_0abf4d3b11.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/0abf4d3b11f1f4402673/typed_field.gd").new()
	node.bank = retained
	Profile.begin("ice_storm_typed_source")
	var constructed: Dictionary = retained.construction_program.instantiate(retained.construction_operands)
	node.subject = constructed.root
	node.subject.name = "Recorded"
	node.add_child(node.subject)
	node.materials.assign(constructed.materials)
	var runtime_nodes: Array = constructed.geometry
	for index: int in retained.geometry_indices:
		node.geometry.append(runtime_nodes[index])
	for track: Dictionary in retained.node_tracks:
		node.node_targets.append(runtime_nodes[int(track.node_index)])
	node.node_samples = retained.node_values_by_track
	node.node_kinds = retained.node_kinds
	node.node_blend = retained.node_blend
	node.node_degenerate = retained.node_degenerate_by_track
	node.node_tracks = retained.node_tracks
	node.material_tracks = retained.material_tracks
	node.node_values = retained.initial_node_values.duplicate(false)
	node.material_values = retained.initial_material_values.duplicate(false)
	Profile.end("ice_storm_typed_source")
	return node

func source_bindings() -> Dictionary:
	var result: Dictionary = super.source_bindings()
	result.geometry_paths = bank.prepared_geometry_paths
	return result

func sample(seconds: float) -> void:
	_update_source_transform()
	if seconds == last_age:
		return
	var frame := clampf(seconds * bank.rate, 0.0, float(bank.frames - 1))
	var low := int(frame)
	var high := mini(low + 1, bank.frames - 1)
	var weight := frame - float(low)
	var sequential := low == last_frame or low == last_frame + 1
	var indices: PackedInt32Array
	if last_age == 0.0:
		indices = bank.initial_node_dispatch[low]
	else:
		indices = bank.frame_node_indices[low] if sequential else bank.all_node_indices
	for index: int in indices:
		var samples: Array = node_samples[index]
		var value: Variant = samples[low]
		if node_blend[index] and low != high and weight != 0.0:
			var last: Variant = samples[high]
			if node_kinds[index] == 1:
				if node_degenerate[index][low]:
					value = Transform3D(Basis(value.basis.x.lerp(last.basis.x,weight),value.basis.y.lerp(last.basis.y,weight),
						value.basis.z.lerp(last.basis.z,weight)),value.origin.lerp(last.origin,weight))
				else: value = value.interpolate_with(last,weight)
			else: value = lerp(value,last,weight)
		if value != node_values[index]:
			if node_kinds[index] == 1:
				node_targets[index].transform = value
			elif node_kinds[index] == 2:
				node_targets[index].visible = value
			else:
				node_targets[index].set(node_tracks[index].property, value)
			node_values[index] = value
	if last_age == 0.0:
		indices = bank.initial_material_dispatch[low]
	else:
		indices = bank.frame_material_indices[low] if sequential else bank.all_material_indices
	for index: int in indices:
		var track: Dictionary = material_tracks[index]
		var value: Variant = _value(track, low, high, weight)
		if value != material_values[index]:
			materials[int(track.material)].set_shader_parameter(track.property, value)
			material_values[index] = value
	last_age = seconds
	last_frame = low

const VfxPackageIO_0abf4d3b11 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
