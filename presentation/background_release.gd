extends RefCounted
## Dropping the last reference to large data (decoded images, a retired view's
## tables) frees megabytes and thousands of Variants; on the main thread it took
## 2-6 ms. These references are dropped on a worker instead. They must not be
## the only owners of Nodes (Nodes are freed explicitly, never by refcount).
static var _tasks: Array[int] = []

static func release(values: Array) -> void:
    for i in range(_tasks.size() - 1, -1, -1):
        if WorkerThreadPool.is_task_completed(_tasks[i]):
            WorkerThreadPool.wait_for_task_completion(_tasks[i]); _tasks.remove_at(i)
    if values.is_empty(): return
    _tasks.append(WorkerThreadPool.add_task(func(): values.clear(), false, "Release retired data"))

## Waits for every pending release; the owner calls it before it exits.
static func join() -> void:
    for task in _tasks: WorkerThreadPool.wait_for_task_completion(task)
    _tasks.clear()

## Takes a script node's container members, leaving empty ones of the same type.
static func detach_tables(node: Object) -> Array:
    var held := []
    for property in node.get_property_list():
        if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: continue
        var value = node.get(property.name)
        if value is Dictionary and not value.is_empty():
            held.append(value)
            node.set(property.name, Dictionary({}, value.get_typed_key_builtin(), value.get_typed_key_class_name(), value.get_typed_key_script(),
                value.get_typed_value_builtin(), value.get_typed_value_class_name(), value.get_typed_value_script()))
        elif value is Array and not value.is_empty():
            held.append(value)
            node.set(property.name, Array([], value.get_typed_builtin(), value.get_typed_class_name(), value.get_typed_script()))
    return held
