extends "res://assets/vfx/extensions/speed-completion-20261021/sources/49093a6c3497cf09b4ae/entry.gd"
## The existing private RD release protocol, with this one dispatch binding.
var uniform_set := RID()
var point_count := 0
var point_capacity := 0
var profile_updates := false
var update_spans: Array[Dictionary] = []


func begin_revision() -> int:
	mutex.lock()
	if closed or not state.error.is_empty():
		mutex.unlock()
		return -1
	var revision: int = int(state.get("requested_revision", 0)) + 1
	state.requested_revision = revision
	state.ready = false
	state.render_thread_us = 0
	mutex.unlock()
	return revision


func current_revision() -> int:
	mutex.lock()
	var result: int = int(state.get("requested_revision", 0))
	mutex.unlock()
	return result


func finish_revision(revision: int, error: String, elapsed: int) -> void:
	mutex.lock()
	if revision == int(state.get("requested_revision", 0)):
		state.ready = true
		state.error = error
		state.render_thread_us = elapsed
		state.completed_revision = revision
	mutex.unlock()


func add_orientation_cpu(revision: int, elapsed: int) -> void:
	mutex.lock()
	if revision == int(state.get("requested_revision", 0)):
		state.render_thread_us += elapsed
	mutex.unlock()
