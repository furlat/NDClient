extends Resource
## Offline flattened interfaces to the exact original sample arrays. No new
## keys/interpolation/clock or dropped tracks; source arrays resolve at readiness.
const LightUnits = preload("res://assets/vfx/extensions/followup-20261020/sources/568b297c87464dcefeda/native_light_units.gd")
const Values = preload("res://assets/vfx/extensions/followup-20261020/sources/982094992f0fc8016d1d/values.gd")
@export var initial_node_dispatch: Array = []
@export var initial_material_dispatch: Array = []
@export var node_blend := PackedByteArray()
@export var node_properties := PackedStringArray()
@export var node_setters := PackedByteArray()
@export var node_degenerate: Array = []
@export var material_blend := PackedByteArray()
@export var material_properties := PackedStringArray()
@export var material_indices := PackedInt32Array()
@export var material_degenerate: Array = []
var node_samples: Array = []
var material_samples: Array = []
var source: Resource

static func flags(track: Dictionary, frames: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(frames)
	for index in frames:
		var first: Variant = track.values[index]
		var last: Variant = track.values[mini(index+1,frames-1)]
		# The original only reads both determinants when interpolating an
		# actual Transform3D. The source corpus has no interpolated type change.
		if first is Transform3D and last is Transform3D:
			result[index]=int(is_zero_approx(first.basis.determinant()) or is_zero_approx(last.basis.determinant()))
	return result

static func self_lerp_preserves_value(value: Variant) -> bool:
	# Original equality already suppresses a write for scalar/vector self lerp.
	# Keep nondegenerate Transform self-interpolation conservative: quaternion
	# decomposition can produce a different basis even with equal endpoints.
	match typeof(value):
		TYPE_TRANSFORM3D: return is_zero_approx(value.basis.determinant()) or value.basis==Basis.IDENTITY
		TYPE_FLOAT,TYPE_VECTOR2,TYPE_VECTOR3,TYPE_VECTOR4,TYPE_COLOR: return true
	return false

static func initial_dispatch(tracks: Array, frames: int) -> Array:
	var result:=[]
	for low in frames:
		var active:=PackedInt32Array()
		for index in tracks.size():
			var track: Dictionary=tracks[index]
			var first: Variant=track.values[low]
			var initial: Variant=track.values[0]
			var needed:=Values.different(first,initial)
			if not needed and track.blend and low+1<frames:
				var last: Variant=track.values[low+1]
				needed=Values.different(last,initial) or not self_lerp_preserves_value(first)
			if needed: active.append(index)
		result.append(active)
	return result

static func compile(bank: Resource) -> Resource:
	var table: Resource = VfxPackageIO_7bc39fc721.resource("res://assets/vfx/extensions/heavy-effects-20261020/sources/7bc39fc721d5bdddd58b/sample_table.gd").new()
	for track: Dictionary in bank.node_tracks:
		table.node_blend.append(int(track.blend))
		table.node_properties.append(str(track.property))
		table.node_setters.append(1 if track.property=="transform" else 2 if track.property=="visible" else 0)
		table.node_degenerate.append(flags(track,bank.frames))
	for track: Dictionary in bank.material_tracks:
		table.material_blend.append(int(track.blend))
		table.material_properties.append(str(track.property))
		table.material_indices.append(int(track.material))
		table.material_degenerate.append(flags(track,bank.frames))
	table.initial_node_dispatch=initial_dispatch(bank.node_tracks,bank.frames)
	table.initial_material_dispatch=initial_dispatch(bank.material_tracks,bank.frames)
	return table

func prepare(bank: Resource) -> void:
	if source != null:
		assert(source==bank,"One immutable table belongs to its exact original bank")
		return
	assert(node_blend.size()==bank.node_tracks.size() and material_blend.size()==bank.material_tracks.size())
	for track: Dictionary in bank.node_tracks: node_samples.append(track.values)
	for track: Dictionary in bank.material_tracks: material_samples.append(track.values)
	source = bank

static func at(samples: Array, blend: bool, degenerate: PackedByteArray, low: int, high: int, weight: float) -> Variant:
	var first: Variant = samples[low]
	if not blend or low==high or weight==0.: return first
	var last: Variant = samples[high]
	match typeof(first):
		TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR: return lerp(first,last,weight)
		TYPE_TRANSFORM3D:
			if degenerate[low]:
				return Transform3D(Basis(first.basis.x.lerp(last.basis.x,weight),first.basis.y.lerp(last.basis.y,weight),first.basis.z.lerp(last.basis.z,weight)),first.origin.lerp(last.origin,weight))
			return first.interpolate_with(last,weight)
	return first

func sample(field: Node3D, seconds: float) -> void:
	if (field.sampled and is_equal_approx(seconds,field.last_age)) or (not field.sampled and seconds==0.):
		field.sampled=true
		if field.is_inside_tree(): LightUnits.rescale(field.light_units,absf(field.subject.global_basis.get_scale().x))
		return
	LightUnits.restore(field.light_units)
	var frame := clampf(seconds*field.bank.rate,0.,float(field.bank.frames-1))
	var low := int(frame)
	var high := mini(low+1,field.bank.frames-1)
	var weight := frame-float(low)
	var sequential: bool = low==field.last_frame or low==field.last_frame+1
	var initial: bool=field.last_age==0.
	var indices: PackedInt32Array = initial_node_dispatch[low] if initial else field.bank.frame_node_indices[low] if sequential else field.bank.all_node_indices
	for index: int in indices:
		var value: Variant = at(node_samples[index],bool(node_blend[index]),node_degenerate[index],low,high,weight)
		if Values.different(value,field.node_values[index]):
			if node_setters[index]==1: field.node_targets[index].transform=value
			elif node_setters[index]==2: field.node_targets[index].visible=value
			else: field.node_targets[index].set(node_properties[index],value)
			field.node_values[index]=value
	indices=initial_material_dispatch[low] if initial else field.bank.frame_material_indices[low] if sequential else field.bank.all_material_indices
	for index: int in indices:
		var value: Variant = at(material_samples[index],bool(material_blend[index]),material_degenerate[index],low,high,weight)
		if Values.different(value,field.material_values[index]):
			field.materials[material_indices[index]].set_shader_parameter(material_properties[index],value)
			field.material_values[index]=value
	if field.is_inside_tree(): LightUnits.apply(field.light_units,absf(field.subject.global_basis.get_scale().x))
	field.last_frame=low
	field.last_age=seconds
	field.sampled=true

const VfxPackageIO_7bc39fc721 = preload("res://assets/vfx/extensions/heavy-effects-20261020/scoped_resource_io.gd")
