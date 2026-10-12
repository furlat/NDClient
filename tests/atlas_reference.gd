extends RefCounted
# Historical fixtures predate the optional admitted-change argument. Accept it
# without changing any reference rendering body, cache, lighting or sampling.
static func instantiate(path: String) -> RefCounted:
    var original: GDScript=load(path)
    if original==null: return null
    var old="func sync(world: Node, published: Array = [], styles: Array = []) -> void:"
    if not original.source_code.contains(old): return original.new()
    var compatible=GDScript.new()
    compatible.source_code=original.source_code.replace(old,"func sync(world: Node, published: Array = [], styles: Array = [], _changes: Dictionary = {}) -> void:")
    if compatible.reload()!=OK: return null
    return compatible.new()
