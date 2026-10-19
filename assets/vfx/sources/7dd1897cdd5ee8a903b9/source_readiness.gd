extends RefCounted
## Selective asynchronous immutable-resource preparation. Never builds an effect,
## calls sample(), publishes a node, owns a clock, or caches occurrence inputs.
static var resources: Dictionary = {}
static var requests: Dictionary = {}


static func begin(clip: Dictionary) -> Dictionary:
	var pending: Array = []
	for component in clip.components:
		pending.append({"path": component.script, "script": true,
			"input": component.input.duplicate(true), "requested": false})
	return {"pending": pending, "at": 0, "complete": pending.is_empty(), "error": "",
		"steps": [], "requested_paths": [], "scope": "immutable resources only; no occurrence prototype"}


static func step(job: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	if job.complete or not job.error.is_empty():
		return {"state": "ready" if job.complete else "error", "us": 0}
	var entry: Dictionary = job.pending[job.at]
	var path: String = entry.path
	var operation := "publish_resource"
	if not resources.has(path):
		if not entry.requested:
			if requests.has(path):
				entry.requested = true
				operation = "join_resource_request"
			else:
				var error := ResourceLoader.load_threaded_request(path)
				if error != OK:
					job.error = "Immutable preparation request failed: " + path
				else:
					entry.requested = true
					requests[path] = true
				operation = "request_resource"
		else:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return {"state": "waiting", "us": Time.get_ticks_usec() - started}
			if status != ResourceLoader.THREAD_LOAD_LOADED:
				job.error = "Immutable preparation load failed: " + path
				requests.erase(path)
			else:
				resources[path] = ResourceLoader.load_threaded_get(path)
				requests.erase(path)
	if job.error.is_empty() and resources.has(path):
		var value: Resource = resources[path]
		if entry.script and value.has_method("preparation_resources"):
			var paths: Array = value.preparation_resources(entry.input)
			for required in paths:
				assert(required is String and required.begins_with("res://"), "Preparation exposes native resource paths only")
				if required not in job.requested_paths:
					job.requested_paths.append(required)
					job.pending.append({"path": required, "script": false, "requested": false})
		# Transient discovery inputs are not part of any shared prepared asset.
		entry.erase("input")
		job.at += 1
		job.complete = job.at == job.pending.size()
	var result := {"path": path, "operation": operation, "us": Time.get_ticks_usec() - started,
		"state": "error" if not job.error.is_empty() else "ready" if job.complete else "pending"}
	job.steps.append(result)
	return result
