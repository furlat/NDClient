extends "res://assets/vfx/extensions/speed-completion-20261021/sources/6e801bbcee540821f1cf/component.gd"
## Patches-only optional v2 input. The current Dictionary path stays inherited.
const PackedPacket = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/713a49dfb1d669ead5fe/packet.gd")
var packed_geometry: Resource
var packed_mode := false
var packed_frames := 0


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_patch_frame_bank)]


static func make_component(input: Dictionary) -> Node3D:
	return make_frame_component(VfxPackageIO_27b18cfe19.resource("res://assets/vfx/extensions/speed-completion-20261021/sources/27b18cfe19f2961d1ba5/component.gd"), input)


func set_entity_geometry(value: Dictionary) -> void:
	if packed_mode:
		geometry_key = []
	packed_mode = false
	packed_geometry = null
	super.set_entity_geometry(value)


func set_packed_entity_geometry(value: Variant) -> bool:
	var previous_mode := packed_mode
	packed_mode = true
	points = []
	packed_geometry = null
	surface = {}
	if value is Resource and value.get_script() == PackedPacket and value.admitted():
		packed_geometry = value
		surface = value.header
	if not previous_mode or packed_geometry == null:
		geometry_key = []
	_rebuild()
	return packed_geometry != null


func _pack_frame() -> Dictionary:
	if not packed_mode:
		return super._pack_frame()
	if packed_geometry == null:
		return {"valid": false}
	var packet: Dictionary = packed_geometry.frame()
	typed_frame = bool(packet.get("typed", false))
	if typed_frame:
		packed_frames += 1
		centre = packet.centre
		normal = packet.normal
	return packet


func _refresh_frame() -> bool:
	if not packed_mode:
		return super._refresh_frame()
	var began := Time.get_ticks_usec() if profile_frame_inputs else 0
	if bank == null or bank.kernel == null or not bank.kernel.available():
		return false
	if packed_geometry == null or not packed_geometry.admitted():
		return false
	var key: Array = GeometryKey.from_surface(packed_geometry.header)
	var origin: Vector3 = packed_geometry.header.origin
	if profile_frame_inputs:
		frame_input_spans.append({"stage": "frame_admission_and_key", "us": Time.get_ticks_usec() - began})
	if key.is_empty() or geometry_key != key or geometry_uploads == 0:
		began = Time.get_ticks_usec() if profile_frame_inputs else 0
		var packet: Dictionary = _pack_frame()
		if profile_frame_inputs:
			frame_input_spans.append({"stage": "actual_packet_pack", "us": Time.get_ticks_usec() - began,
				"points": packed_geometry.point_count()})
		if not packet.valid:
			return false
		began = Time.get_ticks_usec() if profile_frame_inputs else 0
		var constants: PackedByteArray = _frame_constants(packet)
		packet.constants = constants
		if profile_frame_inputs:
			frame_input_spans.append({"stage": "actual_push_constants", "us": Time.get_ticks_usec() - began})
		began = Time.get_ticks_usec() if profile_frame_inputs else 0
		if not bank.kernel.program.update(active_entry, packet):
			return false
		if profile_frame_inputs:
			frame_input_spans.append({"stage": "private_update_enqueue", "us": Time.get_ticks_usec() - began})
		began = Time.get_ticks_usec() if profile_frame_inputs else 0
		geometry_key = key.duplicate(true)
		relative_centre = centre - origin
		# Only constant-sized immutable values remain after the queued request.
		# The actual point buffer belongs to that private request until release.
		frame_packet = {"count": packet.count, "centre": packet.centre,
			"normal": packet.normal, "axis": packet.axis}
		orientation_constants = constants
		frame_requests += 1
		geometry_uploads += 1
		for material: ShaderMaterial in materials:
			material.set_shader_parameter("gpu_body_points", active_entry.texture)
			material.set_shader_parameter("gpu_body_count", packet.count)
		if profile_frame_inputs:
			frame_input_spans.append({"stage": "private_packet_state_and_uniforms", "us": Time.get_ticks_usec() - began})
	else:
		began = Time.get_ticks_usec() if profile_frame_inputs else 0
		centre = origin + relative_centre
		var constants: PackedByteArray = _frame_constants(frame_packet, true)
		# Header count/mode differ between full and orientation commands. Compare
		# only actual endpoint availability and bearing, preserving held ties.
		if constants.slice(8, 16) != orientation_constants.slice(8, 16) or constants.slice(64) != orientation_constants.slice(64):
			bank.kernel.program.orient(active_entry, constants)
			orientation_constants = constants
		if profile_frame_inputs:
			frame_input_spans.append({"stage": "held_frame_orientation", "us": Time.get_ticks_usec() - began})
	began = Time.get_ticks_usec() if profile_frame_inputs else 0
	var valid := _entry_valid()
	if profile_frame_inputs:
		frame_input_spans.append({"stage": "private_output_status", "us": Time.get_ticks_usec() - began})
	return valid


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	result.optical_transport = PackedPacket.VERSION if packed_mode else "legacy_dictionary"
	if packed_mode:
		result.control_patches.points = packed_geometry.point_count() if packed_geometry != null else 0
	return result

const VfxPackageIO_27b18cfe19 = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
