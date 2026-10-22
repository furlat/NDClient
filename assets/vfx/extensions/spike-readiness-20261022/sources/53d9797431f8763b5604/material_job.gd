extends Resource
## One immutable native Material RID. No property reflection, source metadata,
## Shader query, Node, owner clock or private material is created on this job.
const CLAIM := "factory_spike_standard_material_rid_worker"
var material: StandardMaterial3D
var thread: Thread
var result: Dictionary = {}
var error := ""
var complete := false


static func _native_material_rid(value: StandardMaterial3D) -> Dictionary:
	var began := Time.get_ticks_usec()
	var rid := value.get_rid()
	return {"worker_us": Time.get_ticks_usec() - began, "rid_valid": rid.is_valid(),
		"main_thread": Thread.is_main_thread(), "material_id": value.get_instance_id()}


func _release_claim() -> void:
	if material != null and material.has_meta(CLAIM):
		var claim: Variant = material.get_meta(CLAIM)
		if claim is WeakRef and (claim.get_ref() == null or claim.get_ref() == self):
			material.remove_meta(CLAIM)


func prepare_step(value: StandardMaterial3D) -> Dictionary:
	if complete or not error.is_empty():
		return {"complete": complete, "error": error, "operation": "complete_or_failed"}
	if value == null:
		error = "Only an unscripted exact immutable StandardMaterial with no next pass is admitted"
		return {"complete": false, "error": error}
	if material != null and material != value:
		error = "Actual native Material identity changed during publication"
		return {"complete": false, "error": error}
	if thread == null:
		if value.has_meta(CLAIM):
			var claim: Variant = value.get_meta(CLAIM)
			if not claim is WeakRef:
				error = "Unknown actual Material claim cannot be replaced"
				return {"complete": false, "error": error}
			if claim.get_ref() != null and claim.get_ref() != self:
				return {"complete": false, "operation": "waiting_shared_material"}
		# These immutable source checks occur before starting the real worker,
		# never as property probes while that worker is alive.
		if value.get_class() != "StandardMaterial3D" or value.get_script() != null or value.next_pass != null:
			error = "Only an unscripted exact immutable StandardMaterial with no next pass is admitted"
			return {"complete": false, "error": error}
		material = value
		material.set_meta(CLAIM, weakref(self))
		thread = Thread.new()
		# Only the Script and immutable actual Material are captured. The
		# owning bank/job can be cancelled without a worker owning that bank.
		var started := thread.start(Callable(get_script(), "_native_material_rid").bind(value))
		if started != OK:
			thread = null
			error = "Native Material RID worker could not start: " + str(started)
			_release_claim()
			return {"complete": false, "error": error}
		return {"complete": false, "operation": "request_native_material_rid"}
	if thread.is_alive():
		return {"complete": false, "operation": "waiting_native_material_rid"}
	result = thread.wait_to_finish()
	thread = null
	if not result.get("rid_valid", false) or result.get("main_thread", true) \
		or int(result.get("material_id", 0)) != material.get_instance_id():
		error = "Actual native Material RID did not complete on its admitted worker"
		_release_claim()
		return {"complete": false, "error": error}
	_release_claim()
	complete = true
	return {"complete": true, "operation": "publish_native_material_rid", "native_job": result.duplicate(true)}


func drain_step() -> Dictionary:
	var drained: Dictionary = {}
	if thread != null:
		if thread.is_alive():
			return {"complete": false, "operation": "drain_current_native_material"}
		result = thread.wait_to_finish()
		thread = null
		drained = result.duplicate(true)
	_release_claim()
	result.clear()
	# A joined cancelled unit is not a successful publication.
	return {"complete": true, "operation": "current_native_material_joined", "drained_native_job": drained}


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	# Same last-resort destructor safety as the audited Shader job. Ordinary
	# admission retains/drains the current job before this destructor runs;
	# normal steps/drains never force sync or wait on a live Thread.
	if thread != null and thread.is_started():
		while thread.is_alive():
			RenderingServer.force_sync()
			OS.delay_usec(50)
		thread.wait_to_finish()
	if material != null and material.has_meta(CLAIM):
		var claim: Variant = material.get_meta(CLAIM)
		if claim is WeakRef and (claim.get_ref() == null or claim.get_ref() == self):
			material.remove_meta(CLAIM)
