extends RefCounted
## Actorless prepublication pipeline + private requests on the MAIN render device.
## No local RD, submit/sync, CPU image copyback or per-frame support dispatch.
const Entry = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/49093a6c3497cf09b4ae/entry.gd")
const CODE_PATH := "res://assets/vfx/extensions/speed-completion-20261021/sources/cc5097c11c43cc700be9/support.glsl"
var shader := RID()
var pipeline := RID()
var mutex := Mutex.new()
var state := {"ready": false, "complete": false, "error": "", "device": "", "prepare_us": 0}
var source: String
var started := false
var closed := false
var active_entries := 0


func prepare() -> void:
	if started or closed:
		return
	started = true
	source = VfxPackageIO_4eab3ac083.text(CODE_PATH).trim_prefix("#[compute]\n")
	RenderingServer.call_on_render_thread(_prepare_thread)


func status() -> Dictionary:
	mutex.lock()
	var result := state.duplicate()
	result.closed = closed
	if closed:
		result.ready = false
		if result.error.is_empty(): result.error = "Flow compute program is closed"
	mutex.unlock()
	return result


func available() -> bool:
	var current := status()
	return current.ready and current.error.is_empty() and not current.closed and shader.is_valid() and pipeline.is_valid()


func _prepare_thread() -> void:
	var began := Time.get_ticks_usec()
	var device: RenderingDevice = RenderingServer.get_rendering_device()
	var error := ""
	if device == null:
		error = "Flow FP64 compute requires the main RenderingDevice, not Dummy/Compatibility"
	else:
		var code := RDShaderSource.new()
		code.source_compute = source
		var spirv: RDShaderSPIRV = device.shader_compile_spirv_from_source(code)
		error = spirv.compile_error_compute
		if error.is_empty():
			shader = device.shader_create_from_spirv(spirv)
			if shader.is_valid():
				pipeline = device.compute_pipeline_create(shader)
			if not shader.is_valid() or not pipeline.is_valid():
				error = "Actual main-device FP64 pipeline was rejected; no float32 fallback"
	mutex.lock()
	state.complete = true
	state.ready = error.is_empty() and not closed
	state.error = error
	state.device = device.get_device_name() if device != null else ""
	state.prepare_us = Time.get_ticks_usec() - began
	mutex.unlock()


func request(packet: Dictionary, diagnostics: bool = false) -> RefCounted:
	if not available():
		return null
	var entry := Entry.new()
	# Allocate a stable server RID before enqueueing compute. The native
	# Texture2DRD setter replaces its backing view in place on the render
	# thread, before subsequently queued material/draw commands consume it.
	entry.server_rid = entry.texture.get_rid()
	active_entries += 1
	entry.release_requested.connect(_entry_released)
	# Own packed immutable request operands; no actor Node, callback clock or
	# encounter endpoint is captured on the render thread.
	# A separate Dictionary prevents the caller from replacing an operand while
	# queued. Packed arrays retain native copy-on-write storage, without a CPU
	# image or another body-point representation.
	RenderingServer.call_on_render_thread(_request_thread.bind(entry, packet.duplicate(), diagnostics))
	return entry


func _entry_released() -> void:
	active_entries -= 1
	assert(active_entries >= 0)


func _uniform(binding: int, kind: int, rid: RID) -> RDUniform:
	var result := RDUniform.new()
	result.binding = binding
	result.uniform_type = kind
	result.add_id(rid)
	return result


func _request_thread(entry: RefCounted, packet: Dictionary, diagnostics: bool) -> void:
	var began := Time.get_ticks_usec()
	if entry.is_closed():
		entry.complete("Owner released before GPU request admission", Time.get_ticks_usec() - began)
		return
	if not available():
		entry.complete("Flow pipeline unavailable at queued request admission", Time.get_ticks_usec() - began)
		return
	var device: RenderingDevice = RenderingServer.get_rendering_device()
	var buffers: Array[RID] = []
	for data: PackedByteArray in [packet.points, packet.coordinates, packet.queries, packet.clearances]:
		var buffer := device.storage_buffer_create(data.size(), data)
		buffers.append(buffer)
		entry.resource_rids.append(buffer)
	var format := RDTextureFormat.new()
	format.width = 13
	format.height = packet.curves * 2
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	if diagnostics:
		format.usage_bits |= RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	entry.texture_rid = device.texture_create(format, RDTextureView.new())
	entry.resource_rids.append(entry.texture_rid)
	entry.neighbour_rid = device.storage_buffer_create(packet.curves * 13 * 16 if diagnostics else 16)
	entry.diagnostic_rid = device.storage_buffer_create(packet.curves * 13 * 9 * 8 if diagnostics else 8)
	entry.resource_rids.append_array([entry.neighbour_rid, entry.diagnostic_rid])
	var uniforms: Array[RDUniform] = []
	for index in 4:
		uniforms.append(_uniform(index, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, buffers[index]))
	uniforms.append(_uniform(4, RenderingDevice.UNIFORM_TYPE_IMAGE, entry.texture_rid))
	uniforms.append(_uniform(5, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, entry.neighbour_rid))
	uniforms.append(_uniform(6, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, entry.diagnostic_rid))
	var uniform_set := device.uniform_set_create(uniforms, shader, 0)
	entry.resource_rids.push_front(uniform_set)
	var constants := PackedInt32Array([packet.count, packet.curves, 1 if diagnostics else 0, 0]).to_byte_array()
	var origin: Vector3 = packet.origin
	constants.append_array(PackedFloat32Array([origin.x, origin.y, origin.z, 0.]).to_byte_array())
	if diagnostics:
		entry.timestamp_names.assign(["flow_support_%d_begin" % entry.get_instance_id(), "flow_support_%d_end" % entry.get_instance_id()])
		device.capture_timestamp(entry.timestamp_names[0])
	var commands := device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(commands, pipeline)
	device.compute_list_bind_uniform_set(commands, uniform_set, 0)
	device.compute_list_set_push_constant(commands, constants, constants.size())
	device.compute_list_dispatch(commands, 1, packet.curves, 1)
	device.compute_list_end()
	if diagnostics:
		device.capture_timestamp(entry.timestamp_names[1])
	# Texture2DRD uses the same main-device RID. Its native setter runs on the
	# render thread; the following native sampled draw retains the GPU dependency.
	entry.texture.texture_rd_rid = entry.texture_rid
	entry.complete("", Time.get_ticks_usec() - began)


func close() -> bool:
	if closed:
		return true
	# A host must retire its owners first. Do not drop a live program when
	# release builds omit assertions; the caller can close after the drain.
	if active_entries != 0:
		return false
	mutex.lock()
	closed = true
	state.ready = false
	mutex.unlock()
	RenderingServer.call_on_render_thread(release_owned.bind(self))
	return true


static func release_owned(program: RefCounted) -> void:
	var device: RenderingDevice = RenderingServer.get_rendering_device()
	if program.pipeline.is_valid():
		device.free_rid(program.pipeline)
		program.pipeline = RID()
	if program.shader.is_valid():
		device.free_rid(program.shader)
		program.shader = RID()

const VfxPackageIO_4eab3ac083 = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
