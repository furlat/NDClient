extends "res://assets/vfx/extensions/material-runtime-20261021/sources/43db04e716a3a8dc8454/cloud_preparation.gd"
## Same ordered immutable publication; only lazy native Shader creation runs
## on a worker. No nodes, source time, materials, caches or actor inputs there.
const CLAIM := "factory_shader_interface_worker"
@export var original_bank: Resource:
	set(value):
		original_bank = value
		if value != null:
			# Keep original native Resource identity, not serialized copies of
			# every nested source material/scene. These operands stay immutable.
			for property: Dictionary in value.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE and int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
					set(property.name, value.get(property.name))
var _shader_thread: Thread
var _pending_shader: Shader
var _shader_result: Dictionary = {}
var native_jobs: Array[Dictionary] = []


func _validate_property(property: Dictionary) -> void:
	if str(property.name) != "original_bank" and int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
		# Persist the original bank reference and this derivative Script only.
		# On load its setter restores the exact original exported references.
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE


static func _native_interface(shader: Shader) -> Dictionary:
	var started := Time.get_ticks_usec()
	# Both calls belong here: creating the native shader lazily on the main
	# thread before moving its server query left the expensive work there.
	var shader_rid := shader.get_rid()
	var uniforms := shader.get_shader_uniform_list()
	return {"worker_us": Time.get_ticks_usec() - started,
		"rid_valid": shader_rid.is_valid(), "uniform_count": uniforms.size(),
		"main_thread": Thread.is_main_thread()}


func _release_claim() -> void:
	if _pending_shader != null and _pending_shader.has_meta(CLAIM):
		var previous: Variant = _pending_shader.get_meta(CLAIM).get_ref()
		if previous == null or previous == self:
			_pending_shader.remove_meta(CLAIM)
	_pending_shader = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Resource cancellation/teardown must join its real outstanding work.
		# Normal runtime publication has already joined before marking ready.
		if _shader_thread != null and _shader_thread.is_started():
			while _shader_thread.is_alive():
				RenderingServer.force_sync()
				OS.delay_usec(50)
			_shader_thread.wait_to_finish()
		# A script method cannot be called on a RefCounted already at zero.
		# Release the weak native-resource claim directly during destruction.
		if _pending_shader != null and _pending_shader.has_meta(CLAIM):
			var owner: Variant = _pending_shader.get_meta(CLAIM).get_ref()
			if owner == null or owner == self:
				_pending_shader.remove_meta(CLAIM)


func prepare_immutable_interface() -> void:
	# Explicit synchronous authoring compatibility, never the runtime hook.
	while not immutable_interface_prepared:
		var progress := prepare_immutable_interface_step()
		if not str(progress.get("error", "")).is_empty():
			push_error(progress.error)
			return
		if progress.get("operation") == "waiting_shared_shader":
			# A synchronous authoring call cannot leave the actual claim owner
			# unpolled. Finish that bank's immutable work before continuing here.
			# Runtime readiness never enters this synchronous method.
			var shader: Shader = material_specs[_prepare_material].shader
			var claimant: Resource = shader.get_meta(CLAIM).get_ref()
			if claimant != null:
				claimant.prepare_immutable_interface()
		if _shader_thread != null:
			# Synchronous authoring must service queued native server requests
			# while joining. Runtime polling never calls force_sync or waits.
			while _shader_thread.is_alive():
				RenderingServer.force_sync()
				OS.delay_usec(50)
			_shader_result = _shader_thread.wait_to_finish()
			_shader_thread = null


func prepare_immutable_interface_step() -> Dictionary:
	if not _preparation_error.is_empty() or immutable_interface_prepared:
		return super.prepare_immutable_interface_step()
	if _prepare_node < node_specs.size() or _prepare_material >= material_specs.size():
		return super.prepare_immutable_interface_step()
	if _prepare_material_step != 0:
		return super.prepare_immutable_interface_step()
	var shader: Shader = material_specs[_prepare_material].shader
	if _prepared_shaders.has(shader):
		return super.prepare_immutable_interface_step()
	if _pending_shader == null:
		# Distinct banks can reference the same immutable Shader. Only one may
		# lazily create its native state at a time; the weak claim owns no bank.
		if shader.has_meta(CLAIM) and shader.get_meta(CLAIM).get_ref() != null:
			return {"complete": false, "operation": "waiting_shared_shader"}
		_pending_shader = shader
		shader.set_meta(CLAIM, weakref(self))
		_shader_thread = Thread.new()
		# The Callable owns the Script and Shader, not this bank. Cancellation
		# may therefore destroy the bank on its caller thread and join safely.
		var error := _shader_thread.start(Callable(get_script(), "_native_interface").bind(shader))
		if error != OK:
			_shader_thread = null
			_release_claim()
			_preparation_error = "Native shader worker could not start: " + str(error)
			return {"complete": false, "error": _preparation_error}
		return {"complete": false, "operation": "request_native_shader_interface"}
	if _pending_shader != shader:
		_preparation_error = "Immutable shader order changed during preparation"
		return {"complete": false, "error": _preparation_error}
	if _shader_thread != null:
		if _shader_thread.is_alive():
			return {"complete": false, "operation": "waiting_native_shader_interface"}
		_shader_result = _shader_thread.wait_to_finish()
		_shader_thread = null
	if not _shader_result.get("rid_valid", false) or _shader_result.get("main_thread", true):
		_preparation_error = "Native shader worker did not publish a valid background interface"
		_release_claim()
		return {"complete": false, "error": _preparation_error}
	var result := _shader_result.duplicate()
	native_jobs.append(result)
	_shader_result.clear()
	_prepared_shaders[shader] = true
	_prepare_material_step = 1
	_release_claim()
	return {"complete": false, "operation": "publish_native_shader_interface", "native_job": result}
