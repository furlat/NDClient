extends RefCounted
## Opt-in construction diagnostics only. No occurrence facts or runtime manager.
static var current: RefCounted
var stack: Array[Dictionary] = []
var stages: Dictionary = {}


static func begin(name: String) -> void:
	if current != null:
		current.stack.append({"name": name, "begin": Time.get_ticks_usec(), "children": 0})


static func end(name: String) -> void:
	if current == null:
		return
	var entry: Dictionary = current.stack.pop_back()
	assert(entry.name == name, "Unbalanced construction timing: " + name)
	var duration: int = Time.get_ticks_usec() - int(entry.begin)
	if not current.stack.is_empty():
		current.stack.back().children += duration
	if not current.stages.has(name):
		current.stages[name] = {"calls": 0, "inclusive_us": 0, "exclusive_us": 0}
	var row: Dictionary = current.stages[name]
	row.calls += 1
	row.inclusive_us += duration
	row.exclusive_us += duration - int(entry.children)


func report() -> Dictionary:
	assert(stack.is_empty(), "Construction profiling did not finish")
	return stages.duplicate(true)
