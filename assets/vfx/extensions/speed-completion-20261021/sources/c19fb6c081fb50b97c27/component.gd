extends "res://assets/vfx/extensions/speed-completion-20261021/sources/ed4d797836efe191ff94/patches.gd"
## Same current private native patches and sorted draw transforms. Only the
## pose fit/relative point-image build moves to the private main-RD resolve.
const Preparation = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const Packet = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/9fabdaca118c979b7899/packet.gd")
const GeometryKey = preload("res://assets/vfx/sources/9c05cee00f7d74560348/geometry_key.gd")
const Materials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
var active_entry: RefCounted
var frame_packet: Dictionary = {}
var orientation_constants := PackedByteArray()
var frame_requests := 0
var profile_frame_inputs := false
var frame_input_spans: Array[Dictionary] = []


static func preparation_resources(input: Dictionary) -> Array:
	return [str(input.prepared_patch_frame_bank)]


static func make_component(input: Dictionary) -> Node3D:
	return make_frame_component(VfxPackageIO_c19fb6c081.resource("res://assets/vfx/extensions/speed-completion-20261021/sources/c19fb6c081fb50b97c27/component.gd"), input)


static func make_frame_component(script: Script, input: Dictionary) -> Node3D:
	var path := str(input.get("prepared_patch_frame_bank", ""))
	var retained: Resource = Preparation.resources.get(path)
	if retained == null or not retained.get("interface_ready"):
		return null
	if retained.kernel == null or not retained.kernel.available() or retained.native_bank == null:
		return null
	var original: Resource = retained.native_bank
	if original.scene == null or retained.frame_shaders.size() != original.material_piece_indices.size():
		return null
	var settings_input := input.duplicate(true)
	settings_input.erase("prepared_patch_frame_bank")
	if settings_input != original.source_input:
		return null
	var node: Node3D = script.new()
	node.bank = retained
	node.settings = settings_input
	node.prepared_root = original.scene.instantiate()
	node.add_child(node.prepared_root)
	for selected: NodePath in original.piece_paths:
		node.pieces.append(node.prepared_root.get_node(selected))
	for index: int in original.material_piece_indices.size():
		var material: ShaderMaterial = node.pieces[original.material_piece_indices[index]].material_override
		var previous_shader: Shader = material.shader
		var prepared_keys: Array[String] = []
		for key: String in ["factory_prepared_shader", "factory_opacity_prepared_shader"]:
			if material.has_meta(key) and material.get_meta(key) == previous_shader:
				prepared_keys.append(key)
		Materials.replace_shader(material, retained.frame_shaders[index])
		for key: String in prepared_keys:
			material.set_meta(key, material.shader)
		node.materials.append(material)
	node.active_entry = retained.kernel.program.create_owner()
	if node.active_entry == null:
		node.free()
		return null
	return node


func _entry_valid() -> bool:
	return active_entry != null and not active_entry.is_closed() and active_entry.status().error.is_empty()


func _pack_frame() -> Dictionary:
	return Packet.pack(self)


func _frame_constants(packet: Dictionary, orientation_only: bool = false) -> PackedByteArray:
	return Packet.constants(packet, endpoints, orientation_only)


func _refresh_frame() -> bool:
	var began := Time.get_ticks_usec() if profile_frame_inputs else 0
	if bank == null or bank.kernel == null or not bank.kernel.available():
		return false
	if surface.get("points", []).size() < 8:
		return false
	var key: Array = GeometryKey.from_surface(surface)
	var origin: Vector3 = surface.get("origin", Vector3.ZERO)
	if profile_frame_inputs:
		frame_input_spans.append({"stage": "frame_admission_and_key", "us": Time.get_ticks_usec() - began})
	if key.is_empty() or geometry_key != key or geometry_uploads == 0:
		began = Time.get_ticks_usec() if profile_frame_inputs else 0
		var packet: Dictionary = _pack_frame()
		if profile_frame_inputs:
			frame_input_spans.append({"stage": "actual_packet_pack", "us": Time.get_ticks_usec() - began,
				"points": points.size()})
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
			material.set_shader_parameter("gpu_body_count", points.size())
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


func _rebuild() -> void:
	if envelope <= .0001 or not _refresh_frame():
		for piece: MeshInstance3D in pieces:
			piece.hide()
		return
	var began := Time.get_ticks_usec() if profile_frame_inputs else 0
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("gpu_form_phase", (local_clock + float(settings.get("phase_offset_seconds", 0.))) * float(settings.motion_rate))
	for piece: MeshInstance3D in pieces:
		piece.global_transform = Transform3D(Basis.IDENTITY, centre)
		piece.show()
	if profile_frame_inputs:
		frame_input_spans.append({"stage": "source_phase_and_sorted_draw_writes", "us": Time.get_ticks_usec() - began})


func capture_observation() -> Dictionary:
	var result := super.capture_observation()
	# Principal/radii now live on the GPU. Never report stale CPU getters as an
	# exact observation; the native diagnostic reads the explicit frame output.
	for field: String in ["principal", "long_radius", "cross_radius"]:
		result.control_patches.erase(field)
	result.frame_operand_location = "private main-RD texture row 2"
	result.frame_requests = frame_requests
	result.frame_entry_status = active_entry.status() if active_entry != null else {}
	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and active_entry != null:
		active_entry.close()

const VfxPackageIO_c19fb6c081 = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
