extends RefCounted
# Frozen complete prefix before sparse capture. Independent qualification oracle.
const GroundReceiving=preload("res://presentation/ground_receiving.gd")
static func _source(atlas, entry: Dictionary, world, snapshot: Dictionary = {}) -> Dictionary:
    var sampled: Dictionary=entry if snapshot.is_empty() else snapshot
    var info: Dictionary=atlas._entry_info(sampled)
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
    var result={"entry":entry,"info":info,"signature":signature,"geometry":geometry,"crop":crop,"same":same,
        "ground_version":sampled.get("ground_version",0),"row_indices":sampled.get("ground_indices",{}),"packets":before.get("packets",{}),"by_row":before.get("by_row",{}),
        "receivers":before.get("receivers",{})}
    if not snapshot.is_empty(): result.snapshot=snapshot
    else:
        var prepared: Dictionary=atlas.prepared_source_bindings.get(id,{})
        if not prepared.is_empty():prepared.accepted=false
        var basis=Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed()
        var source_matches:bool=not prepared.is_empty() and (atlas.prepared_dynamic_materials_match(prepared,entry) if info.dynamic else prepared.version==entry.get("source_version",0))
        if not prepared.is_empty() and prepared.signature==signature and prepared.ground_version==result.ground_version \
                and source_matches and prepared.info==info \
                and prepared.basis==basis and prepared.screen_size==world.get_viewport().get_visible_rect().size:
            prepared.accepted=true
            result.prepared_specs=prepared.specs
            result.prepared_output=prepared.output
    return result

static func _snapshot_spec(source:Dictionary,row:Dictionary,id:int,material_id:int)->Dictionary:
    # Shared passive metadata construction for ordinary and worker planning.
    # A complete source replacement can include retained floor rows that did
    # not need a new native shell; they still need their real transform/rank.
    var entry:Dictionary=source.entry
    var sampled:Dictionary=source.get("snapshot",entry)
    var row_id:String=str(row.id) if sampled.has("batch_rows") else "source"
    var geometry:Array=[]
    if not source.info.dynamic:
        var transform:PackedFloat32Array=sampled.ground_packets[row_id].data.slice(0,12) if sampled.has("batch_rows") else PackedFloat32Array()
        geometry=[source.geometry,source.crop.uv,transform]
    return {"id":str(id)+":"+row_id,"row_id":row_id,"row":row,"entry":entry,"crop":source.crop,
        "source_geometry":geometry,"source_id":id,"info":source.info,"material_id":material_id,
        "row_rank":sampled.ground_indices[row_id] if sampled.has("batch_rows") else 0}

static func _support_change(atlas, patches: Dictionary, receiver_id: String, row: Dictionary, remove: bool) -> void:
    if not GroundReceiving.eligible(row): return
    var cell=Vector2(row.position[0],row.position[1])
    if not patches.has(cell): patches[cell]=atlas.support_owners.get(cell,{}).duplicate()
    if remove: patches[cell].erase(receiver_id)
    else: patches[cell][receiver_id]=float(row.base_height_steps)

static func _plan(atlas, source_patches:Dictionary, removed:Dictionary, specs:Dictionary)->Dictionary:
    # This prefix reads only copied scalar/row data when invoked by a worker.
    # Native resources carried by specs are opaque handles, never accessed here.
    var started:int=Time.get_ticks_usec()
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
            spec.row=receiver.row; spec.row_id=receiver.row_id; spec.row_rank=maxi(receiver.index,0); specs[id]=spec
    for spec in specs.values(): spec.join_mask=GroundReceiving.mask(spec.row,supports)
    var specs_ms=(Time.get_ticks_usec()-started)/1000.0
    # Reserve only added cells in the original append order. Height growth does
    # not move existing pixel addresses; only normalized output regions change.
    # Changed crops/overflow still use the complete transactional planner.
    var cursor: Vector3i=atlas.shelf_cursor
    var positions={}
    # Keep the same reservation order as the complete world-entry/floor-row
    # traversal. Different atlas coordinates can change native interpolation
    # roundoff at byte boundaries even when all source/light inputs are equal.
    # Sort scalar source/row ranks natively. Calling a GDScript comparator for
    # every pair repeatedly traverses the same source/ground dictionaries.
    var reservation_keys=PackedInt64Array()
    var reservations:Dictionary={}
    for spec in specs.values():
        var source:Dictionary=source_patches[spec.source_id] if source_patches.has(spec.source_id) else atlas.entry_specs[spec.source_id]
        # Changed support masks can pull retained rows into this plan after
        # an insertion has shifted floor indices. Their old receiver index is
        # valid only for an unchanged source; changed sources use the exact
        # future (worker) or published (ordinary path) directory.
        var row_rank:int=source.row_indices[spec.row_id] if source.get("row_indices",{}).has(spec.row_id) else spec.row_rank
        spec.row_rank=row_rank
        var rank:int=(int(source.order)<<32)|row_rank
        if reservations.has(rank):return {"error":"duplicate_reservation_rank","source_id":spec.source_id,"row_id":spec.row_id,"rank":rank,
            "previous_source_id":reservations[rank].source_id,"previous_row_id":reservations[rank].row_id,"source_order":source.order,"row_rank":row_rank}
        reservation_keys.append(rank);reservations[rank]=spec
    reservation_keys.sort()
    for rank in reservation_keys:
        var spec:Dictionary=reservations[rank]
        if atlas.receiver_index.has(spec.id):
            var old: Dictionary=atlas.receiver_index[spec.id]
            if old.crop!=spec.crop: return {"error":"changed_crop"}
            positions[spec.id]=old.position
            continue
        var size: Vector2i=spec.crop.pixels.size
        if size.x+2>atlas.MAX_SIZE or size.y+2>atlas.MAX_SIZE: return {"error":"oversized_cell"}
        if cursor.x+size.x+1>atlas.MAX_SIZE: cursor.x=1; cursor.y+=cursor.z+2; cursor.z=0
        if cursor.y+size.y+1>atlas.MAX_SIZE: return {"error":"append_overflow"}
        positions[spec.id]=Vector2i(cursor.x,cursor.y)
        cursor.x+=size.x+2; cursor.z=maxi(cursor.z,size.y)
    var needed: int=maxi(cursor.y+cursor.z+1,atlas.viewport.size.y)
    if needed>atlas.MAX_SIZE: return {"error":"append_overflow"}
    var next_height: int=atlas.viewport.size.y
    while next_height<needed: next_height=mini(atlas.MAX_SIZE,next_height*2)
    var growing: bool=next_height!=atlas.viewport.size.y
    return {"owners":owners,"supports":supports,"specs":specs,"positions":positions,"cursor":cursor,
        "next_height":next_height,"growing":growing,"specs_ms":specs_ms,"support_cells":affected.size(),
        "reservations_ms":(Time.get_ticks_usec()-started)/1000.0-specs_ms}

# Candidate capture is incremental on the scene thread. The worker receives
# copies of row/layout metadata; all Node/Material references remain opaque.
static func token(atlas)->Array:
    return [atlas.get_instance_id(),atlas.revision,atlas.repack_count,atlas.shelf_cursor,
        atlas.viewport.size,atlas.next_source_order,atlas.delta_serial,atlas.light_cap]

static func begin_candidate(atlas,jobs:Array,removed:Dictionary,world)->Dictionary:
    return {"token":token(atlas),"jobs":jobs,"removed_sources":removed.duplicate(),"source_patches":{},
        "removed":{},"specs":{},"floor_ids":{},"capture_ids":atlas.receiver_index.keys(),"capture_cells":atlas.support_owners.keys(),
        "cursor":0,"stage":"receivers","next_order":atlas.next_source_order,"ranks":{},"bind_cursor":0,
        "ready_new":{},"ready_members":{},"ready_cull":{},"ready_pixels":0,
        "ready_list":[],"bulk_commands":[],"bulk_sources":{},"bulk_retained":[],"bulk_possible":true,
        "bulk_new_count":0,"bulk_static_new_count":0,"bulk_index_cursor":0,
        "base_lists":[atlas.receivers.size(),atlas.static_receivers.size(),atlas.groups.size()],"group_proofs":{},
        "basis":world.camera.global_basis,"screen":world.get_viewport().get_visible_rect().size,
        "passive":{"receiver_index":{},"support_owners":{},"published_supports":atlas.published_supports.duplicate(),
            "entry_specs":{},"shelf_cursor":atlas.shelf_cursor,"viewport":{"size":atlas.viewport.size},"MAX_SIZE":atlas.MAX_SIZE}}

static func capture_candidate(atlas,work:Dictionary,world)->bool:
    if work.token!=token(atlas):work.error="atlas_changed_during_capture";return true
    if work.stage=="receivers":
        if work.cursor==work.capture_ids.size():work.cursor=0;work.stage="supports";return false
        var id:String=work.capture_ids[work.cursor];work.cursor+=1
        var receiver:Dictionary=atlas.receiver_index[id]
        var spec:Dictionary=receiver.spec.duplicate()
        spec.row=receiver.row;spec.row_id=receiver.row_id;spec.row_rank=maxi(receiver.index,0)
        work.passive.receiver_index[id]={"id":id,"row":receiver.row,"row_id":receiver.row_id,"index":receiver.index,
            "join_mask":receiver.join_mask,"crop":receiver.crop,"position":receiver.position,"group_id":receiver.group.id,"spec":spec}
        work.passive.entry_specs[spec.source_id]={"order":atlas.entry_specs[spec.source_id].order}
        if work.removed_sources.has(spec.source_id):work.removed[id]=work.passive.receiver_index[id]
        return false
    if work.stage=="supports":
        if work.cursor==work.capture_cells.size():work.cursor=0;work.stage="sources";return false
        var cell:Vector2=work.capture_cells[work.cursor];work.cursor+=1
        work.passive.support_owners[cell]=atlas.support_owners[cell].duplicate()
        return false
    if work.stage=="sources":
        if work.cursor==work.jobs.size():
            for key in atlas.groups:
                var group:Dictionary=atlas.groups[key]
                work.ranks[key]=group.rank
                work.group_proofs[key]=[group,group.material,group.material.shader,group.crop,group.rank,group.get("users",0)]
            work.stage="captured";return true
        var job:Dictionary=work.jobs[work.cursor];work.cursor+=1
        var entry:Dictionary=job.entry
        var prepared:Dictionary=job.get("prepared",{})
        var snapshot:Dictionary=prepared.snapshot if not prepared.is_empty() else entry.duplicate()
        var source:Dictionary=_source(atlas,entry,world,snapshot)
        if source.crop.is_empty():work.error="missing_crop";return true
        if not prepared.is_empty() and (prepared.version!=entry.get("source_version",0)
            or prepared.signature!=source.signature or prepared.info!=source.info
            or prepared.basis!=Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed()
            or prepared.screen_size!=world.get_viewport().get_visible_rect().size):
            work.error="source_changed_before_prefix_capture";return true
        var id:int=entry.node.get_instance_id()
        var before:Dictionary=atlas.entry_specs.get(id,{})
        source.order=work.next_order if before.is_empty() else before.order
        if before.is_empty():work.next_order+=1
        source.receivers=before.get("receivers",{}).duplicate();source.by_row=before.get("by_row",{}).duplicate()
        source.packets=before.get("packets",{}).duplicate()
        source.complete=before.is_empty() or not source.same or work.removed_sources.has(id)
        if source.complete:
            for old_id in before.get("receivers",{}):
                var receiver_id:String=before.receivers[old_id].id
                work.removed[receiver_id]=work.passive.receiver_index[receiver_id]
            source.receivers={};source.by_row={};source.packets={}
        elif entry.has("batch_rows"):
            for row_id in job.packet.get("geometry_changes",{}).get("removed",[]):
                if before.receivers.has(str(row_id)):
                    var receiver_id:String=before.receivers[str(row_id)].id
                    work.removed[receiver_id]=work.passive.receiver_index[receiver_id]
        source.prepared_specs=prepared.get("specs",{})
        source.prepared_output=prepared.get("output",{})
        source.proof={"entry":entry,"cell":entry.cell,"material":entry.material,"material_id":entry.material.get_instance_id(),"version":entry.get("source_version",0),
            "ground_version":snapshot.get("ground_version",0),"scenery":snapshot.scenery_values.duplicate() if snapshot.has("scenery_values") else snapshot.get("scenery_value",1.0),
            "geometry":source.geometry,"info":source.info,"record_path":entry.get("record",{}).get("path",""),
            "record_rect":entry.get("record",{}).get("rect",[]).duplicate()}
        source.rows=snapshot.batch_rows if source.complete and entry.has("batch_rows") else [snapshot.placement] if source.complete else job.rows
        source.snapshot=snapshot
        work.source_patches[id]=source
        if entry.has("batch_rows"):work.floor_ids[id]=true
        return false
    return true

static func compute_candidate(work:Dictionary)->void:
    var started:int=Time.get_ticks_usec()
    work.complete=false
    for id in work.source_patches:
        var source:Dictionary=work.source_patches[id]
        var snapshot:Dictionary=source.snapshot
        for selected in source.rows:
            var row:Dictionary=selected if selected is Dictionary else snapshot.batch_rows[snapshot.ground_indices[str(selected)]]
            var row_id:String=str(row.id) if snapshot.has("batch_rows") else "source"
            var spec:Dictionary=source.prepared_specs.get(row_id,{})
            if spec.is_empty():spec=_snapshot_spec(source,row,id,source.proof.material_id)
            else:spec=spec.duplicate()
            spec.row_rank=snapshot.ground_indices[row_id] if snapshot.has("batch_rows") else 0
            work.specs[spec.id]=spec
    for receiver in work.removed.values():
        var source:Dictionary=work.source_patches.get(receiver.spec.source_id,{})
        if not source.is_empty():
            source.receivers.erase(receiver.row_id);source.by_row.erase(receiver.row_id);source.packets.erase(receiver.row_id)
    work.plan=_plan(work.passive,work.source_patches,work.removed,work.specs)
    if work.plan.has("error"):
        work.error=work.plan.error;work.worker_ms=(Time.get_ticks_usec()-started)/1000.0;return
    if not _candidate_addresses(work):
        work.worker_ms=(Time.get_ticks_usec()-started)/1000.0;return
    work.worker_ms=(Time.get_ticks_usec()-started)/1000.0
    work.bind_ids=work.plan.specs.keys();work.bind_cursor=0
    # The exact planned removals run before any new bind. Prepare final list
    # offsets and initial group ranks against that same post-removal prefix.
    var removed_static:int=0;var removed_groups:Dictionary={}
    for receiver in work.removed.values():
        if not receiver.spec.info.dynamic:removed_static+=1
        removed_groups[receiver.group_id]=removed_groups.get(receiver.group_id,0)+1
    work.dropped_groups={}
    for key in removed_groups:
        if removed_groups[key]==work.group_proofs[key][5]:
            work.ranks.erase(key);work.dropped_groups[key]=true
    work.bulk_base_lists=[work.base_lists[0]-work.removed.size(),work.base_lists[1]-removed_static]
    work.rank_count=work.ranks.size();work.bulk_reason="";work.complete=true

static func _candidate_addresses(work:Dictionary)->bool:
    for id in work.floor_ids:
        var source:Dictionary=work.source_patches[id]
        var snapshot:Dictionary=source.snapshot
        var buffer:PackedFloat32Array=snapshot.ground_buffer.duplicate()
        var packets:Dictionary=snapshot.ground_packets.duplicate()
        var snapshots:Dictionary=source.packets.duplicate()
        var indices:Dictionary={}
        for row in snapshot.batch_rows:
            var row_id:String=str(row.id);var receiver_id:String=str(id)+":"+row_id
            if not work.plan.positions.has(receiver_id) and not work.passive.receiver_index.has(receiver_id):
                work.error="unreserved_floor_row:"+receiver_id;return false
            var pixel:Vector2i=work.plan.positions[receiver_id] if work.plan.positions.has(receiver_id) else work.passive.receiver_index[receiver_id].position
            var index:int=snapshot.ground_indices[row_id];var offset:int=index*20
            var x:int=pixel.x%1024;var y:int=pixel.y%1024;var high:int=(pixel.x/1024)+8*(pixel.y/1024)
            buffer[offset+17]=x;buffer[offset+18]=y;buffer[offset+19]=high
            var packet:Dictionary=packets[row_id].duplicate();var data:PackedFloat32Array=packet.data.duplicate()
            data[17]=x;data[18]=y;data[19]=high;packet.data=data;packets[row_id]=packet
            var previous:Dictionary=snapshots.get(row_id,{}).duplicate();previous.data=data.duplicate();snapshots[row_id]=previous
            if work.passive.receiver_index.has(receiver_id) and work.passive.receiver_index[receiver_id].index!=index:
                indices[row_id]=index
        source.prepared_addresses={"buffer":buffer,"packets":packets,"snapshots":snapshots,"indices":indices,"count":snapshot.batch_rows.size()}
    return true

