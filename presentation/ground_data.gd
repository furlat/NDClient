extends RefCounted
# Immutable floor geometry is separate from mutable visibility/address packets.
# A worker borrows only capture_geometry output; its owner adopts a completed
# patch before lending that base to another task. No scene/resource operations.
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
    # Explicit source ordinal preserves equal-Y insertion order independently
    # of sort_custom's unstable ordering of equivalent elements.
    order.sort_custom(func(a,b):return keys[a]<keys[b] or (keys[a]==keys[b] and a<b))
    var sorted: Array = []; sorted.resize(rows.size())
    for i in range(order.size()): sorted[i] = rows[order[i]]
    rows.assign(sorted)

static func _geometry(row: Dictionary, receiver_bounds: AABB, quarter: int, basis: Basis) -> Dictionary:
    var transform = Transform3D(basis,Placement.contact(row))
    return {"row":row,"y":Placement.project(Vector2(row.position[0],row.position[1]),0,quarter).y,
        "transform":transform,"bounds":transform*receiver_bounds}

static func capture_geometry(rows: Array, receiver_bounds: AABB, quarter: int, basis: Basis, previous: Dictionary = {}) -> Dictionary:
    # Initial build or explicit affected-batch rebuild. Source rows are immutable;
    # the array and every numeric geometry record belong to this new base.
    var records = {}; var indices = {}; var ranks = {}; var bounds = AABB()
    var reuse: bool = previous.get("quarter",-1)==quarter and previous.get("basis") == basis and previous.get("receiver_bounds") == receiver_bounds
    for i in rows.size(): ranks[rows[i].id] = i
    rows = rows.duplicate()
    sort_rows(rows,records,quarter)
    for i in rows.size():
        var row: Dictionary = rows[i]
        var old: Dictionary = previous.get("records",{}).get(row.id,{}) if reuse else {}
        var record: Dictionary = old if old.get("row") == row else _geometry(row,receiver_bounds,quarter,basis)
        records[row.id] = record; indices[row.id] = i
        bounds = record.bounds if i==0 else bounds.merge(record.bounds)
    return {"rows":rows,"records":records,"indices":indices,"source_ranks":ranks,"bounds":bounds,
        "receiver_bounds":receiver_bounds,"quarter":quarter,"basis":basis}

static func capture_previous(previous: Dictionary, quarter: int, basis: Basis) -> Dictionary:
    # Owner-only migration adapter for existing fixtures/native batch builders.
    # Capture before launching a worker. Never pass live packets to preparation.
    var rows: Array = []
    for packet in previous.packets.values(): rows.append(packet.row)
    var geometry = capture_geometry(rows,previous.receiver_bounds,quarter,basis)
    var bounds = AABB()
    for i in geometry.rows.size():
        var row: Dictionary = geometry.rows[i]
        var packet: Dictionary = previous.packets[row.id]
        var data: PackedFloat32Array = packet.data
        var transform = Transform3D(Basis(Vector3(data[0],data[4],data[8]),Vector3(data[1],data[5],data[9]),
            Vector3(data[2],data[6],data[10])),Vector3(data[3],data[7],data[11]))
        var record: Dictionary = geometry.records[row.id]
        record.transform = transform; record.bounds = packet.get("bounds",transform*previous.receiver_bounds)
        bounds = record.bounds if i==0 else bounds.merge(record.bounds)
    geometry.bounds = bounds
    return {"geometry":geometry,"receiver_bounds":previous.receiver_bounds,"capacity":previous.capacity,
        "ground_version":previous.get("ground_version",-1)}

static func _ordered_pair(a: Dictionary, b: Dictionary, ranks: Dictionary) -> bool:
    return a.y<b.y or (a.y==b.y and ranks[a.row.id]<ranks[b.row.id])

static func prepare_changes(changed_rows: Dictionary, removed_ids: Array, base: Dictionary, order_changed: bool = false) -> Dictionary:
    var patch = {"rebuild_required":false,"records":{},"indices":{},"changed":[],"removed":removed_ids,"bounds":base.bounds}
    if order_changed:
        patch.rebuild_required = true; return patch
    for id in removed_ids:
        if base.records.has(id): patch.rebuild_required = true; return patch
    for id in changed_rows:
        if not base.records.has(id): patch.rebuild_required = true; return patch
        var row: Dictionary = changed_rows[id]
        if row==base.records[id].row: continue
        var record = _geometry(row,base.receiver_bounds,base.quarter,base.basis)
        patch.records[id] = record; patch.indices[id] = base.indices[id]; patch.changed.append(id)
        # Conservative union keeps publication sparse and cannot clip a moved
        # receiver. Exact shrinking occurs at the next affected-batch rebuild.
        patch.bounds = patch.bounds.merge(record.bounds)
    # Only neighbors of changed slots can violate the existing sorted order.
    # Equal-Y ties use source membership order, never UUID or changed-map order.
    for id in patch.records:
        var index: int = base.indices[id]
        var record: Dictionary = patch.records[id]
        if index>0:
            var previous_id: String = base.rows[index-1].id
            var previous: Dictionary = patch.records.get(previous_id,base.records[previous_id])
            if not _ordered_pair(previous,record,base.source_ranks): patch.rebuild_required = true; return patch
        if index+1<base.rows.size():
            var next_id: String = base.rows[index+1].id
            var next: Dictionary = patch.records.get(next_id,base.records[next_id])
            if not _ordered_pair(record,next,base.source_ranks): patch.rebuild_required = true; return patch
    return patch

static func apply_geometry(base: Dictionary, patch: Dictionary) -> void:
    # Caller handles rebuild_required during preparation, before publication.
    for id in patch.records:
        base.records[id] = patch.records[id]
        base.rows[patch.indices[id]] = patch.records[id].row
    base.bounds = patch.bounds

static func _packet(record: Dictionary, visible: bool) -> Dictionary:
    var transform: Transform3D = record.transform
    var b = transform.basis; var o = transform.origin
    return {"row":record.row,"y":record.y,"bounds":record.bounds,
        "data":PackedFloat32Array([b.x.x,b.y.x,b.z.x,o.x,b.x.y,b.y.y,b.z.y,o.y,b.x.z,b.y.z,b.z.z,o.z,
            1,1,1,1,1.0 if visible else 0.0,0,0,0])}

static func prepare(rows: Array, previous: Dictionary, quarter: int, basis: Basis, visibility: Dictionary) -> Dictionary:
    # Full affected-batch preparation. previous.geometry is an immutable geometry
    # base, never live ground_packets. Fresh custom channels cannot inherit an
    # atlas-address token; publication must merge current owned addresses by ID.
    assert(not previous.has("packets"),"Capture immutable ground geometry before launching preparation")
    var geometry = capture_geometry(rows,previous.receiver_bounds,quarter,basis,previous.get("geometry",{}))
    var old: Dictionary = previous.get("geometry",{}).get("records",{})
    var packets = {}; var buffer = PackedFloat32Array(); var values: Array = []
    var changed: Array = []; var removed: Array = []
    for row in geometry.rows:
        var record: Dictionary = geometry.records[row.id]
        if not old.has(row.id) or old[row.id].row!=row or old[row.id].transform!=record.transform:
            changed.append(row.id)
        var packet = _packet(record,visibility.has(row.id))
        packets[row.id] = packet
        buffer.append_array(packet.data); values.append(packet.data[16])
    buffer.resize(maxi(previous.capacity,ceili(geometry.rows.size()/256.0)*256)*20)
    for id in old:
        if not geometry.records.has(id): removed.append(id)
    var geometry_changes = {"base_version":previous.get("ground_version",-1),"changed":changed,"removed":removed}
    return {"rows":geometry.rows,"geometry":geometry,"packets":packets,"indices":geometry.indices,"buffer":buffer,
        "bounds":geometry.bounds,"values":values,"geometry_changes":geometry_changes,"address_token":[]}
