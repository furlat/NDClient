extends RefCounted
## Exact native restore/get/set min/max ordering in private typed f32 state.
## Shader/scalar layout is compiled offline; no reflection or temporary scalar
## arrays are needed per advancing root-scale update.
const NativeUnits = preload("res://assets/vfx/sources/07cc721710dacce01ef6/native_particle_units.gd")
const MAPPING := {"tangential_accel_min": "tangent_accel_min", "tangential_accel_max": "tangent_accel_max"}
var material: ShaderMaterial
var specification: Dictionary
var values: PackedFloat32Array
var sources: PackedFloat32Array
var uploaded: PackedByteArray
var peers: PackedInt32Array
var roles: PackedInt32Array
var uniforms: PackedStringArray
var active: PackedInt32Array
var gravity: Vector3
var source_gravity: Vector3
var gravity_active := false
var zero_gravity: Vector3
var applied_scale := 1.0
var current: Dictionary:
	get:
		var result := {"gravity": gravity}
		for index in specification.scalar_fields.size(): result[specification.scalar_fields[index]] = float(values[index])
		return result

static func source_specification(original: ParticleProcessMaterial, captured: ShaderMaterial, local_coordinates: bool) -> Dictionary:
	if local_coordinates: return {}
	var fields: Array = NativeUnits.LENGTH_FIELDS.duplicate()
	if not original.particle_flag_inherit_emitter_scale:
		fields.append_array(["scale_3d_min", "scale_3d_max"] if original.use_scale_3d else ["scale_min", "scale_max"])
	if not original.particle_flag_damping_as_friction: fields.append_array(["damping_min", "damping_max"])
	fields.append_array(["directional_velocity_min", "directional_velocity_max"])
	var initial := {}
	var uniforms := {}
	var scalar_fields := PackedStringArray()
	var scalar_values := PackedFloat32Array()
	for field: String in fields:
		initial[field] = original.get(field)
		if initial[field] is float or initial[field] is int:
			scalar_fields.append(field)
			scalar_values.append(float(initial[field]))
		else:
			assert(field == "gravity" and initial[field] is Vector3, "New native vector ranges require their own explicit typed operand path")
		uniforms[field] = MAPPING.get(field, field)
		assert(captured.get_shader_parameter(uniforms[field]) != null, "Actual native unit field absent")
	var peers := PackedInt32Array()
	var roles := PackedInt32Array()
	var scalar_uniforms := PackedStringArray()
	for field: String in scalar_fields:
		var peer := field.trim_suffix("_min") + "_max" if field.ends_with("_min") else field.trim_suffix("_max") + "_min"
		peers.append(scalar_fields.find(peer))
		roles.append(1 if field.ends_with("_min") else 2)
		scalar_uniforms.append(uniforms[field])
	var active := PackedInt32Array()
	var invariant_zero_ranges := []
	for index in scalar_fields.size():
		var peer: int = peers[index]
		assert(peer >= 0 and peers[peer] == index, "Unknown native range layout cannot use zero-invariant lowering")
		assert(roles[index] != roles[peer] and (roles[index] != 1 or peer == index + 1), "Original min/max setter order changed")
		if scalar_values[index] != 0.0 or scalar_values[peer] != 0.0:
			active.append(index)
		elif roles[index] == 1:
			# Admitted source callbacks never author these native process fields;
			# restoring / positive finite owner scaling / min-max peer clamps all
			# preserve this exact all-zero pair, including existing signed zeros.
			invariant_zero_ranges.append({"minimum": scalar_fields[index], "maximum": scalar_fields[peer],
				"initial_float32_bits": PackedFloat32Array([scalar_values[index], scalar_values[peer]]).to_byte_array().hex_encode(),
				"operator_proof": "Private exact zero pair; no admitted source/player writes; restore, positive finite scale and peer clamps preserve zero bits"})
	return {"fields": fields, "initial": initial, "uniforms": uniforms,
		"scalar_fields": scalar_fields, "scalar_values": scalar_values,
		"scalar_peers": peers, "scalar_roles": roles, "scalar_uniforms": scalar_uniforms,
		"active_scalar_indices": active, "invariant_zero_ranges": invariant_zero_ranges,
		"gravity_active": original.gravity != Vector3.ZERO,
		"zero_gravity": captured.get_shader_parameter("gravity") if original.gravity == Vector3.ZERO else Vector3.ZERO}

func _init(target: ShaderMaterial, source_operands: Dictionary) -> void:
	material = target
	specification = source_operands
	values = specification.scalar_values.duplicate()
	sources = values.duplicate()
	uploaded = values.to_byte_array()
	peers = specification.scalar_peers
	roles = specification.scalar_roles
	uniforms = specification.scalar_uniforms
	active = specification.active_scalar_indices
	gravity = specification.initial.gravity
	source_gravity = gravity
	gravity_active = specification.gravity_active
	zero_gravity = specification.zero_gravity

func _store(index: int, value: float) -> void:
	values[index] = value # Actual typed f32 store, exactly like the native setter.
	var peer: int = peers[index]
	if peer < 0: return
	var role: int = roles[index]
	if (role == 1 and values[index] > values[peer]) or (role == 2 and values[index] < values[peer]):
		values[peer] = values[index]

func advance(scale_value: float) -> void:
	if applied_scale != 1.0:
		for index in active: _store(index, float(sources[index]))
		gravity = source_gravity
		applied_scale = 1.0
	if scale_value != 1.0:
		for index in active:
			var value: float = values[index]
			sources[index] = value
			_store(index, value * scale_value)
		source_gravity = gravity
		gravity *= scale_value
		applied_scale = scale_value
	# Zero/no-change source fields need no redundant renderer setter. Compare
	# actual f32 bits, retaining signed zero as well as all native range effects.
	var bytes := values.to_byte_array()
	for index in active:
		if bytes.decode_u32(index * 4) != uploaded.decode_u32(index * 4):
			material.set_shader_parameter(uniforms[index], float(values[index]))
	uploaded = bytes
	if gravity_active:
		material.set_shader_parameter("gravity", zero_gravity if gravity == Vector3.ZERO else gravity)
