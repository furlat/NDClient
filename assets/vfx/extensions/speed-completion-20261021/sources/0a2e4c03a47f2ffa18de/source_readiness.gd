extends "res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd"
## Same actual shared resource/request dictionaries and normal begin/step.
## Cancellation only collects the currently admitted load or resource worker.
const OriginalCloudPreparation = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/43db04e716a3a8dc8454/cloud_preparation.gd")
const WorkerCloudPreparation = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/75b200daec4a20076a81/cloud_bank.gd")


static func begin(clip: Dictionary) -> Dictionary:
	return super.begin(clip)


static func step(job: Dictionary) -> Dictionary:
	if job.complete or not job.error.is_empty():
		return super.step(job)
	var entry: Dictionary = job.pending[job.at]
	var path: String = entry.path
	# Intercept only successful loader collection so an unknown progressive
	# hook cannot run before the class boundary below is checked. Delegate all
	# ordinary request/wait/error/discovery/publication to the existing helper.
	if not resources.has(path) and entry.requested:
		var started := Time.get_ticks_usec()
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# The original fallback polls again in this same main frame. Godot
			# treats that as a request to sync RenderingServer. Keep the actual
			# observed waiting state; do not substitute a cached Resource/status.
			return {"path": path, "state": "waiting", "us": Time.get_ticks_usec() - started}
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			resources[path] = ResourceLoader.load_threaded_get(path)
			requests.erase(path)
			var collected := {"path": path, "operation": "collect_before_cloud_hook_admission",
				"state": "pending", "us": Time.get_ticks_usec() - started}
			job.steps.append(collected)
			return collected
		# Preserve the canonical FAILED/INVALID error and request cleanup.
		# Admission retains the actual errored job for existing drain/fence.
		job.error = "Immutable preparation load failed: " + path
		requests.erase(path)
		var failed := {"path": path, "operation": "publish_resource",
			"state": "error", "us": Time.get_ticks_usec() - started}
		job.steps.append(failed)
		return failed
	if resources.has(path):
		var value: Resource = resources[path]
		var progressive := value.has_method("prepare_immutable_interface_step") or value.has_method("prepare_immutable_interface")
		if progressive and not value is WorkerCloudPreparation and value.get_script() != OriginalCloudPreparation:
			entry.bridge_hook_rejected = true
			job.error = "Cloud worker readiness does not admit this preparation hook: " + path
			return {"state": "error", "us": 0, "path": path}
	return super.step(job)


static func drain(job: Dictionary) -> Dictionary:
	if job.at >= job.pending.size():
		return {"complete": true, "operation": "no_current_resource"}
	var entry: Dictionary = job.pending[job.at]
	var path: String = entry.path
	if entry.get("bridge_hook_rejected", false):
		return {"complete": true, "operation": "unstarted_unrelated_hook_rejected"}
	if not resources.has(path) and requests.has(path):
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return {"complete": false, "operation": "drain_current_load"}
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			resources[path] = ResourceLoader.load_threaded_get(path)
		requests.erase(path)
	if resources.has(path):
		var value: Resource = resources[path]
		if value is WorkerCloudPreparation:
			return value.drain_immutable_interface_step()
		if value.get_script() == OriginalCloudPreparation:
			# This exact original class performs only synchronous resource units.
			# A clip-scoped opt-in may still select its unchanged original approach.
			return {"complete": true, "operation": "exact_original_cloud_unit_finished"}
		if value.has_method("prepare_immutable_interface_step") or value.has_method("prepare_immutable_interface"):
			# This prototype cannot infer another progressive resource's thread
			# lifetime. Keep admission owned instead of declaring an unsafe drain.
			return {"complete": false, "error": "Current progressive resource has no explicit drain hook", "path": path}
	return {"complete": true, "operation": "current_resource_collected"}
