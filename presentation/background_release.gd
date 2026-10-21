extends RefCounted
## Dropping the last reference to large data (decoded images, a retired view's
## tables) frees megabytes and thousands of Variants; on the main thread it took
## 2-6 ms. These references are dropped on a worker instead. They must not be
## the only owners of Nodes (Nodes are freed explicitly, never by refcount).
static var _tasks: Array[int] = []
static var _joins_at_exit := false

static func release(values: Array) -> void:
    for i in range(_tasks.size() - 1, -1, -1):
        if WorkerThreadPool.is_task_completed(_tasks[i]):
            WorkerThreadPool.wait_for_task_completion(_tasks[i]); _tasks.remove_at(i)
    if values.is_empty(): return
    # Retired tables can own the last Material reference. Godot's headless
    # dummy RID owner cannot free it concurrently with scene construction.
    if DisplayServer.get_name()=="headless" and RenderingServer.get_rendering_device()==null:
        values.clear()
        return
    if not _joins_at_exit:
        # Whatever owner released them, every release finishes before the
        # scene tree, and with it the scripts of what they free, shuts down.
        (Engine.get_main_loop() as SceneTree).root.tree_exiting.connect(func(): join(), CONNECT_ONE_SHOT)
        _joins_at_exit = true
    _tasks.append(WorkerThreadPool.add_task(func(): values.clear(), false, "Release retired data"))

## A retiring subtree keeps its ordinary teardown: deletion still runs its
## _exit_tree. Once the whole subtree has left the tree, its script nodes'
## containers (and `extra` data it shared, such as a replaced recording index)
## are taken from it. They are dropped on a worker on the next frame, after its
## Nodes, and any viewport textures they own, were freed on the main thread.
static func release_after_exit(root: Node, extra: Array = []) -> void:
    root.tree_exited.connect(func():
        var held := extra
        for node in root.find_children("*", "", true, false):
            if node.get_script() != null: held.append_array(detach_tables(node))
        if root.get_script() != null: held.append_array(detach_tables(root))
        (Engine.get_main_loop() as SceneTree).process_frame.connect(func(): release(held), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)

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
