extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/08355a94de091c0ca029/program.gd"
## Only immutable code preparation differs. Runtime entries, dispatch, private
## image publication, orientation and release are the unchanged typed program.
var prepared_code: Resource
var next_unit := 0
var unit_pending := false


func prepare() -> void:
	if started or closed:
		return
	started = true
	var error := "Prepared frame code was not supplied"
	if prepared_code != null:
		error = prepared_code.validate_data()
	if not error.is_empty():
		mutex.lock()
		state.complete = true
		state.error = error
		mutex.unlock()
		return
	advance_preparation()


func advance_preparation() -> void:
	mutex.lock()
	if not started or closed or unit_pending or state.complete:
		mutex.unlock()
		return
	var unit := next_unit
	unit_pending = true
	mutex.unlock()
	var began := Time.get_ticks_usec()
	var caller_main := Thread.is_main_thread()
	var caller_id := OS.get_thread_caller_id()
	_queue_unit(unit)
	var ended := Time.get_ticks_usec()
	mutex.lock()
	if not state.has("submissions"):
		state.submissions = []
	state.submissions.append({"unit": unit, "begin_us": began, "end_us": ended,
		"main_thread": caller_main, "thread_id": caller_id})
	mutex.unlock()


func _queue_unit(unit: int) -> void:
	RenderingServer.call_on_render_thread(_prepare_unit.bind(unit))


func _prepare_unit(unit: int) -> void:
	var began := Time.get_ticks_usec()
	var callback_main := Thread.is_main_thread()
	var callback_id := OS.get_thread_caller_id()
	var device: RenderingDevice = RenderingServer.get_rendering_device()
	var error := ""
	mutex.lock()
	var cancelled := closed
	mutex.unlock()
	if cancelled:
		error = "Prepared frame program closed before native unit admission"
	elif device == null:
		error = "Prepared frame code requires the actual main RenderingDevice"
	elif unit == 0:
		error = prepared_code.validate_target(prepared_code.current_target(device))
		if error.is_empty():
			shader = device.shader_create_from_bytecode(prepared_code.native_code)
			if not shader.is_valid():
				error = "Exact prepared native frame shader was rejected"
	elif unit == 1 and shader.is_valid():
		pipeline = device.compute_pipeline_create(shader)
		if not pipeline.is_valid():
			error = "Actual prepared frame compute pipeline was rejected"
	else:
		error = "Invalid prepared frame native unit ordering"
	var ended := Time.get_ticks_usec()
	_complete_unit(unit, error, {"unit": unit,
		"operation": "validate_target_and_create_shader" if unit == 0 else "create_compute_pipeline",
		"begin_us": began, "end_us": ended, "us": ended - began,
		"main_thread": callback_main, "thread_id": callback_id,
		"device": device.get_device_name() if device != null else ""})


func _complete_unit(unit: int, error: String, observation: Dictionary) -> void:
	mutex.lock()
	if not state.has("units"):
		state.units = []
	state.units.append(observation)
	state.prepare_us += int(observation.us)
	state.device = observation.get("device", "")
	state.error = error
	state.complete = not error.is_empty() or closed or unit == 1
	state.ready = state.complete and error.is_empty() and not closed
	next_unit = unit + 1
	unit_pending = false
	mutex.unlock()
