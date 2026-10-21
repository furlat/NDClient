extends RefCounted
## Selective asynchronous immutable-resource preparation. Never builds an effect,
## calls sample(), publishes a node, owns a clock, or caches occurrence inputs.
const Bindings = preload("res://assets/vfx/sources/dabf568b4506db4883ad/occurrence_bindings.gd")
static var resources: Dictionary = {}
static var requests: Dictionary = {}


static func begin(clip: Dictionary) -> Dictionary:
	var pending: Array = []
	for component in clip.components:
		pending.append({"path": component.script, "script": true,
			"input": component.input.duplicate(true), "requested": false})
		for record in component.input.get("_prepared_materials", []):
			pending.append({"path": record.path, "script": false, "requested": false})
	return {"pending": pending, "at": 0, "complete": pending.is_empty(), "error": "",
		"steps": [], "requested_paths": [], "scope": "immutable resources only; no occurrence prototype"}


static func step(job: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	if job.complete or not job.error.is_empty():
		return {"state": "ready" if job.complete else "error", "us": 0}
	var entry: Dictionary = job.pending[job.at]
	var path: String = entry.path
	var operation := "publish_resource"
	var immutable_progress: Dictionary = {}
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
		if entry.script:
			# The source Script's inherited public setter interface is immutable.
			# Resolve it here rather than during the first owner's tree binding.
			Bindings.methods(value)
		elif value is ShaderMaterial:
			# Native materials lazily reflect their uniform property interface on
			# the first private duplicate. This is Resource-only publication work;
			# it does not sample a source or preconstruct an occurrence.
			value.get_property_list()
			value.shader.get_shader_uniform_list()
			operation = "publish_material_and_prepare_immutable_interface"
		if entry.script and value.has_method("preparation_resources"):
			var paths: Array = value.preparation_resources(entry.input)
			for required in paths:
				assert(required is String and required.begins_with("res://"), "Preparation exposes native resource paths only")
				if required not in job.requested_paths:
					job.requested_paths.append(required)
					job.pending.append({"path": required, "script": false, "requested": false})
		# Opt-in immutable interface preparation belongs before publication. A
		# native material may lazily reflect/compile its uniform interface on its
		# first private duplicate. This hook may warm immutable Resource APIs;
		# it must not construct/sample nodes, own clocks or retain occurrence input.
		if value.has_method("prepare_immutable_interface_step"):
			immutable_progress = value.prepare_immutable_interface_step()
			assert(immutable_progress is Dictionary and immutable_progress.has("complete"),
				"Progressive preparation exposes an explicit native Resource completion state")
			var preparation_error := str(immutable_progress.get("error", ""))
			if not preparation_error.is_empty():
				job.error = "Immutable preparation failed: " + path + ": " + preparation_error
				var failed := {"path":path,"operation":"prepare_immutable_resource_unit",
					"us":Time.get_ticks_usec()-started,"state":"error",
					"immutable_progress":immutable_progress}
				job.steps.append(failed)
				return failed
			if not immutable_progress.complete:
				var preparing := {"path":path,"operation":"prepare_immutable_resource_unit",
					"us":Time.get_ticks_usec()-started,"state":"preparing",
					"immutable_progress":immutable_progress}
				job.steps.append(preparing)
				return preparing
			operation = "publish_resource_and_prepare_immutable_interface"
		elif value.has_method("prepare_immutable_interface"):
			value.prepare_immutable_interface()
			operation = "publish_resource_and_prepare_immutable_interface"
		# Transient discovery inputs are not part of any shared prepared asset.
		entry.erase("input")
		job.at += 1
		job.complete = job.at == job.pending.size()
	var result := {"path": path, "operation": operation, "us": Time.get_ticks_usec() - started,
		"state": "error" if not job.error.is_empty() else "ready" if job.complete else "pending"}
	if not immutable_progress.is_empty(): result.immutable_progress = immutable_progress
	job.steps.append(result)
	return result
