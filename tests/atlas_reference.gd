extends RefCounted
# Interface-only adaptation: historical renderers keep their complete discovery
# scans and untouched rendering body. They ignore modern admitted-change and
# receiver-notification optimizations; no shader/cache/pixel behavior is patched.
static func instantiate(path: String) -> RefCounted:
    var original: GDScript=load(path)
    if original==null: return null
    var source: String=original.source_code
    var signatures=[
        "func sync(world: Node, published: Array = [], styles: Array = []) -> void:",
        "func sync(world: Node, published: Array = [], styles: Array = [], changes: Dictionary = {}) -> void:",
        "func sync(world: Node, published: Array = [], styles: Array = [], _changes: Dictionary = {}) -> void:"]
    for signature in signatures:
        if source.contains(signature):
            var argument="_changes" if not signature.contains("changes: Dictionary") or signature.contains("_changes: Dictionary") else "changes"
            source=source.replace(signature,"func sync(world: Node, published: Array = [], styles: Array = [], "+argument+": Dictionary = {}, _tracked_receivers: bool = false) -> void:")
            break
    if not source.contains("func style_changed("):
        source+='\nfunc style_changed(_entry: Dictionary, _row_id: String = "source") -> void:\n    pass\n'
    if not source.contains("func visibility_changed("):
        source+="\nfunc visibility_changed(_entry: Dictionary) -> void:\n    pass\n"
    if not source.contains("func floor_address_token("):
        source+="\nfunc floor_address_token(_entry: Dictionary) -> Array:\n    return []\n"
    if source==original.source_code: return original.new()
    var compatible=GDScript.new();compatible.source_code=source
    if compatible.reload()!=OK: return null
    return compatible.new()
