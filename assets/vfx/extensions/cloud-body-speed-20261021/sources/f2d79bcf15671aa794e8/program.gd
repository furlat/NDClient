extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/4fe42bfa77a875f8e76c/program.gd"
## Only the two immutable creation calls run on an actual current-unit Thread.
## Entry allocation, uploads, dispatch and release retain the original route.
var unit_thread: Thread
var pending_publication: Dictionary = {}


static func _native_unit(device: RenderingDevice, code: Resource, unit: int,
		current_shader: RID) -> Dictionary:
	var began := Time.get_ticks_usec()
	var created := RID()
	var error := ""
	if device == null:
		error = "Prepared frame code requires the actual main RenderingDevice"
	elif unit == 0:
		error = code.validate_target(code.current_target(device))
		if error.is_empty():
			created = device.shader_create_from_bytecode(code.native_code)
			if not created.is_valid():
				error = "Exact prepared native frame shader was rejected"
	elif unit == 1 and current_shader.is_valid():
		created = device.compute_pipeline_create(current_shader)
		if not created.is_valid():
			error = "Actual prepared frame compute pipeline was rejected"
	else:
		error = "Invalid prepared frame native unit ordering"
	var ended := Time.get_ticks_usec()
	return {"unit": unit, "created": created, "error": error,
		"observation": {"unit": unit,
			"operation": "validate_target_and_create_shader" if unit == 0 else "create_compute_pipeline",
			"begin_us": began, "end_us": ended, "us": ended - began,
			"main_thread": Thread.is_main_thread(), "thread_id": OS.get_thread_caller_id(),
			"device_id": device.get_instance_id() if device != null else 0,
			"device": device.get_device_name() if device != null else ""}}


func _native_callable(unit: int) -> Callable:
	# Capture only actual immutable operands. The existing Admission retains the
	# Bank/Kernel/Program and engine lifetime until this current unit drains.
	return Callable(get_script(), "_native_unit").bind(
		RenderingServer.get_rendering_device(), prepared_code, unit, shader)


func _start_unit(unit: int) -> Error:
	unit_thread = Thread.new()
	var error := unit_thread.start(_native_callable(unit))
	if error != OK:
		unit_thread = null
	return error


func _queue_unit(unit: int) -> void:
	var error := _start_unit(unit)
	if error != OK:
		_complete_unit(unit, "Native frame unit worker could not start: " + str(error),
			{"unit": unit, "us": 0, "main_thread": true,
				"operation": "worker_start_failed", "device": ""})


func _collect_finished() -> bool:
	if unit_thread == null:
		return true
	if unit_thread.is_alive():
		return false
	# A completed-but-unjoined Thread still owns its result. Collect it before
	# either source publication or the original render-thread release callback.
	pending_publication = unit_thread.wait_to_finish()
	unit_thread = null
	if int(pending_publication.unit) == 0:
		shader = pending_publication.created
	else:
		pipeline = pending_publication.created
	return true


func advance_preparation() -> void:
	if closed:
		return
	if unit_thread != null:
		_collect_finished()
		return
	if not pending_publication.is_empty():
		var result := pending_publication
		pending_publication = {}
		# Publication is a main preparation operation, never a worker result or
		# cancellation side effect. A later step alone can start the next unit.
		_complete_unit(int(result.unit), str(result.error), result.observation)
		return
	super.advance_preparation()


func drain_current() -> Dictionary:
	if not _collect_finished():
		return {"complete": false, "operation": "drain_current_native_unit"}
	return {"complete": true, "operation": "current_native_unit_joined_unpublished",
		"pending_publication": not pending_publication.is_empty()}


func status() -> Dictionary:
	var result := super.status()
	result.worker_pending = unit_thread != null
	result.worker_alive = unit_thread != null and unit_thread.is_alive()
	result.joined_unit_pending_publication = not pending_publication.is_empty()
	return result


func close() -> bool:
	if active_entries != 0 or not _collect_finished():
		return false
	# Actual returned handles are now owned by the original Program fields.
	# No worker can still read the Shader or return an uncollected pipeline.
	if not super.close():
		return false
	pending_publication.clear()
	unit_pending = false
	return true
