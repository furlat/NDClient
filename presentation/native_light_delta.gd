extends RefCounted
# Apply an already-admitted source patch. Planning stays private until every
# crop/address fits; initial scenes, missed patches and repacking use the full
# atlas planner. The world and its event clock remain owned by Play.
const GroundReceiving=preload("res://presentation/ground_receiving.gd")

static func _row(entry: Dictionary, row_id: String) -> Dictionary:
    return entry.batch_rows[entry.ground_indices[row_id]] if entry.has("batch_rows") else entry.placement

static func rebuild(atlas, serial: int) -> void:
    atlas.receiver_index={}; atlas.support_owners={}; atlas.source_groups={}
    atlas.static_receivers=[]; atlas.dynamic_receivers=[]
    atlas.next_source_order=0
    for source in atlas.entry_specs.values():
        source.receivers={}; source.order=atlas.next_source_order
        atlas.next_source_order+=1
    for group in atlas.groups.values():
        group.users=0
        var id: int=group.entry.node.get_instance_id()
        group.source_id=id
        if not atlas.source_groups.has(id): atlas.source_groups[id]={}
        atlas.source_groups[id][group.id]=group
    for i in atlas.receivers.size():
        var receiver: Dictionary=atlas.receivers[i]
        var entry: Dictionary=receiver.entry
        var row: Dictionary=entry.batch_rows[receiver.index] if receiver.index>=0 else entry.placement
        receiver.row_id=str(row.id) if receiver.index>=0 else "source"
        receiver.row=row; receiver.list_index=i
        var partition: Array=atlas.dynamic_receivers if receiver.dynamic else atlas.static_receivers
        receiver.partition_index=partition.size(); partition.append(receiver)
        atlas.receiver_index[receiver.id]=receiver
        var source: Dictionary=atlas.entry_specs[entry.node.get_instance_id()]
        source.receivers[receiver.row_id]=receiver; source.info=receiver.spec.info
        receiver.group.users+=1
        if GroundReceiving.eligible(row):
            var cell=Vector2(row.position[0],row.position[1])
            if not atlas.support_owners.has(cell): atlas.support_owners[cell]={}
            atlas.support_owners[cell][receiver.id]=float(row.base_height_steps)
    atlas.delta_serial=serial; atlas.delta_ready=true

static func _source(atlas, entry: Dictionary, world) -> Dictionary:
    var info: Dictionary=atlas._entry_info(entry)
    var geometry: Array=[]
    if not info.dynamic:
        var mesh: QuadMesh=entry.node.multimesh.mesh if entry.has("batch_rows") else entry.node.mesh
        geometry=[entry.node.global_transform,mesh.size,mesh.center_offset]
    var record: Dictionary={} if info.dynamic else entry.get("record",{})
    var signature=[entry.cell,record.get("path",""),record.get("rect",[]),info.shader,entry.material.get_instance_id(),geometry]
    var id: int=entry.node.get_instance_id()
    var before: Dictionary=atlas.entry_specs.get(id,{})
    var same: bool=not before.is_empty() and is_same(before.entry,entry) and before.signature==signature
    var crop: Dictionary=before.crop if same else atlas._crop(entry,world,info)
    return {"entry":entry,"info":info,"signature":signature,"geometry":geometry,"crop":crop,"same":same,
        "ground_version":entry.get("ground_version",0),"packets":before.get("packets",{}),"by_row":before.get("by_row",{}),
        "receivers":before.get("receivers",{})}

static func _spec(source: Dictionary, row: Dictionary) -> Dictionary:
    var entry: Dictionary=source.entry
    var id: int=entry.node.get_instance_id()
    var row_id: String=str(row.id) if entry.has("batch_rows") else "source"
    var geometry: Array=[]
    if not source.info.dynamic:
        var transform: PackedFloat32Array=entry.ground_packets[row_id].data.slice(0,12) if entry.has("batch_rows") else PackedFloat32Array()
        geometry=[source.geometry,source.crop.uv,transform]
    return {"id":str(id)+":"+row_id,"row_id":row_id,"row":row,"entry":entry,"crop":source.crop,
        "source_geometry":geometry,"source_id":id,"info":source.info,"material_id":entry.material.get_instance_id()}

static func _support_change(atlas, patches: Dictionary, receiver_id: String, row: Dictionary, remove: bool) -> void:
    if not GroundReceiving.eligible(row): return
    var cell=Vector2(row.position[0],row.position[1])
    if not patches.has(cell): patches[cell]=atlas.support_owners.get(cell,{}).duplicate()
    if remove: patches[cell].erase(receiver_id)
    else: patches[cell][receiver_id]=float(row.base_height_steps)

static func _remove_list(values: Array, index: int, field: String) -> void:
    var last: Dictionary=values.back()
    if index<values.size()-1:
        values[index]=last; last[field]=index
    values.pop_back()

static func drop_group(atlas, group: Dictionary) -> void:
    group.users-=1
    if group.users>0: return
    atlas.groups.erase(group.id)
    if atlas.source_groups.has(group.source_id): atlas.source_groups[group.source_id].erase(group.id)

static func _remove(atlas, receiver: Dictionary) -> void:
    if not receiver.dynamic and receiver.get("view_visible",false): atlas.static_live_receivers-=1
    _remove_list(atlas.receivers,receiver.list_index,"list_index")
    _remove_list(atlas.dynamic_receivers if receiver.dynamic else atlas.static_receivers,receiver.partition_index,"partition_index")
    atlas.receiver_index.erase(receiver.id)
    var source: Dictionary=atlas.entry_specs[receiver.spec.source_id]
    source.receivers.erase(receiver.row_id); source.by_row.erase(receiver.row_id); source.packets.erase(receiver.row_id)
    drop_group(atlas,receiver.group)
    receiver.node.visible=false; receiver.node.queue_free()

static func _bind(atlas, spec: Dictionary, position: Vector2i) -> Dictionary:
    var entry: Dictionary=spec.entry
    var index: int=entry.ground_indices[spec.row_id] if entry.has("batch_rows") else -1
    var visibility: float=entry.scenery_values[index] if index>=0 else float(entry.get("scenery_value",1.0))
    var receiver: Dictionary=atlas.receiver_index.get(spec.id,{})
    var group: Dictionary=atlas._group(entry,spec.crop,visibility,spec.id,spec.info,spec.join_mask)
    if not group.has("users"): group.users=0
    if receiver.is_empty():
        receiver=atlas._make_receiver(spec,group,index)
        receiver.list_index=atlas.receivers.size(); atlas.receivers.append(receiver)
        receiver.dynamic=spec.info.dynamic
        var partition: Array=atlas.dynamic_receivers if receiver.dynamic else atlas.static_receivers
        receiver.partition_index=partition.size(); partition.append(receiver)
        atlas.receiver_index[spec.id]=receiver; group.users+=1
    elif not is_same(receiver.group,group):
        drop_group(atlas,receiver.group); group.users+=1
    receiver.entry=entry; receiver.index=index; receiver.crop=spec.crop; receiver.group=group
    receiver.water=spec.info.water; receiver.source_material=spec.material_id; receiver.receiving_shader=spec.info.shader
    receiver.visibility=visibility; receiver.join_mask=spec.join_mask; receiver.row_id=spec.row_id; receiver.row=spec.row
    if receiver.node.material!=group.material: receiver.node.material=group.material
    if receiver.get("source_geometry",[])!=spec.source_geometry or receiver.projection.is_empty():
        receiver.projection=[]
        if not receiver.dynamic: atlas.projection_dirty.append(receiver)
    receiver.source_geometry=spec.source_geometry; receiver.spec=spec
    var region=Rect2(Vector2(position),Vector2(receiver.crop.pixels.size))
    if receiver.get("region",Rect2())!=region:
        receiver.node.region_rect=region; receiver.region=region
    receiver.position=position
    var rank: int=group.rank%1024
    if receiver.get("rank",-1)!=rank: receiver.node.z_index=rank; receiver.rank=rank
    var source: Dictionary=atlas.entry_specs[spec.source_id]
    source.receivers[spec.row_id]=receiver; source.by_row[spec.row_id]=spec
    if not receiver.dynamic: atlas.cull_dirty[receiver.id]=true
    return receiver

static func reconcile(atlas, world, changes: Dictionary) -> bool:
    if not atlas.delta_ready or atlas.delta_serial<0: return false
    var serial: int=int(changes.serial)
    var new_world: bool=serial!=atlas.delta_serial
    if new_world and (int(changes.base)!=atlas.delta_serial or bool(changes.full)): return false
    var screen=Vector2i(world.get_viewport().get_visible_rect().size)
    if screen.x>atlas.viewport.size.x or screen.y>atlas.viewport.size.y: return false
    var started=Time.get_ticks_usec()
    var upserts={}; var removed_sources={}
    if new_world:
        for id in changes.removed: removed_sources[id]=true
        for entry in changes.upserts: upserts[entry.node.get_instance_id()]=entry
    # Actor/flame identity is separate from static world admission. Frame/sample
    # changes retain their full cell and remain source_version updates in sync.
    var dynamic_ids={}
    for entries in [world.actor_entries,world.fixture_entries]:
        for entry in entries:
            if not entry.has("cell") or not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion(): continue
            var id: int=entry.node.get_instance_id()
            dynamic_ids[id]=true
            if not atlas.entry_specs.has(id) or not is_same(atlas.entry_specs[id].entry,entry) or atlas.entry_specs[id].signature[0]!=entry.cell:
                upserts[id]=entry
    for receiver in atlas.dynamic_receivers:
        if not dynamic_ids.has(receiver.spec.source_id): removed_sources[receiver.spec.source_id]=true
    if upserts.is_empty() and removed_sources.is_empty():
        atlas.delta_serial=serial
        atlas.last_reconcile_phases.delta_sources=0
        return true
    var source_patches={}; var removed={}; var specs={}; var floor_ids={}; var address_changes={}
    var next_order: int=atlas.next_source_order
    for id in removed_sources:
        if not atlas.entry_specs.has(id): continue
        for receiver in atlas.entry_specs[id].receivers.values(): removed[receiver.id]=receiver
    for id in upserts:
        var entry: Dictionary=upserts[id]
        if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion() or not entry.has("cell"): continue
        var source=_source(atlas,entry,world)
        if source.crop.is_empty(): return false
        var before: Dictionary=atlas.entry_specs.get(id,{})
        if before.is_empty(): source.order=next_order; next_order+=1
        else: source.order=before.order
        var complete: bool=before.is_empty() or not source.same or removed_sources.has(id)
        if complete:
            if not before.is_empty():
                for receiver in before.receivers.values(): removed[receiver.id]=receiver
            source.receivers={}; source.by_row={}; source.packets={}
            var rows: Array=entry.batch_rows if entry.has("batch_rows") else [entry.placement]
            for row in rows:
                var spec=_spec(source,row); specs[spec.id]=spec
        elif entry.has("batch_rows"):
            if before.ground_version!=source.ground_version:
                var geometry: Dictionary=entry.get("geometry_changes",{})
                if geometry.get("base_version",-1)!=before.ground_version or geometry.get("version",-1)!=source.ground_version: return false
                # Retained cells never move in the sparse planner. The existing
                # repack counter invalidates worker copies if a complete planner
                # could have moved them while preparation was pending.
                var expected=[atlas.get_instance_id(),atlas.repack_count,id,before.ground_version]
                if entry.get("prepared_address_version",-1)==source.ground_version and entry.get("prepared_address_token",[])==expected:
                    address_changes[id]=geometry.changed
                for row_id in geometry.removed:
                    if before.receivers.has(str(row_id)):
                        var receiver: Dictionary=before.receivers[str(row_id)]; removed[receiver.id]=receiver
                for row_id in geometry.changed:
                    var spec=_spec(source,_row(entry,str(row_id))); specs[spec.id]=spec
        else:
            var spec=_spec(source,entry.placement); specs[spec.id]=spec
        if entry.has("batch_rows"): floor_ids[id]=true
        source_patches[id]=source
    # Only the old/new support cells need new maxima. Multiple elevations at
    # one cell retain independent owners; removing the top must expose the next.
    var owners={}
    for receiver in removed.values(): _support_change(atlas,owners,receiver.id,receiver.row,true)
    for spec in specs.values():
        if atlas.receiver_index.has(spec.id) and not removed.has(spec.id):
            var receiver: Dictionary=atlas.receiver_index[spec.id]
            _support_change(atlas,owners,spec.id,receiver.row,true)
        _support_change(atlas,owners,spec.id,spec.row,false)
    var supports: Dictionary=atlas.published_supports.duplicate()
    var affected={}
    for cell in owners:
        var height: float=-INF
        for value in owners[cell].values(): height=maxf(height,float(value))
        if height==-INF: supports.erase(cell)
        else: supports[cell]=height
        if supports.get(cell,-INF)!=atlas.published_supports.get(cell,-INF):
            affected[cell]=true
            for direction in GroundReceiving.DIRECTIONS: affected[cell+direction]=true
    for cell in affected:
        var neighbours: Dictionary=owners.get(cell,atlas.support_owners.get(cell,{}))
        for id in neighbours:
            if specs.has(id) or removed.has(id) or not atlas.receiver_index.has(id): continue
            var receiver: Dictionary=atlas.receiver_index[id]
            var mask: int=GroundReceiving.mask(receiver.row,supports)
            if mask==receiver.join_mask: continue
            var spec: Dictionary=receiver.spec.duplicate()
            spec.row=receiver.row; spec.row_id=receiver.row_id; specs[id]=spec
    for spec in specs.values(): spec.join_mask=GroundReceiving.mask(spec.row,supports)
    atlas.last_reconcile_phases.specs_ms=(Time.get_ticks_usec()-started)/1000.0
    atlas.last_reconcile_phases.delta_sources=source_patches.size()
    atlas.last_reconcile_phases.delta_specs=specs.size()
    atlas.last_reconcile_phases.delta_support_cells=affected.size()
    # Reserve only added cells. A resize or changed crop falls back to the full
    # transactional planner, which handles all normalized output addresses.
    var cursor: Vector3i=atlas.shelf_cursor
    var positions={}
    # Keep the same reservation order as the complete world-entry/floor-row
    # traversal. Different atlas coordinates can change native interpolation
    # roundoff at byte boundaries even when all source/light inputs are equal.
    var reservations: Array=specs.values()
    reservations.sort_custom(func(a,b):
        var source_a: Dictionary=source_patches[a.source_id] if source_patches.has(a.source_id) else atlas.entry_specs[a.source_id]
        var source_b: Dictionary=source_patches[b.source_id] if source_patches.has(b.source_id) else atlas.entry_specs[b.source_id]
        if source_a.order!=source_b.order: return source_a.order<source_b.order
        return a.entry.ground_indices[a.row_id]<b.entry.ground_indices[b.row_id] if a.entry.has("batch_rows") else false)
    for spec in reservations:
        if atlas.receiver_index.has(spec.id):
            var old: Dictionary=atlas.receiver_index[spec.id]
            if old.crop!=spec.crop: return false
            positions[spec.id]=old.position
            continue
        var size: Vector2i=spec.crop.pixels.size
        if size.x+2>atlas.MAX_SIZE or size.y+2>atlas.MAX_SIZE: return false
        if cursor.x+size.x+1>atlas.MAX_SIZE: cursor.x=1; cursor.y+=cursor.z+2; cursor.z=0
        if cursor.y+size.y+1>atlas.viewport.size.y: return false
        positions[spec.id]=Vector2i(cursor.x,cursor.y)
        cursor.x+=size.x+2; cursor.z=maxi(cursor.z,size.y)
    # Commit only after all reservations and source receipts have been checked.
    var phase=Time.get_ticks_usec()
    for receiver in removed.values():
        atlas.packed_pixels-=receiver.crop.pixels.size.x*receiver.crop.pixels.size.y
        atlas.layout_members.erase(receiver.id)
        _remove(atlas,receiver)
    for id in removed_sources:
        atlas.entry_specs.erase(id); atlas.source_groups.erase(id)
    for id in source_patches:
        atlas.entry_specs[id]=source_patches[id]
        atlas.material_dirty[id]=true
    for cell in owners:
        if owners[cell].is_empty(): atlas.support_owners.erase(cell)
        else: atlas.support_owners[cell]=owners[cell]
    atlas.published_supports=supports
    for spec in specs.values():
        if not atlas.layout_members.has(spec.id): atlas.packed_pixels+=spec.crop.pixels.size.x*spec.crop.pixels.size.y
        atlas.layout_members[spec.id]=spec.crop
        _bind(atlas,spec,positions[spec.id])
    atlas.shelf_cursor=cursor; atlas.delta_serial=serial; atlas.next_source_order=next_order
    atlas.last_reconcile_phases.receivers_ms=(Time.get_ticks_usec()-phase)/1000.0
    phase=Time.get_ticks_usec()
    var outputs=[]; var floors={}
    for id in source_patches:
        var source: Dictionary=atlas.entry_specs[id]
        var entry: Dictionary=source.entry
        var shader: Shader=source.info.output
        if not entry.has("received_material"):
            entry.received_material=ShaderMaterial.new()
        var output: ShaderMaterial=entry.received_material
        if output.shader!=shader:
            output.shader=shader; entry.erase("received_source_key")
        output.set_shader_parameter("received",atlas.viewport.get_texture())
        output.set_shader_parameter("received_is_encoded_hdr",atlas._uses_hdr())
        output.set_shader_parameter("use_instance_atlas",entry.has("batch_rows"))
        output.set_shader_parameter("light_cap",atlas.light_cap)
        entry.node.material_override=output; source.output=output
        atlas.output_changed(entry)
        if floor_ids.has(id):
            var repairs: Array=[]
            if address_changes.has(id):
                for row_id in address_changes[id]: repairs.append(source.receivers[str(row_id)])
            else: repairs=source.receivers.values()
            floors[id]={"entry":entry,"receivers":repairs,"crop":source.crop,"repair_indices":true,
                "preserved_rows":source.receivers.size()-repairs.size(),
                "coherent_addresses":entry.get("prepared_address_version",-1)==entry.get("ground_version",0)}
        else: outputs.append_array(source.receivers.values())
    atlas._publish_addresses(floors,outputs)
    atlas.last_reconcile_phases.addresses_ms=(Time.get_ticks_usec()-phase)/1000.0
    atlas.last_reconcile_phases.layout_mode="delta"
    atlas.revision+=1
    return true
