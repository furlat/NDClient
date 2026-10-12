extends RefCounted
# Numeric floor preparation. No scene nodes, resources or renderer calls.
const Placement = preload("res://placement.gd")

static func sort_rows(rows: Array, packets: Dictionary, quarter: int) -> void:
    var keys := PackedFloat64Array()
    keys.resize(rows.size())
    for i in range(rows.size()):
        var row: Dictionary = rows[i]
        if not packets.has(row.id) or packets[row.id].row!=row:
            packets[row.id] = {"row":row,"y":Placement.project(Vector2(row.position[0],row.position[1]),0,quarter).y}
        keys[i] = packets[row.id].y
    var order: Array = range(rows.size())
    order.sort_custom(func(a,b):return keys[a]<keys[b])
    var sorted: Array = []; sorted.resize(rows.size())
    for i in range(order.size()): sorted[i] = rows[order[i]]
    rows.assign(sorted)

static func prepare(rows: Array, previous: Dictionary, quarter: int, basis: Basis, visibility: Dictionary) -> Dictionary:
    var packets: Dictionary = previous.packets.duplicate()
    rows = rows.duplicate()
    sort_rows(rows,packets,quarter)
    var retained = {}; var indices = {}; var buffer = PackedFloat32Array(); var bounds = AABB(); var values: Array = []
    var changed: Array = []; var removed: Array = []
    for i in range(rows.size()):
        var row: Dictionary = rows[i]
        var packet: Dictionary = packets[row.id].duplicate()
        if not packet.has("data"):
            # sort_rows invalidates geometry from immutable source-row changes.
            # Visibility and atlas addresses are mutable packet channels and
            # must never decide whether source geometry changed in this worker.
            changed.append(row.id)
            var transform = Transform3D(basis,Placement.contact(row))
            var b = transform.basis; var o = transform.origin
            packet.data = PackedFloat32Array([b.x.x,b.y.x,b.z.x,o.x,b.x.y,b.y.y,b.z.y,o.y,b.x.z,b.y.z,b.z.z,o.z,1,1,1,1,0,0,0,0])
            packet.bounds = transform*previous.receiver_bounds
        var data: PackedFloat32Array = packet.data.duplicate()
        data[16] = 1.0 if visibility.has(row.id) else 0.0
        packet.data = data
        retained[row.id] = packet; indices[row.id] = i
        buffer.append_array(data); values.append(data[16])
        bounds = packet.bounds if i==0 else bounds.merge(packet.bounds)
    buffer.resize(maxi(previous.capacity,ceili(rows.size()/256.0)*256)*20)
    for id in previous.packets:
        if not retained.has(id): removed.append(id)
    var geometry_changes = {"base_version":previous.get("ground_version",-1),"changed":changed,"removed":removed}
    return {"rows":rows,"packets":retained,"indices":indices,"buffer":buffer,"bounds":bounds,"values":values,"geometry_changes":geometry_changes}
