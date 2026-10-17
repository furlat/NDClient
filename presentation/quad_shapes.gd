extends RefCounted
## Sprite quads shared by shape. A node built on a worker with its own mesh
## costs about 6 us to attach, with a shared mesh about 1.4 us. A shared quad is
## never mutated: a shape change swaps the node's mesh.
static var _meshes: Dictionary = {}
static var _lock := Mutex.new()

static func mesh(size: Vector2, center: Vector3 = Vector3.ZERO) -> QuadMesh:
    var key := [size, center]
    _lock.lock()
    var shared: QuadMesh = _meshes.get(key)
    if shared == null:
        shared = QuadMesh.new(); shared.size = size; shared.center_offset = center
        shared.get_rid() # Builds the surface now, not on the first frame that draws it.
        _meshes[key] = shared
    _lock.unlock()
    return shared
