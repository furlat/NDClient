extends RefCounted
## Private one-pose GPU output. Main RenderingDevice only; no runtime readback.
signal release_requested
var texture := Texture2DRD.new()
var server_rid := RID()
var mutex := Mutex.new()
var state := {"ready": false, "error": "", "render_thread_us": 0}
var resource_rids: Array[RID] = []
var texture_rid := RID()
var neighbour_rid := RID()
var diagnostic_rid := RID()
var timestamp_names: Array[String] = []
var closed := false


func status() -> Dictionary:
	mutex.lock()
	var result := state.duplicate()
	mutex.unlock()
	return result


func complete(error: String, elapsed: int) -> void:
	mutex.lock()
	state.error = error
	state.render_thread_us = elapsed
	state.ready = true
	mutex.unlock()


func close() -> void:
	mutex.lock()
	if closed:
		mutex.unlock()
		return
	closed = true
	mutex.unlock()
	release_requested.emit()
	# Bind the RefCounted entry itself, keeping it alive until this queued
	# render-thread release sees all allocations from an earlier request.
	RenderingServer.call_on_render_thread(release_owned.bind(self))


func is_closed() -> bool:
	mutex.lock()
	var result := closed
	mutex.unlock()
	return result


static func release_owned(entry: RefCounted) -> void:
	entry.texture.texture_rd_rid = RID()
	var device: RenderingDevice = RenderingServer.get_rendering_device()
	for rid: RID in entry.resource_rids:
		if rid.is_valid():
			device.free_rid(rid)
	entry.resource_rids.clear()
	entry.texture_rid = RID()
	entry.neighbour_rid = RID()
	entry.diagnostic_rid = RID()
