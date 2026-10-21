extends "res://assets/vfx/extensions/speed-completion-20261021/sources/4eab3ac08359abaa2e9a/program.gd"
## One actual-pose fit on the main RD. Existing guarded publication/retirement
## protocol; no submit/sync, CPU readback, owner cache or per-frame refitting.
const PatchEntry = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/709931d8cf961a889202/entry.gd")
const Packet = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/9fabdaca118c979b7899/packet.gd")


func prepare() -> void:
	if started or closed:
		return
	started = true
	source = VfxPackageIO_84260a019e.text("res://assets/vfx/extensions/speed-completion-20261021/sources/ac8f6d91eefb9bf87d91/frame.glsl").trim_prefix("#[compute]\n")
	RenderingServer.call_on_render_thread(_prepare_thread)


func create_owner() -> RefCounted:
	if not available():
		return null
	var entry := PatchEntry.new()
	entry.server_rid = entry.texture.get_rid()
	active_entries += 1
	entry.release_requested.connect(_entry_released)
	return entry


func request(packet: Dictionary, _diagnostics: bool = false) -> RefCounted:
	var entry: RefCounted = create_owner()
	if entry == null:
		return null
	if not update(entry, packet):
		entry.close()
		return null
	return entry


func update(entry: RefCounted, packet: Dictionary) -> bool:
	var profiling: bool = entry != null and entry.profile_updates
	var began := Time.get_ticks_usec() if profiling else 0
	if profiling:
		entry.update_spans.clear()
	if not available() or entry == null or entry.is_closed() or not packet.get("valid", false):
		return false
	if int(packet.get("count", 0)) < 8 or packet.points.size() != int(packet.count) * 32 or packet.constants.size() != 80:
		return false
	if profiling:
		entry.update_spans.append({"stage": "native_update_admission", "us": Time.get_ticks_usec() - began})
		began = Time.get_ticks_usec()
	var revision: int = entry.begin_revision()
	if revision < 0:
		return false
	if profiling:
		entry.update_spans.append({"stage": "private_revision_mutex", "us": Time.get_ticks_usec() - began})
		began = Time.get_ticks_usec()
	var retained: Dictionary = packet.duplicate()
	if profiling:
		entry.update_spans.append({"stage": "immutable_packet_dictionary_copy", "us": Time.get_ticks_usec() - began})
		began = Time.get_ticks_usec()
	var command: Callable = _update_thread.bind(entry, retained, revision)
	if profiling:
		entry.update_spans.append({"stage": "private_render_callable_binding", "us": Time.get_ticks_usec() - began})
		began = Time.get_ticks_usec()
	RenderingServer.call_on_render_thread(command)
	if profiling:
		entry.update_spans.append({"stage": "render_thread_queue_submission", "us": Time.get_ticks_usec() - began})
	return true


func _update_thread(entry: RefCounted, packet: Dictionary, revision: int) -> void:
	var began := Time.get_ticks_usec()
	if entry.is_closed():
		return
	if not available():
		_fail(entry, "Patch frame pipeline unavailable at queued admission", began)
		return
	var device: RenderingDevice = RenderingServer.get_rendering_device()
	if int(packet.count) > entry.point_capacity:
		if not _reserve(device, entry, int(packet.count)):
			_fail(entry, "Actual patch frame native allocation failed", began)
			return
	var error := device.buffer_update(entry.resource_rids[1], 0, packet.points.size(), packet.points)
	if error != OK:
		_fail(entry, "Actual patch point buffer update failed: " + str(error), began)
		return
	entry.point_count = int(packet.count)
	_dispatch(device, entry, packet.constants)
	entry.finish_revision(revision, "", Time.get_ticks_usec() - began)


func _reserve(device: RenderingDevice, entry: RefCounted, required: int) -> bool:
	var capacity := maxi(entry.point_capacity, 8)
	while capacity < required:
		capacity *= 2
	var buffer := device.storage_buffer_create(capacity * 32)
	var format := RDTextureFormat.new()
	format.width = capacity
	format.height = 3
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var texture := device.texture_create(format, RDTextureView.new())
	if not buffer.is_valid() or not texture.is_valid():
		if buffer.is_valid():
			device.free_rid(buffer)
		if texture.is_valid():
			device.free_rid(texture)
		return false
	var uniforms: Array[RDUniform] = [_uniform(0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, buffer),
		_uniform(1, RenderingDevice.UNIFORM_TYPE_IMAGE, texture)]
	var binding := device.uniform_set_create(uniforms, shader, 0)
	if not binding.is_valid():
		device.free_rid(buffer)
		device.free_rid(texture)
		return false
	var previous: Array[RID] = entry.resource_rids.duplicate()
	entry.resource_rids.assign([binding, buffer, texture])
	entry.uniform_set = binding
	entry.texture_rid = texture
	entry.point_capacity = capacity
	entry.texture.texture_rd_rid = texture
	for rid: RID in previous:
		if rid.is_valid():
			device.free_rid(rid)
	return true


func orient(entry: RefCounted, constants: PackedByteArray) -> void:
	if not available() or entry == null or entry.is_closed() or constants.size() != 80:
		return
	RenderingServer.call_on_render_thread(_orient_thread.bind(entry, constants, entry.current_revision()))


func _orient_thread(entry: RefCounted, constants: PackedByteArray, revision: int) -> void:
	var began := Time.get_ticks_usec()
	if entry.is_closed():
		return
	if not available() or not entry.status().error.is_empty() or not entry.uniform_set.is_valid():
		entry.complete("Patch frame unavailable at queued orientation", 0)
		return
	_dispatch(RenderingServer.get_rendering_device(), entry, constants)
	entry.add_orientation_cpu(revision, Time.get_ticks_usec() - began)


func _dispatch(device: RenderingDevice, entry: RefCounted, constants: PackedByteArray) -> void:
	var commands := device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(commands, pipeline)
	device.compute_list_bind_uniform_set(commands, entry.uniform_set, 0)
	device.compute_list_set_push_constant(commands, constants, constants.size())
	device.compute_list_dispatch(commands, 1, 1, 1)
	device.compute_list_end()


func _fail(entry: RefCounted, error: String, began: int) -> void:
	entry.complete(error, Time.get_ticks_usec() - began)
	entry.close()

const VfxPackageIO_84260a019e = preload("res://assets/vfx/extensions/speed-completion-20261021/scoped_resource_io.gd")
