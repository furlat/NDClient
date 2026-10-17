extends RefCounted
# Apply an already-admitted source patch. Planning stays private until every
# crop/address fits; initial scenes, missed patches and repacking use the full
# atlas planner. The world and its event clock remain owned by Play.
const SourceMaterial=preload("res://presentation/source_material.gd")
const GroundReceiving=preload("res://presentation/ground_receiving.gd")
const CanvasDraw=preload("res://presentation/canvas_draw.gd")
const CanvasBatch=preload("res://presentation/canvas_batch.gd")

static func new_group(entry:Dictionary,crop:Dictionary,visibility:float,id:Array,info:Dictionary,join_mask:int)->Dictionary:
    var material=ShaderMaterial.new();material.shader=info.shader
    return {"id":id,"entry":entry,"info":info,"material":material,"crop":crop,"version":-1,"source_shader":null,
        "highlighted":null,"visibility":visibility,"join_mask":join_mask,"rank":0,"water":info.water}

static func static_group(input:Dictionary,key:Array,visibility:float,join_mask:int,world_origin:Variant=null)->Dictionary:
    # One private receiving material from captured source values. The planner
    # and the environment resource producer construct it identically.
    var group:Dictionary=new_group(input.get("entry",{}),input.crop,visibility,key,input.info,join_mask)
    var material:ShaderMaterial=group.material
    for name in input.parameters:material.set_shader_parameter(name,input.parameters[name])
    material.set_shader_parameter("use_instance_visibility",false)
    material.set_shader_parameter("source_crop",input.crop.uv)
    material.set_shader_parameter("atlas_cell_size",Vector2(input.crop.pixels.size))
    material.set_shader_parameter("receiver_visibility",visibility)
    material.set_shader_parameter("ground_join_mask",join_mask)
    material.set_shader_parameter("store_irradiance",input.info.capped)
    material.set_shader_parameter("world_to_canvas",input.basis)
    material.set_shader_parameter("actual_scene_viewport_size",input.screen)
    material.set_shader_parameter("highlighted",input.highlighted)
    if input.info.water:material.set_shader_parameter("receiver_world_origin",world_origin)
    group.version=input.version;group.source_shader=input.source_shader;group.source_material=input.source_material
    group.target_material=material;group.target_shader=input.info.shader;group.binding_revision=input.binding_revision
    group.capped=input.info.capped;group.seconds=null;group.highlighted=input.highlighted
    return group

static func realize_output(output:Dictionary)->void:
    # The deferred output material of one private source, realized once.
    var input:Dictionary=output.input
    var material:ShaderMaterial=ShaderMaterial.new();material.shader=input.shader
    for name in input.parameters:material.set_shader_parameter(name,input.parameters[name])
    material.get_rid()
    output.received_material=material;output.binding=input.binding
    if input.capped:
        var sample:Dictionary=output.sample
        output.received_source_key={"binding_revision":sample.binding_revision,"version":sample.version,
            "output":material,"output_shader":input.shader,"quad_size":input.quad_size}
        output.received_style={"output":material,"visibility":sample.visibility,"highlighted":sample.highlighted,"seconds":sample.seconds}
    output.erase("input")

static func _row(entry: Dictionary, row_id: String) -> Dictionary:
    return entry.batch_rows[entry.ground_indices[row_id]] if entry.has("batch_rows") else entry.placement

static func row_index(receiver:Dictionary)->int:
    # Packed floor slots belong to the published floor directory. A different
    # tile can shift them without changing this receiving node or its pixels.
    return int(receiver.entry.ground_indices[receiver.row_id]) if receiver.index>=0 else -1

static func sampled_row(sampled:Dictionary,id:String)->Dictionary:
    return sampled.get("ground_row_changes",{}).get(id,sampled.batch_rows[sampled.ground_indices[id]])

static func sampled_visibility(sampled:Dictionary,row_id:String,index:int)->float:
    if sampled.has("ground_visibility"):return float(sampled.ground_visibility.get(row_id,1.0))
    return float(sampled.scenery_values[index]) if sampled.has("batch_rows") else float(sampled.get("scenery_value",1.0))

static func rebuild(atlas, serial: int) -> void:
    atlas.receiver_index={}; atlas.support_owners={}; atlas.source_groups={}
    atlas.static_receivers=[]; atlas.dynamic_receivers=[]
    atlas.next_source_order=0
    for source in atlas.entry_specs.values():
        source.receivers={}; source.addresses={}; source.order=atlas.next_source_order
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
        if receiver.index>=0:source.addresses[receiver.row_id]={"position":receiver.position,"index":receiver.index}
        receiver.group.users+=1
        if GroundReceiving.eligible(row):
            var cell=Vector2(row.position[0],row.position[1])
            if not atlas.support_owners.has(cell): atlas.support_owners[cell]={}
            atlas.support_owners[cell][receiver.id]=float(row.base_height_steps)
    atlas.delta_serial=serial; atlas.delta_ready=true

static func _source(atlas, entry: Dictionary, world, snapshot: Dictionary = {}, target_options: Dictionary = {}) -> Dictionary:
    var sampled: Dictionary=entry if snapshot.is_empty() else snapshot
    var info: Dictionary=atlas._entry_info(sampled,target_options)
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
        "receivers":before.get("receivers",{}),"addresses":before.get("addresses",{})}
    if not snapshot.is_empty(): result.snapshot=snapshot
    else:
        var prepared: Dictionary=atlas.prepared_source_bindings.get(id,{})
        if not prepared.is_empty():prepared.accepted=false
        var basis=Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed()
        var source_matches:bool=not prepared.is_empty() and (atlas.prepared_dynamic_materials_match(prepared,entry) if info.dynamic else prepared.version==entry.get("source_version",0))
        if info.dynamic and prepared.is_empty():
            atlas.dynamic_prepared_miss(entry,prepared,"absent_"+entry.get("atlas_preparation",{}).get("status","no_actor_preparation"))
        elif info.dynamic and source_matches:
            if prepared.signature!=signature:atlas.dynamic_prepared_miss(entry,prepared,"signature")
            elif prepared.ground_version!=result.ground_version:atlas.dynamic_prepared_miss(entry,prepared,"ground_version")
            elif prepared.info!=info:atlas.dynamic_prepared_miss(entry,prepared,"source_info")
            elif prepared.basis!=basis:atlas.dynamic_prepared_miss(entry,prepared,"view_basis")
            elif prepared.screen_size!=world.get_viewport().get_visible_rect().size:atlas.dynamic_prepared_miss(entry,prepared,"screen_size")
            else:atlas.last_reconcile_phases.dynamic_prepared_accepted=atlas.last_reconcile_phases.get("dynamic_prepared_accepted",0)+1
        if not prepared.is_empty() and prepared.signature==signature and prepared.ground_version==result.ground_version \
                and source_matches and prepared.info==info \
                and prepared.basis==basis and prepared.screen_size==world.get_viewport().get_visible_rect().size:
            prepared.accepted=true
            result.prepared_specs=prepared.specs
            result.prepared_output=prepared.output
    return result

static func _spec(source: Dictionary, row: Dictionary) -> Dictionary:
    var entry: Dictionary=source.entry
    var id: int=entry.node.get_instance_id()
    var row_id: String=str(row.id) if entry.has("batch_rows") else "source"
    var prepared: Dictionary=source.get("prepared_specs",{}).get(row_id,{})
    if not prepared.is_empty() and (is_same(prepared.row,row) or prepared.row==row): return prepared
    return _snapshot_spec(source,row,id,entry.material.get_instance_id())

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
    atlas.dispose_receiver(receiver)

static func _bind(atlas, spec: Dictionary, position: Vector2i) -> Dictionary:
    var entry: Dictionary=spec.entry
    var index: int=entry.ground_indices[spec.row_id] if entry.has("batch_rows") else -1
    var visibility: float=entry.scenery_values[index] if index>=0 else float(entry.get("scenery_value",1.0))
    var receiver: Dictionary=atlas.receiver_index.get(spec.id,{})
    var prepared:Dictionary=atlas.prepared_source_bindings.get(spec.source_id,{})
    var candidate:Dictionary=prepared.get("receivers",{}).get(spec.id,{}) if prepared.get("accepted",false) else {}
    var prebound:bool=receiver.is_empty() and not candidate.is_empty() and candidate.index==index \
        and candidate.visibility==visibility and candidate.join_mask==spec.join_mask and candidate.source_geometry==spec.source_geometry
    var group_started:int=Time.get_ticks_usec()
    var group:Dictionary
    if prebound:
        atlas.last_reconcile_phases.prepared_receiver_fast_bindings=atlas.last_reconcile_phases.get("prepared_receiver_fast_bindings",0)+1
        # The source/version/view proof was checked before this transaction.
        # Register each exact staged material group once, not once per floor row.
        if not prepared.has("admitted_groups"):prepared.admitted_groups={}
        var key:Array=candidate.group.id
        group=prepared.admitted_groups.get(key,{})
        if group.is_empty():
            group=atlas._group(entry,spec.crop,visibility,spec.id,spec.info,spec.join_mask)
            prepared.admitted_groups[key]=group
    else:group=atlas._group(entry,spec.crop,visibility,spec.id,spec.info,spec.join_mask)
    atlas.last_reconcile_phases.ordinary_group_ms=atlas.last_reconcile_phases.get("ordinary_group_ms",0.0)+(Time.get_ticks_usec()-group_started)/1000.0
    var receiver_started:int=Time.get_ticks_usec()
    if not group.has("users"): group.users=0
    if receiver.is_empty():
        if prebound:
            receiver=candidate;prepared.receivers.erase(spec.id)
            atlas.last_reconcile_phases.prepared_receiver_bindings=atlas.last_reconcile_phases.get("prepared_receiver_bindings",0)+1
        else:receiver=atlas._make_receiver(spec,group,index)
        receiver.list_index=atlas.receivers.size(); atlas.receivers.append(receiver)
        receiver.dynamic=spec.info.dynamic
        var partition: Array=atlas.dynamic_receivers if receiver.dynamic else atlas.static_receivers
        receiver.partition_index=partition.size(); partition.append(receiver)
        atlas.receiver_index[spec.id]=receiver; group.users+=1
    elif not is_same(receiver.group,group):
        drop_group(atlas,receiver.group); group.users+=1
    atlas.last_reconcile_phases.ordinary_receiver_ms=atlas.last_reconcile_phases.get("ordinary_receiver_ms",0.0)+(Time.get_ticks_usec()-receiver_started)/1000.0
    var binding_started:int=Time.get_ticks_usec()
    receiver.group=group
    if not prebound:
        receiver.entry=entry; receiver.index=index; receiver.crop=spec.crop
        receiver.water=spec.info.water; receiver.source_material=spec.material_id; receiver.receiving_shader=spec.info.shader
        receiver.visibility=visibility; receiver.join_mask=spec.join_mask; receiver.row_id=spec.row_id; receiver.row=spec.row
        if receiver.get("source_geometry",[])!=spec.source_geometry or receiver.projection.is_empty():
            receiver.projection=[]
            if not receiver.dynamic: atlas.projection_dirty.append(receiver)
        receiver.source_geometry=spec.source_geometry; receiver.spec=spec
    atlas.set_receiver_material(receiver,group.material)
    if receiver.water and not receiver.projection.is_empty():
        receiver.group.material.set_shader_parameter("receiver_world_origin",receiver.world_origin)
    var region=Rect2(Vector2(position),Vector2(receiver.crop.pixels.size))
    if receiver.get("region",Rect2())!=region:
        atlas.set_receiver_region(receiver,region); receiver.region=region
    receiver.position=position
    var rank: int=group.rank%1024
    if receiver.get("rank",-1)!=rank: atlas.set_receiver_rank(receiver,rank); receiver.rank=rank
    var source: Dictionary=atlas.entry_specs[spec.source_id]
    source.receivers[spec.row_id]=receiver; source.by_row[spec.row_id]=spec
    if not receiver.dynamic: atlas.cull_dirty[receiver.id]=true
    atlas.last_reconcile_phases.ordinary_binding_ms=atlas.last_reconcile_phases.get("ordinary_binding_ms",0.0)+(Time.get_ticks_usec()-binding_started)/1000.0
    return receiver

static func _fallback(atlas, reason: String) -> bool:
    atlas.last_delta_fallback=reason
    return false

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
        atlas.viewport.size,atlas.next_source_order,atlas.delta_serial,atlas.light_cap,atlas.normals_visible]

static func begin_candidate(atlas,jobs:Array,removed:Dictionary,world,target_options:Dictionary={},base_world:Node=null)->Dictionary:
    # Capture only changed sources and their incident support cells. Retained
    # floor addresses belong to the atlas, never to mutable floor packets.
    var sparse:bool=true
    var work={"token":token(atlas),"world":world,"jobs":jobs,"removed_sources":removed.duplicate(),"source_patches":{},
        "removed":{},"specs":{},"floor_ids":{},"capture_ids":[],"capture_cells":[],
        "cursor":0,"stage":"removals" if not removed.is_empty() else "sources","capture_sparse":sparse,
        "removal_sources":removed.keys(),"removal_source_cursor":0,"removal_receivers":[],"removal_receiver_cursor":0,
        "needed_receivers":{},"needed_cells":{},"removed_ids":{},"next_order":atlas.next_source_order,"ranks":{},"bind_cursor":0,
        "ready_new":{},"ready_members":{},"ready_cull":{},"ready_style":{},"ready_pixels":0,
        "ready_list":[],"ready_static":[],"ready_dynamic":[],"ready_retained":[],"bulk_commands":[],"bulk_sources":{},"bulk_retained":[],"bulk_possible":true,
        "binding_sources":{},"obsolete_private_receivers":{},
        "source_sync_versions":{},"source_ground_versions":{},"projection_packets":{},"group_inputs":{},"private_groups":{},"private_draws":{},
        "white":atlas.white,"white_rid":atlas.white.get_rid(),"cull_sample":atlas.capture_projection(world),
        "output_region":atlas.get_script().prepare_output_region_values,
        "base_lists":[atlas.receivers.size(),atlas.static_receivers.size(),atlas.groups.size()],"group_proofs":{},
        "basis":world.camera.global_basis,"base_basis":world.camera.global_basis if base_world==null else base_world.camera.global_basis,
        "target_options":target_options,"screen":world.get_viewport().get_visible_rect().size,
        "passive":{"receiver_index":{},"support_owners":{},"published_supports":{},
            "entry_specs":{},"shelf_cursor":atlas.shelf_cursor,"viewport":{"size":atlas.viewport.size},"MAX_SIZE":atlas.MAX_SIZE}}
    return work

static func begin_global(atlas,world:Node,target_world:Node,entries:Array,options:Dictionary)->Dictionary:
    # Rotation and render options replace bindings inside the same atlas owner.
    # Source/light pages and the displayed viewport remain live until preflight.
    return {"phase":"sources","world":world,"target":target_world,"entries":entries.duplicate(),
        "options":options.duplicate(),"cursor":0,"jobs":[],"bindings":{},"prefix":{},"task":-1,
        "epoch":world.timeline.initialization_revision,"generation":world.world_generation,
        "token":token(atlas),"actor_members":_actor_members(world),"removed":{},"upserts":[],
        "old_sources":atlas.entry_specs.keys(),"planner":atlas.plan_layout}

static func _actor_members(world:Node)->Array:
    var result:Array=[]
    for entry in world.actor_entries:
        if entry.has("cell") and is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion():
            result.append([entry.node.get_instance_id(),entry.cell])
    return result

static func global_base_matches(atlas,work:Dictionary)->bool:
    var world:Node=work.world
    if work.epoch!=world.timeline.initialization_revision or work.generation!=world.world_generation:return false
    if work.token!=token(atlas) or work.actor_members!=_actor_members(world):return false
    if work.phase=="ready":return candidate_base_matches(atlas,work.prefix,world,work.target)
    return true

static func step_global(atlas,work:Dictionary,budget_usec:int)->void:
    var began:int=Time.get_ticks_usec()
    while Time.get_ticks_usec()-began<budget_usec:
        match work.phase:
            "sources":
                if work.cursor==work.entries.size():work.phase="removed";work.cursor=0;continue
                var entry:Dictionary=work.entries[work.cursor];work.cursor+=1
                if not entry.has("cell") or not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion():continue
                var snapshot:Dictionary=entry.duplicate()
                if entry.has("batch_rows"):
                    snapshot.ground_buffer=entry.ground_buffer.duplicate()
                    snapshot.scenery_values=entry.scenery_values.duplicate()
                    snapshot.ground_packets={}
                var prepared:Dictionary=atlas.prepare_source_binding(entry,snapshot,work.target,true,work.options)
                if prepared.is_empty():work.error="Global lighting preparation has no source bounds: "+str(entry.id);work.phase="failed";return
                prepared.receiver_parent=atlas.projection_root
                work.bindings[entry.node.get_instance_id()]=prepared
                work.jobs.append({"entry":entry,"rows":entry.batch_rows if entry.has("batch_rows") else [entry.placement],"packet":{},"prepared":prepared})
                work.upserts.append(entry)
                if entry.has("batch_rows"):work.phase="floor_packets";work.row_cursor=0
            "floor_packets":
                var job:Dictionary=work.jobs.back()
                if work.row_cursor==job.rows.size():work.phase="sources";continue
                var row:Dictionary=job.rows[work.row_cursor];work.row_cursor+=1
                var packet:Dictionary=job.entry.ground_packets[str(row.id)].duplicate()
                packet.data=packet.data.duplicate()
                job.prepared.snapshot.ground_packets[str(row.id)]=packet
            "removed":
                if work.cursor<work.old_sources.size():
                    work.removed[work.old_sources[work.cursor]]=true;work.cursor+=1;continue
                work.prefix=begin_candidate(atlas,work.jobs,work.removed,work.target,work.options,work.world)
                work.prefix.global=true;work.prefix.planner=work.planner
                work.phase="capture"
            "capture":
                if not capture_candidate(atlas,work.prefix,work.target):continue
                if work.prefix.has("error"):work.error=work.prefix.error;work.phase="failed";return
                work.phase="worker"
                work.task=WorkerThreadPool.add_task(compute_candidate.bind(work.prefix),false,"Plan global lighting bindings")
                return
            "worker":
                if not WorkerThreadPool.is_task_completed(work.task):return
                WorkerThreadPool.wait_for_task_completion(work.task);work.task=-1
                if work.prefix.has("error"):work.error=work.prefix.error;work.phase="failed";return
                work.phase="reserve"
            "reserve":
                if not reserve_candidate_capacity(atlas,work.prefix):work.error=work.prefix.error;work.phase="failed";return
                work.token=work.prefix.token
                work.phase="bind"
            "bind":
                if not prepare_candidate_binding(atlas,work.prefix,work.bindings):continue
                if work.prefix.has("error"):work.error=work.prefix.error;work.phase="failed";return
                work.phase="ready";return
            _:return

static func retire_global(work:Dictionary,record:Dictionary)->void:
    # Cancellation retains all borrowed resources until the pure worker exits.
    record.task=work.task
    var prefix:Dictionary=work.prefix
    if prefix.is_empty():prefix={"jobs":work.jobs}
    retire_candidate(record,prefix,work.bindings,true)

static func publish_global(atlas,work:Dictionary,cleanup:Dictionary)->void:
    for binding in work.bindings.values():atlas.adopt_source_binding(binding)
    work.prefix.admitted=true
    atlas.prepared_delta=work.prefix
    cleanup.blocked=true;atlas.prepared_cleanup=cleanup
    work.bindings={};work.prefix={}

static func _need_support(atlas,work:Dictionary,row:Dictionary)->void:
    if not GroundReceiving.eligible(row):return
    var cell=Vector2(row.position[0],row.position[1])
    _need_cell(atlas,work,cell)
    for direction in GroundReceiving.DIRECTIONS:_need_cell(atlas,work,cell+direction)

static func _need_cell(atlas,work:Dictionary,cell:Vector2)->void:
    # Each support cell is captured once, with the source that first needs it,
    # instead of in a separate pass after the last source. The capture token
    # proves the atlas did not change in between; cell order is unchanged.
    if work.needed_cells.has(cell):return
    work.needed_cells[cell]=true
    var owners:Dictionary=atlas.support_owners.get(cell,{})
    work.passive.support_owners[cell]=owners.duplicate()
    if atlas.published_supports.has(cell):work.passive.published_supports[cell]=atlas.published_supports[cell]
    for id in owners:work.needed_receivers[id]=true

static func _need_receiver(atlas,work:Dictionary,id:String)->void:
    if not atlas.receiver_index.has(id):return
    work.needed_receivers[id]=true
    _need_support(atlas,work,atlas.receiver_index[id].row)

static func _capture_removal(atlas,work:Dictionary,id:String)->void:
    if work.capture_sparse:
        work.removed_ids[id]=true
        _need_receiver(atlas,work,id)
    else:work.removed[id]=work.passive.receiver_index[id]

static func _capture_receiver(atlas,work:Dictionary,id:String)->void:
    var receiver:Dictionary=atlas.receiver_index[id]
    var spec:Dictionary=receiver.spec.duplicate()
    var index:int=row_index(receiver)
    spec.row=receiver.row;spec.row_id=receiver.row_id;spec.row_rank=maxi(index,0)
    if not work.source_ground_versions.has(spec.source_id):
        work.source_ground_versions[spec.source_id]=receiver.entry.get("ground_version",0)
    if not spec.info.dynamic and not work.group_inputs.has(spec.source_id):
        work.group_inputs[spec.source_id]=atlas.capture_group_input(receiver.entry,spec.info,spec.crop,
            Basis(work.basis.x,-work.basis.y,work.basis.z).transposed(),work.screen)
    work.passive.receiver_index[id]={"id":id,"row":receiver.row,"row_id":receiver.row_id,"index":index,
        "join_mask":receiver.join_mask,"crop":receiver.crop,"position":receiver.position,"group_id":receiver.group.id,
        "visibility":receiver.visibility,"spec":spec,"receiver":receiver,"group":receiver.group,
        "binding_revision":receiver.entry.get("source_binding_revision",0),
        "source_visible":receiver.entry.node.is_visible_in_tree()}
    work.passive.entry_specs[spec.source_id]={"order":atlas.entry_specs[spec.source_id].order}
    if work.removed_sources.has(spec.source_id) or work.removed_ids.has(id):work.removed[id]=work.passive.receiver_index[id]

static func _capture_groups(atlas,work:Dictionary)->void:
    # Only groups incident to changed sources/support receivers can be consumed
    # by this candidate. Unrelated source materials are not a preparation input.
    if work.get("canonical_capture",false):
        var ordered:Dictionary={}
        for job in work.jobs:ordered[job.source_id]=work.source_patches[job.source_id]
        work.source_patches=ordered
    var sources:Dictionary={}
    for id in work.source_patches:sources[id]=true
    for receiver in work.passive.receiver_index.values():sources[receiver.spec.source_id]=true
    for id in sources:
        for key in atlas.source_groups.get(id,{}):
            var group:Dictionary=atlas.source_groups[id][key]
            work.ranks[key]=group.rank
            work.group_proofs[key]=[group,group.material,group.material.shader,group.crop,group.rank,group.get("users",0),group.material.get_rid(),group.version]
            work.source_sync_versions[id]=mini(int(work.source_sync_versions.get(id,group.version)),int(group.version))
    work.stage="captured"

static func _capture_source(atlas,work:Dictionary,world)->bool:
    var job:Dictionary=work.jobs[work.cursor];work.cursor+=1
    if work.source_patches.has(job.entry.node.get_instance_id()):return false
    return _capture_source_value(atlas,work,world,job)

static func capture_source_job(atlas,work:Dictionary,world,job:Dictionary)->bool:
    # World preparation may hand off ready operands before its scene adoption
    # finishes. This is the same source owner/capture, not another work queue.
    if work.token!=token(atlas):work.error="atlas_changed_during_capture";return false
    var id:int=job.entry.node.get_instance_id()
    if work.source_patches.has(id):return true
    var selected:Dictionary=job.duplicate()
    work.jobs.append(selected)
    _capture_source_value(atlas,work,world,selected)
    return not work.has("error")

static func seal_candidate_jobs(atlas,work:Dictionary,canonical_jobs:Array)->void:
    # Arrival order must never become painter/group order. Actual source IDs
    # remain unchanged; only this prefix's private job shells are reordered.
    var jobs:Array=[];var order:int=int(work.token[5])
    for original in canonical_jobs:
        var job:Dictionary=original.duplicate()
        var id:int=job.entry.node.get_instance_id()
        var before:Dictionary=atlas.entry_specs.get(id,{})
        job.source_id=id;job.source_order=order if before.is_empty() else before.order
        if before.is_empty():order+=1
        if work.source_patches.has(id):work.source_patches[id].order=job.source_order
        jobs.append(job)
    work.jobs=jobs;work.cursor=0;work.next_order=order;work.canonical_capture=true

static func private_source_capture(prepared:Dictionary)->Dictionary:
    # The resource producer owns every value here. This is a separate outer
    # directory from prepared.source: the displayed atlas may retain it after
    # the constructor shell retires. Native identity is linked on admission.
    var snapshot:Dictionary=prepared.snapshot
    var source:Dictionary=prepared.source.duplicate()
    source.complete=true
    source.prepared_specs=prepared.specs;source.prepared_output=prepared.output
    source.private_receivers=prepared.receivers.duplicate()
    source.private_specs=prepared.specs.duplicate();source.private_groups=prepared.groups.duplicate()
    source.proof={"cell":snapshot.cell,"material":snapshot.material,"material_id":snapshot.material.get_instance_id(),
        "version":snapshot.source_version,"binding_revision":snapshot.source_binding_revision,
        "base_ground_version":0,"ground_version":0,"scenery":snapshot.get("scenery_value",1.0),
        "geometry":source.geometry,"info":source.info,"record_path":snapshot.get("record",{}).get("path",""),
        "record_rect":snapshot.get("record",{}).get("rect",[]).duplicate()}
    source.rows=[snapshot.placement];source.snapshot=snapshot;source.is_floor=false
    return source

static func _capture_source_value(atlas,work:Dictionary,world,job:Dictionary)->bool:
    var entry:Dictionary=job.entry
    var prepared:Dictionary=job.get("prepared",{})
    var id:int=entry.node.get_instance_id()
    # Actual new native identity proves there is no retained atlas base to
    # snapshot. Its private constructor already completed the passive source.
    if prepared.has("capture") and not atlas.entry_specs.has(id):
        var source:Dictionary=prepared.capture
        if (prepared.binding_revision!=entry.source_binding_revision
            or source.info.light_cap!=work.target_options.get("light_cap",atlas.light_cap)
            or source.info.normals_visible!=work.target_options.get("normals_visible",atlas.normals_visible)
            or prepared.basis!=Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed()
            or prepared.screen_size!=world.get_viewport().get_visible_rect().size):
            work.error="source_changed_before_prefix_capture";return true
        prepared.erase("capture")
        source.source_id=id;source.order=job.get("source_order",work.next_order)
        if not job.has("source_order"):work.next_order+=1
        source.future_visible=job.get("source_visible",entry.node.visible)
        job.source_id=id
        work.binding_sources[id]=prepared;work.source_ground_versions[id]=0
        if not source.info.dynamic:
            work.group_inputs[id]=prepared.group_input
            # The resource producer already built this source's single-row
            # receiving material; the planner adopts it when the key matches.
            if prepared.has("static_group"):
                var group:Dictionary=prepared.static_group;prepared.erase("static_group")
                work.private_groups[id]={group.id:group}
        if work.capture_sparse:
            _need_receiver(atlas,work,str(id)+":source")
            _need_support(atlas,work,source.rows[0])
        work.source_patches[id]=source
        return false
    var snapshot:Dictionary=prepared.snapshot if not prepared.is_empty() else entry.duplicate()
    # New private static Nodes already carry the exact source operands produced
    # before they existed. Re-reading those Nodes here merely reconstructed the
    # same crop/signature/geometry and copied the same uniform maps again.
    var direct:bool=prepared.get("private_static",false)
    var source:Dictionary=prepared.source.duplicate() if direct else _source(atlas,entry,world,snapshot,work.target_options)
    if source.crop.is_empty():work.error="missing_crop";return true
    if not prepared.is_empty() and (prepared.get("binding_revision",0)!=entry.get("source_binding_revision",0)
        or (not direct and (prepared.signature!=source.signature or prepared.info!=source.info))
        or (direct and (source.info.light_cap!=work.target_options.get("light_cap",atlas.light_cap) or source.info.normals_visible!=work.target_options.get("normals_visible",atlas.normals_visible)))
        or prepared.basis!=Basis(world.camera.global_basis.x,-world.camera.global_basis.y,world.camera.global_basis.z).transposed()
        or prepared.screen_size!=world.get_viewport().get_visible_rect().size):
        work.error="source_changed_before_prefix_capture";return true
    job.source_id=id
    source.source_id=id;source.is_floor=entry.has("batch_rows")
    # The candidate lends this exclusive shell to its planner until completion.
    # Its entry/Node remains opaque; only private directories/output may change.
    if not prepared.is_empty():source.prepared_binding=prepared
    work.source_ground_versions[id]=snapshot.get("ground_version",0)
    if not source.info.dynamic:
        work.group_inputs[id]=prepared.group_input if not prepared.is_empty() else atlas.capture_group_input(entry,source.info,source.crop,
            Basis(work.basis.x,-work.basis.y,work.basis.z).transposed(),work.screen)
    var before:Dictionary=atlas.entry_specs.get(id,{})
    if job.has("source_order"):source.order=job.source_order
    else:
        source.order=work.next_order if before.is_empty() else before.order
        if before.is_empty():work.next_order+=1
    source.receivers=before.get("receivers",{}).duplicate();source.by_row=before.get("by_row",{}).duplicate()
    source.packets=before.get("packets",{}).duplicate()
    source.complete=before.is_empty() or not source.same or work.removed_sources.has(id)
    if source.complete:
        for old_id in before.get("receivers",{}):
            var receiver_id:String=before.receivers[old_id].id
            _capture_removal(atlas,work,receiver_id)
        source.receivers={};source.by_row={};source.packets={}
    elif entry.has("batch_rows"):
        for row_id in job.packet.get("geometry_changes",{}).get("removed",[]):
            if before.receivers.has(str(row_id)):
                var receiver_id:String=before.receivers[str(row_id)].id
                _capture_removal(atlas,work,receiver_id)
    source.prepared_specs=prepared.get("specs",{})
    source.prepared_output=prepared.get("output",{})
    if source.info.dynamic and not prepared.is_empty():
        atlas._prepare_source_group(prepared,float(snapshot.get("scenery_value",1.0)),"",0)
    source.private_receivers=prepared.get("receivers",{}).duplicate()
    source.private_specs=source.prepared_specs.duplicate()
    source.private_groups=prepared.get("groups",{}).duplicate()
    source.future_visible=job.get("source_visible",entry.node.visible)
    source.proof={"entry":entry,"cell":entry.cell,"material":entry.material,"material_id":entry.material.get_instance_id(),"version":entry.get("source_version",0),"binding_revision":entry.get("source_binding_revision",0),
        "base_ground_version":entry.get("ground_version",0),"ground_version":snapshot.get("ground_version",0),"scenery":snapshot.ground_visibility.duplicate() if snapshot.has("ground_visibility") else snapshot.scenery_values.duplicate() if snapshot.has("scenery_values") else snapshot.get("scenery_value",1.0),
        "geometry":source.geometry,"info":source.info,"record_path":entry.get("record",{}).get("path",""),
        "record_rect":entry.get("record",{}).get("rect",[]).duplicate()}
    source.rows=snapshot.batch_rows if source.complete and entry.has("batch_rows") else [snapshot.placement] if source.complete else job.rows
    source.snapshot=snapshot
    if work.capture_sparse:
        if entry.has("batch_rows") and not before.is_empty():source.addresses=before.get("addresses",{})
        for selected in source.rows:
            var row:Dictionary=selected if selected is Dictionary else sampled_row(snapshot,str(selected))
            var receiver_id:String=str(id)+":"+(str(row.id) if entry.has("batch_rows") else "source")
            _need_receiver(atlas,work,receiver_id)
            _need_support(atlas,work,row)
    work.source_patches[id]=source
    if entry.has("batch_rows"):work.floor_ids[id]=true
    return false

static func capture_candidate(atlas,work:Dictionary,world)->bool:
    if work.token!=token(atlas):work.error="atlas_changed_during_capture";return true
    if work.stage=="removals":
        if work.removal_receiver_cursor<work.removal_receivers.size():
            _capture_removal(atlas,work,work.removal_receivers[work.removal_receiver_cursor].id)
            work.removal_receiver_cursor+=1;return false
        if work.removal_source_cursor<work.removal_sources.size():
            var id:int=work.removal_sources[work.removal_source_cursor];work.removal_source_cursor+=1
            work.removal_receivers=atlas.entry_specs.get(id,{}).get("receivers",{}).values()
            work.removal_receiver_cursor=0;return false
        work.removal_sources=[];work.removal_receivers=[];work.stage="sources"
    if work.capture_sparse:
        if work.stage=="sources":
            if work.cursor<work.jobs.size():return _capture_source(atlas,work,world)
            work.capture_cells=work.needed_cells.keys();work.cursor=0;work.stage="supports"
            return false
        if work.stage=="supports":
            # Every needed cell was captured with its first source (_need_cell).
            # Preserve the full snapshot's exact removal/reservation traversal.
            # Native array searches/sort avoid a GDScript walk of every receiver.
            var positions=PackedInt64Array();var ids={}
            for id in work.needed_receivers:
                var position:int=atlas.receiver_index[id].list_index
                if position>=0:positions.append(position);ids[position]=id
            positions.sort();work.capture_ids=[]
            for position in positions:work.capture_ids.append(ids[position])
            work.cursor=0;work.stage="receivers"
            return false
        if work.stage=="receivers":
            if work.cursor<work.capture_ids.size():
                var id:String=work.capture_ids[work.cursor];work.cursor+=1
                _capture_receiver(atlas,work,id)
                return false
            _capture_groups(atlas,work)
            return true
        return true
    # Missing/stale floor-address proof retains the original full snapshot.
    if work.stage=="receivers":
        if work.cursor==work.capture_ids.size():work.cursor=0;work.stage="supports";return false
        var id:String=work.capture_ids[work.cursor];work.cursor+=1
        _capture_receiver(atlas,work,id)
        return false
    if work.stage=="supports":
        if work.cursor==work.capture_cells.size():work.cursor=0;work.stage="sources";return false
        var cell:Vector2=work.capture_cells[work.cursor];work.cursor+=1
        work.passive.support_owners[cell]=atlas.support_owners[cell].duplicate()
        return false
    if work.stage=="sources":
        if work.cursor==work.jobs.size():_capture_groups(atlas,work);return true
        return _capture_source(atlas,work,world)
    return true

static func compute_candidate(work:Dictionary)->void:
    var started:int=Time.get_ticks_usec()
    work.complete=false
    for id in work.source_patches:
        var source:Dictionary=work.source_patches[id]
        var snapshot:Dictionary=source.snapshot
        for selected in source.rows:
            var row:Dictionary=selected if selected is Dictionary else sampled_row(snapshot,str(selected))
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
    work.spec_worker_ms=(Time.get_ticks_usec()-started)/1000.0
    var source_specs:int=work.specs.size()
    work.plan=_plan(work.passive,work.source_patches,work.removed,work.specs)
    var counts:Dictionary={"floor_rows":0,"single":0,"dynamic":0,"support_neighbours":work.specs.size()-source_specs}
    for source in work.source_patches.values():
        if source.info.dynamic:counts.dynamic+=source.rows.size()
        elif source.is_floor:counts.floor_rows+=source.rows.size()
        else:counts.single+=source.rows.size()
    work.spec_counts=counts
    if work.get("global",false) and work.plan.get("error","") in ["changed_crop","append_overflow"]:
        # Preserve addresses when the normal planner fits. A real rebase uses
        # the original complete planner and exact future source/row order.
        var minimum=Vector2i(work.screen.x,maxi(work.screen.y,work.passive.viewport.size.y))
        var complete:Dictionary=work.planner.call(work.specs.values(),minimum)
        if not complete.ok:work.plan={"error":complete.error}
        else:
            var order:int=0
            for source in work.source_patches.values():source.order=order;order+=1
            var empty={"receiver_index":{},"support_owners":{},"published_supports":{},"entry_specs":{},
                "shelf_cursor":Vector3i(1,1,0),"viewport":{"size":complete.size},"MAX_SIZE":work.passive.MAX_SIZE}
            work.plan=_plan(empty,work.source_patches,{},work.specs)
            if not work.plan.has("error"):
                for cell in work.passive.support_owners:
                    if not work.plan.owners.has(cell):work.plan.owners[cell]={}
                work.plan.positions=complete.positions;work.plan.cursor=complete.cursor
                work.plan.next_height=complete.size.y;work.plan.growing=complete.size!=work.passive.viewport.size
                work.rebased=true
    if not work.plan.has("error"):
        if work.screen.x>work.passive.MAX_SIZE or work.screen.y>work.passive.MAX_SIZE:work.plan={"error":"screen_exceeds_atlas"}
        else:
            while work.plan.next_height<work.screen.y:work.plan.next_height=mini(work.passive.MAX_SIZE,work.plan.next_height*2)
            work.plan.growing=work.plan.next_height!=work.passive.viewport.size.y
    if work.plan.has("error"):
        work.error=work.plan.error;work.worker_ms=(Time.get_ticks_usec()-started)/1000.0;return
    var addresses_started:int=Time.get_ticks_usec()
    if not _candidate_addresses(work):
        work.worker_ms=(Time.get_ticks_usec()-started)/1000.0;return
    work.address_worker_ms=(Time.get_ticks_usec()-addresses_started)/1000.0
    # Native source/mesh values were captured once per source. Project final
    # static rows here, after support expansion, without reading live Nodes or
    # Resources. Scene binding consumes these numeric operands exactly once.
    var projection_started:int=Time.get_ticks_usec()
    var projection_basis:Basis=Basis(work.basis.x,-work.basis.y,work.basis.z).transposed()
    for id in work.plan.specs:
        var spec:Dictionary=work.plan.specs[id]
        if spec.info.dynamic:continue
        work.projection_packets[id]=_projection_packet(spec.source_geometry,spec.crop,projection_basis,
            int(work.source_ground_versions.get(spec.source_id,0)))
    work.projection_worker_ms=(Time.get_ticks_usec()-projection_started)/1000.0
    work.worker_ms=(Time.get_ticks_usec()-started)/1000.0
    work.bind_ids=work.plan.specs.keys();work.bind_cursor=0
    work.output_ids=[];work.output_cursor=0
    work.outputs={};work.source_proofs={}
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
    work.bulk_base_lists=[work.base_lists[0]-work.removed.size(),work.base_lists[1]-removed_static,
        work.base_lists[0]-work.base_lists[1]-(work.removed.size()-removed_static)]
    work.group_users={};work.planned_groups={}
    for key in work.group_proofs:
        var count:int=work.group_proofs[key][5]-int(removed_groups.get(key,0))
        if count>0:
            work.group_users[key]=count;work.planned_groups[key]=work.group_proofs[key][0]
    work.rank_count=work.base_lists[2]-work.dropped_groups.size();work.bulk_reason=""
    _prepare_group_resources(work)
    var output_started:int=Time.get_ticks_usec();var output_count:int=0
    var target:Vector2=Vector2(work.passive.MAX_SIZE,work.plan.next_height)
    var region_count:int=0
    for id in work.source_patches:
        var source:Dictionary=work.source_patches[id]
        var output:Dictionary=source.get("prepared_output",{})
        if output.has("input"):realize_output(output);output_count+=1
        if not output.is_empty():
            var position:Vector2i=Vector2i.ZERO
            if not source.is_floor:
                var row_id:String=str(source.source_id)+":source"
                position=work.plan.positions[row_id] if work.plan.positions.has(row_id) else source.receivers["source"].position
            work.output_region.call(output,source.is_floor,source.crop,position,target)
            region_count+=1
            source.output=output.received_material
        if not source.info.dynamic and not source.info.water and output.has("sample"):
            var sample:Dictionary=output.sample
            source.synced=true
            source.sync_version=mini(int(sample.version),int(work.source_sync_versions.get(id,sample.version)))
            source.sync_highlighted=sample.highlighted;source.sync_seconds=sample.seconds;source.sync_visibility=sample.visibility
            source.sync_material=sample.material;source.sync_shader=sample.shader;source.sync_binding_revision=sample.binding_revision
        work.outputs[id]=output;work.source_proofs[id]=source.proof
        if output.get("private_node",false) or not work.binding_sources.has(id):work.output_ids.append(id)
        # Fallback source construction still needs its captured snapshot on
        # main. Every captured shell already owns the same snapshot privately.
        if work.binding_sources.has(id):_finish_source_capture(source)
    work.worker_output_regions=region_count
    work.output_worker_ms=(Time.get_ticks_usec()-output_started)/1000.0;work.worker_output_materials=output_count
    work.worker_ms=(Time.get_ticks_usec()-started)/1000.0
    work.complete=true

static func _prepare_group_resources(work:Dictionary)->void:
    var started:int=Time.get_ticks_usec();var counts:Dictionary=work.group_users.duplicate()
    var created:int=0;var prepared_groups:int=0;var uniforms:int=0;var rid_usec:int=0
    var ranks:Dictionary=work.ranks.duplicate();var rank_count:int=work.rank_count
    var selected_groups:Dictionary=work.planned_groups.duplicate();var material_rids:Dictionary={}
    var materials:Dictionary={};var versions:Dictionary={};var introductions:Dictionary={}
    for key in selected_groups:
        material_rids[key]=work.group_proofs[key][6];materials[key]=work.group_proofs[key][1];versions[key]=work.group_proofs[key][7]
    var canvas_usec:int=0;var record_usec:int=0
    work.static_batch=null
    work.dynamic_bind_ids=[]
    for id in work.bind_ids:
        var spec:Dictionary=work.plan.specs[id]
        var source:Dictionary=work.source_patches.get(spec.source_id,{})
        var previous:Dictionary=work.passive.receiver_index.get(id,{}) if not work.removed.has(id) else {}
        var visibility:float=sampled_visibility(source.snapshot,spec.row_id,spec.row_rank) if not source.is_empty() else float(previous.visibility)
        var key:Array=[spec.material_id,visibility,id if spec.info.water else "",spec.join_mask]
        if not counts.has(key):
            counts[key]=0
            ranks[key]=rank_count;rank_count+=1
            if not spec.info.dynamic:
                if not work.private_groups.has(spec.source_id):work.private_groups[spec.source_id]={}
                var groups:Dictionary=work.private_groups[spec.source_id]
                if not groups.has(key):
                    var input:Dictionary=work.group_inputs[spec.source_id]
                    var group:Dictionary=static_group(input,key,visibility,spec.join_mask,
                        work.projection_packets[id].world_origin if input.info.water else null)
                    uniforms+=input.parameters.size()
                    # Only this newly constructed private resource is realized.
                    # The scene owner later attaches its ready native RID; no
                    # displayed material/Node/texture is mutated by the worker.
                    var rid_started:int=Time.get_ticks_usec()
                    group.material.get_rid()
                    rid_usec+=Time.get_ticks_usec()-rid_started
                    groups[key]=group;created+=1
                else:prepared_groups+=1
                selected_groups[key]=groups[key]
                material_rids[key]=groups[key].material.get_rid()
                materials[key]=groups[key].material;versions[key]=groups[key].version
                groups[key].rank=int(ranks[key])
            else:
                var group:Dictionary=source.get("private_groups",{}).get(key,{})
                if group.is_empty():work.error="unprepared_dynamic_group:"+id;return
                selected_groups[key]=group;materials[key]=group.material;versions[key]=group.version
                group.rank=int(ranks[key])
        var selected:Dictionary=selected_groups[key]
        var draw:CanvasDraw=null
        if not spec.info.dynamic:
            var canvas_started:int=Time.get_ticks_usec()
            if work.static_batch==null:work.static_batch=CanvasBatch.new()
            draw=CanvasDraw.new()
            draw.initialize(work.white,work.white_rid,materials[key],material_rids[key],work.projection_packets[id].transform,
                Rect2(Vector2(work.plan.positions[id]),Vector2(spec.crop.pixels.size)),int(ranks[key])%1024)
            draw.attach_private(work.static_batch)
            work.private_draws[id]=draw
            canvas_usec+=Time.get_ticks_usec()-canvas_started
        var previous_key:Array=previous.group_id if not previous.is_empty() else []
        if previous.is_empty() or previous_key!=key:
            counts[key]+=1
            if not previous.is_empty():
                counts[previous_key]-=1
                if counts[previous_key]==0:
                    counts.erase(previous_key);selected_groups.erase(previous_key);material_rids.erase(previous_key)
                    materials.erase(previous_key);versions.erase(previous_key)
                    ranks.erase(previous_key);rank_count-=1
        var record_started:int=Time.get_ticks_usec()
        work.source_sync_versions[spec.source_id]=mini(int(work.source_sync_versions.get(spec.source_id,versions[key])),int(versions[key]))
        _prepare_receiver_record(work,spec,source,previous,selected,materials[key],visibility,int(ranks[key])%1024,draw,introductions)
        if spec.info.dynamic:work.dynamic_bind_ids.append(id)
        record_usec+=Time.get_ticks_usec()-record_started
    work.group_worker_ms=(Time.get_ticks_usec()-started)/1000.0
    work.group_worker_rid_ms=rid_usec/1000.0
    work.worker_group_materials=created+prepared_groups;work.worker_group_uniforms=uniforms
    work.prepared_group_materials=prepared_groups
    work.canvas_worker_ms=canvas_usec/1000.0;work.worker_canvas_items=work.private_draws.size()
    work.receiver_record_worker_ms=record_usec/1000.0
    work.source_bind_ids=[];work.source_bind_cursor=0
    work.worker_source_directories=0
    for id in work.bulk_sources:
        var prepared:Dictionary=work.binding_sources.get(id,work.source_patches.get(id,{}).get("prepared_binding",{}))
        if prepared.is_empty():work.source_bind_ids.append(id)
        else:
            _finalize_candidate_source(work,id,prepared)
            work.worker_source_directories+=1
    work.bindings_transferred=false
    work.dynamic_bind_cursor=0;work.static_bindings_ready=false

static func _prepare_receiver_record(work:Dictionary,spec:Dictionary,source:Dictionary,previous:Dictionary,
        selected:Dictionary,material:ShaderMaterial,visibility:float,rank:int,draw:CanvasDraw,introductions:Dictionary)->void:
    # All per-row records, list offsets and ordered group leases belong to this
    # private prefix. Live entry/group/receiver references are opaque operands;
    # their current fields are checked only by the existing publication proof.
    var id:String=spec.id;var key:Array=[spec.material_id,visibility,id if spec.info.water else "",spec.join_mask]
    var index:int=spec.row_rank if (source.snapshot.has("batch_rows") if not source.is_empty() else previous.index>=0) else -1
    var receiver:Dictionary={"id":id,"entry":spec.entry,"index":index,"group":selected,
        "crop":spec.crop,"position":work.plan.positions[id],"projection":[],"visibility":visibility,"bounds":Rect2(),
        "row_id":spec.row_id,"row":spec.row,"water":spec.info.water,"source_geometry":spec.source_geometry,
        "source_material":spec.material_id,"receiving_shader":spec.info.shader,"join_mask":spec.join_mask,
        "dynamic":spec.info.dynamic,"spec":spec,"region":Rect2(Vector2(work.plan.positions[id]),Vector2(spec.crop.pixels.size)),"rank":rank}
    if not spec.info.dynamic:
        var projection:Dictionary=work.projection_packets[id]
        receiver.draw=draw;receiver.projection=projection.identity
        receiver.world_origin=projection.world_origin;receiver.bounds=projection.bounds
    if not work.bulk_sources.has(spec.source_id):
        var old:Dictionary=source.get("private_receivers",{})
        work.bulk_sources[spec.source_id]={"prepared":{},"first_spec":spec,"binding_receivers":old.duplicate(),
            "binding_specs":source.get("private_specs",{}).duplicate(),"remaining":old.duplicate(),
            "source_visible":source.future_visible if not source.is_empty() else previous.source_visible,
            "cull_all":{},"cull_shown":{},"cull_owner":{"frame":-1},"created_rows":0,"static_rows":0}
    var owner:Dictionary=work.bulk_sources[spec.source_id]
    if owner.binding_receivers.has(id):work.obsolete_private_receivers[id]=owner.binding_receivers[id]
    owner.binding_receivers[id]=receiver;owner.binding_specs[spec.row_id]=spec;owner.remaining.erase(id)
    owner.created_rows+=1
    if not source.is_empty():source.receivers[spec.row_id]=receiver;source.by_row[spec.row_id]=spec
    if not receiver.dynamic:
        owner.static_rows+=1;receiver.cull_owner=owner.cull_owner
        receiver.cull_shown=owner.source_visible and (work.cull_sample.transform*receiver.bounds).intersects(work.cull_sample.screen)
        draw.set_visible(receiver.cull_shown)
        owner.cull_all[id]=true
        if receiver.cull_shown:owner.cull_shown[id]=true
    work.ready_style[id]=receiver
    var private_group:bool=not work.group_proofs.has(key) or not is_same(selected,work.group_proofs[key][0])
    if not previous.is_empty():
        if private_group and not introductions.has(key):introductions[key]=true;selected.prepared_introduction=-1
        work.bulk_retained.append([previous.receiver,previous.group,previous.index,previous.visibility,previous.binding_revision])
        work.bulk_commands.append({"replace":previous.receiver,"receiver":receiver,"group":selected})
        work.ready_retained.append(receiver)
        return
    work.ready_new[id]=receiver;work.ready_members[id]=spec.crop;work.ready_cull[id]=true
    work.ready_pixels+=spec.crop.pixels.size.x*spec.crop.pixels.size.y
    if work.bulk_commands.is_empty() or not work.bulk_commands.back().has("groups"):
        work.bulk_commands.append({"groups":{},"group_spans":[]})
    var command:Dictionary=work.bulk_commands.back();var run:Dictionary=command.groups
    if not run.has(key):
        var registration:bool=private_group and not introductions.has(key)
        run[key]={"group":selected,"spec":spec,"visibility":visibility,"rows":[],"rank":rank,
            "material":material,"prepared_registration":registration}
        if command.group_spans.is_empty() or command.group_spans.back().prepared!=registration:
            command.group_spans.append({"prepared":registration,"groups":{},"sources":{},"records":[]})
        var span:Dictionary=command.group_spans.back()
        if registration:
            introductions[key]=true;selected.prepared_introduction=work.bulk_commands.size()-1
            selected.entry=spec.entry;selected.source_id=spec.source_id;selected.users=0
            span.groups[key]=selected
            if not span.sources.has(spec.source_id):span.sources[spec.source_id]={}
            span.sources[spec.source_id][key]=selected
        else:span.records.append(run[key])
    var record:Dictionary=run[key];record.rows.append(receiver)
    if record.prepared_registration:record.group.users+=1
    receiver.list_index=work.bulk_base_lists[0]+work.ready_list.size()
    var partition:Array=work.ready_dynamic if receiver.dynamic else work.ready_static
    receiver.partition_index=work.bulk_base_lists[2 if receiver.dynamic else 1]+partition.size()
    partition.append(receiver);work.ready_list.append(receiver)

static func _projection_packet(geometry:Array,crop:Dictionary,basis:Basis,ground_version:int)->Dictionary:
    # Same arithmetic and PackedFloat32 transform values as Atlas._project_entry.
    var source:Array=geometry[0]
    var global_transform:Transform3D=source[0]
    var size:Vector2=source[1];var center:Vector3=source[2]
    var data:PackedFloat32Array=geometry[2]
    var transform:Transform3D=global_transform
    var identity:Array=[global_transform,size,center]
    if not data.is_empty():
        transform=global_transform*Transform3D(Basis(Vector3(data[0],data[4],data[8]),Vector3(data[1],data[5],data[9]),
            Vector3(data[2],data[6],data[10])),Vector3(data[3],data[7],data[11]))
        identity=[ground_version,global_transform,size,center]
    var local:Vector3=center+Vector3(-size.x*.5,size.y*.5,0)
    var projected_origin:Vector3=basis*(transform*local)
    var projected_x:Vector3=basis*(transform.basis*Vector3(size.x,0,0))
    var projected_y:Vector3=basis*(transform.basis*Vector3(0,-size.y,0))
    var origin:Vector2=Vector2(projected_origin.x,projected_origin.y)
    var axis_x:Vector2=Vector2(projected_x.x,projected_x.y)
    var axis_y:Vector2=Vector2(projected_y.x,projected_y.y)
    var uv:Vector4=crop.uv
    origin+=axis_x*uv.x+axis_y*uv.y;axis_x*=uv.z;axis_y*=uv.w
    return {"identity":identity,"transform":Transform2D(axis_x/crop.pixels.size.x,axis_y/crop.pixels.size.y,origin),
        "world_origin":transform.origin,
        "bounds":Rect2(origin,Vector2.ZERO).expand(origin+axis_x).expand(origin+axis_y).expand(origin+axis_x+axis_y)}

static func reserve_candidate_capacity(atlas,work:Dictionary)->bool:
    # A completed append plan already owns exact integer addresses. Reserve
    # only its physical height before final output regions are bound; no future
    # receiver, source, shelf position or event becomes displayed by this step.
    if not work.plan.growing or work.get("rebased",false):return true
    if work.token!=token(atlas):work.error="atlas_changed_before_capacity_reservation";return false
    var height:int=work.plan.next_height
    atlas.viewport.size=Vector2i(atlas.MAX_SIZE,height)
    atlas.repack_count+=1
    atlas._refresh_normalized_addresses()
    work.token=token(atlas)
    work.passive.viewport.size=atlas.viewport.size
    work.plan.growing=false
    work.capacity_reserved=true
    return true

static func _candidate_addresses(work:Dictionary)->bool:
    for id in work.floor_ids:
        var source:Dictionary=work.source_patches[id]
        var snapshot:Dictionary=source.snapshot
        if snapshot.get("sparse_ground",false):continue
        var buffer:PackedFloat32Array=snapshot.ground_buffer.duplicate()
        var packets:Dictionary=snapshot.ground_packets.duplicate()
        var snapshots:Dictionary=source.packets.duplicate()
        var addresses:Dictionary={}
        for row in snapshot.batch_rows:
            var row_id:String=str(row.id);var receiver_id:String=str(id)+":"+row_id
            var pixel:Vector2i
            if work.plan.positions.has(receiver_id):pixel=work.plan.positions[receiver_id]
            elif work.passive.receiver_index.has(receiver_id):pixel=work.passive.receiver_index[receiver_id].position
            elif source.addresses.has(row_id):
                pixel=source.addresses[row_id].position
            else:work.error="unreserved_floor_row:"+receiver_id;return false
            var index:int=snapshot.ground_indices[row_id];var offset:int=index*20
            var x:int=pixel.x%1024;var y:int=pixel.y%1024;var high:int=(pixel.x/1024)+8*(pixel.y/1024)
            buffer[offset+17]=x;buffer[offset+18]=y;buffer[offset+19]=high
            var packet:Dictionary=packets[row_id].duplicate();var data:PackedFloat32Array=packet.data.duplicate()
            data[17]=x;data[18]=y;data[19]=high;packet.data=data;packets[row_id]=packet
            var previous:Dictionary=snapshots.get(row_id,{}).duplicate();previous.data=data.duplicate();snapshots[row_id]=previous
            addresses[row_id]={"position":pixel,"index":index}
        source.addresses=addresses
        source.prepared_addresses={"buffer":buffer,"packets":packets,"snapshots":snapshots,"count":snapshot.batch_rows.size()}
    return true

static func _finalize_candidate_source(work:Dictionary,id:int,prepared:Dictionary)->void:
    var owner:Dictionary=work.bulk_sources[id]
    # The full private outer directory is NOT the displayed source map.
    # Keep it on the existing per-key retirement lane after selected rows
    # transfer; dropping it at publication would synchronously unref K rows.
    prepared.retired_receivers=owner.binding_receivers
    prepared.receivers=owner.binding_receivers;prepared.specs=owner.binding_specs
    prepared.created_rows+=owner.created_rows;prepared.projected_packet_rows+=owner.static_rows
    owner.prepared=prepared;work.binding_sources[id]=prepared

static func _finish_source_capture(source:Dictionary)->void:
    for field in ["prepared_specs","prepared_output","snapshot","proof","rows","complete","prepared_binding","source_id","is_floor"]:source.erase(field)

static func _prepare_candidate_source(atlas,work:Dictionary,bindings:Dictionary,id:int)->void:
    var owner:Dictionary=work.bulk_sources[id]
    var spec:Dictionary=owner.first_spec
    var prepared:Dictionary=bindings.get(id,{})
    if prepared.is_empty():
        var source:Dictionary=work.source_patches.get(id,{})
        prepared=atlas.prepare_source_binding(spec.entry,source.snapshot if not source.is_empty() else spec.entry,work.world,true)
        if prepared.is_empty():work.error="unprepared_source:"+str(id);return
        prepared.receiver_parent=atlas.projection_root;bindings[id]=prepared
    _finalize_candidate_source(work,id,prepared)

static func prepare_candidate_binding(atlas,work:Dictionary,bindings:Dictionary)->bool:
    if work.get("error","")!="":return true
    if not work.get("complete",false):
        work.error="incomplete_private_prefix";return true
    if not work.bindings_transferred:
        # One native reference handoff; the worker already completed every
        # captured source directory. Only uncaptured incident sources fall back.
        bindings.merge(work.binding_sources,true);work.bindings_transferred=true
    if work.source_bind_cursor<work.source_bind_ids.size():
        var source_id:int=work.source_bind_ids[work.source_bind_cursor];work.source_bind_cursor+=1
        _prepare_candidate_source(atlas,work,bindings,source_id)
        return false
    # All static rows already belong to the private batch. Their source
    # directories retain every handle for cancellation or ordered publication.
    if not work.static_bindings_ready:
        work.private_draws.clear();work.static_bindings_ready=true
        work.bind_cursor=work.bind_ids.size()-work.dynamic_bind_ids.size()
    if work.dynamic_bind_cursor==work.dynamic_bind_ids.size():
        if work.output_cursor<work.output_ids.size():
            var id:int=work.output_ids[work.output_cursor];work.output_cursor+=1
            var source:Dictionary=work.source_patches[id]
            var output:Dictionary=work.outputs[id]
            if not output.is_empty():
                if output.get("private_node",false):
                    _install_output(source.entry,output)
                    source.entry.node.material_override=output.received_material
                    output.installed=true
                    # All receivers and the output have consumed this private
                    # source. Its first visible sample now starts a new delivery.
                    SourceMaterial.acknowledge(source.entry)
            # These fields belong to capture/planning only. Detach them beside
            # the hidden owner, not for hundreds of sources at publication.
            if source.has("snapshot"):_finish_source_capture(source)
            return false
        for job in work.jobs:
            if job.packet.is_empty():continue
            var source:Dictionary=work.source_patches[job.entry.node.get_instance_id()]
            if source.has("prepared_addresses"):
                job.packet.buffer=source.prepared_addresses.buffer
                job.packet.packets=source.prepared_addresses.packets
        work.preparation_usec={};work.prepared_created_rows=0;work.prepared_packet_rows=0
        for prepared in bindings.values():
            work.prepared_created_rows+=int(prepared.get("created_rows",0))
            work.prepared_packet_rows+=int(prepared.get("projected_packet_rows",0))
            for name in prepared.get("phase_usec",{}):
                work.preparation_usec[name]=work.preparation_usec.get(name,0)+prepared.phase_usec[name]
        work.bound=true
        return true
    var id:String=work.dynamic_bind_ids[work.dynamic_bind_cursor]
    work.dynamic_bind_cursor+=1;work.bind_cursor+=1
    var receiver:Dictionary=work.ready_style[id]
    var spec:Dictionary=receiver.spec
    var prepared:Dictionary=work.bulk_sources[spec.source_id].prepared
    var started:int=Time.get_ticks_usec() if prepared.profile_preparation else 0
    # Static children are already complete under their private batch. Only
    # actual live-pose nodes need individual scene attachment and sampling.
    receiver.node=atlas.prepare_receiver_node(atlas.projection_root)
    receiver.node.material=receiver.group.material
    receiver.node.region_rect=receiver.region;receiver.node.z_index=receiver.rank
    if prepared.profile_preparation:
        prepared.phase_usec.row_creation=prepared.phase_usec.get("row_creation",0)+Time.get_ticks_usec()-started
    var projection_started:int=Time.get_ticks_usec() if prepared.profile_preparation else 0
    atlas._project_entry(receiver,prepared.snapshot,prepared.basis)
    if prepared.profile_preparation:
        prepared.phase_usec.projection_apply=prepared.phase_usec.get("projection_apply",0)+Time.get_ticks_usec()-projection_started
    return false

static func _bulk_matches(atlas,work:Dictionary,removed:Dictionary)->bool:
    if not work.get("bulk_possible",false):return false
    if removed.size()!=work.removed.size():work.bulk_reason="changed_removals";return false
    for id in removed:
        if not work.removed.has(id):work.bulk_reason="changed_removals";return false
    if work.base_lists!=[atlas.receivers.size(),atlas.static_receivers.size(),atlas.groups.size()]:work.bulk_reason="changed_list_sizes";return false
    for proof in work.bulk_retained:
        var receiver:Dictionary=proof[0]
        if not is_same(atlas.receiver_index.get(receiver.id,{}),receiver) or not is_same(receiver.group,proof[1]) \
            or row_index(receiver)!=proof[2] or receiver.visibility!=proof[3] or receiver.entry.get("source_binding_revision",0)!=proof[4]:work.bulk_reason="changed_retained_receiver";return false
    # Visibility can move existing receivers between groups without changing
    # atlas addresses. Prove that ownership too, not just the layout token.
    for key in work.group_proofs:
        if not atlas.groups.has(key):work.bulk_reason="removed_group";return false
        var group:Dictionary=atlas.groups[key];var proof:Array=work.group_proofs[key]
        if not is_same(group,proof[0]) or group.material!=proof[1] or group.material.shader!=proof[2] \
            or group.crop!=proof[3] or group.rank!=proof[4] or group.get("users",0)!=proof[5]:work.bulk_reason="changed_group";return false
    return true

static func _adopt_group(atlas,group:Dictionary,spec:Dictionary)->void:
    # All resources and ranks were selected before admission. This is ownership
    # registration only; no material/node constructor or alternate binding path.
    if not atlas.groups.has(group.id):
        atlas.groups[group.id]=group
        atlas.last_reconcile_phases.prepared_receiver_materials=atlas.last_reconcile_phases.get("prepared_receiver_materials",0)+1
    group.entry=spec.entry;group.source_id=spec.source_id
    if not atlas.source_groups.has(spec.source_id):atlas.source_groups[spec.source_id]={}
    atlas.source_groups[spec.source_id][group.id]=group

static func _publish_bulk(atlas,work:Dictionary,positions:Dictionary,world:Node)->void:
    # Keep retained binds in order; within each intervening new-row run only
    # group registration can differ. Most prepared nodes already have exactly
    # that native material/rank, so no per-row commit work remains for them.
    var started:int=Time.get_ticks_usec()
    var bind_usec:int=0;var group_usec:int=0;var repair_usec:int=0;var bind_count:int=0;var group_count:int=0
    for command in work.bulk_commands:
        if command.has("replace"):
            var old:Dictionary=command.replace;var receiver:Dictionary=command.receiver
            var group:Dictionary=command.group
            _adopt_group(atlas,group,receiver.spec)
            if not is_same(old.group,group):drop_group(atlas,old.group);group.users=group.get("users",0)+1
            if not old.dynamic and old.get("view_visible",false):atlas.static_live_receivers-=1
            receiver.list_index=old.list_index;receiver.partition_index=old.partition_index
            atlas.receivers[old.list_index]=receiver
            var partition:Array=atlas.dynamic_receivers if receiver.dynamic else atlas.static_receivers
            partition[old.partition_index]=receiver
            atlas.receiver_index[receiver.id]=receiver
            atlas.entry_specs[receiver.spec.source_id].receivers[receiver.row_id]=receiver
            atlas.entry_specs[receiver.spec.source_id].by_row[receiver.row_id]=receiver.spec
            atlas.cull_dirty[receiver.id]=true;atlas.prepared_style_receivers[receiver.id]=receiver
            atlas.dispose_receiver(old)
            bind_count+=1
            continue
        var group_started:int=Time.get_ticks_usec()
        for span in command.group_spans:
            if span.prepared:
                # New private groups already own their entry, rank and first
                # user count. Native merges preserve first-seen registration
                # within this run; no zero-user transition crosses a span.
                atlas.groups.merge(span.groups)
                for source_id in span.sources:
                    if not atlas.source_groups.has(source_id):atlas.source_groups[source_id]={}
                    atlas.source_groups[source_id].merge(span.sources[source_id],true)
                atlas.last_reconcile_phases.prepared_receiver_materials=atlas.last_reconcile_phases.get("prepared_receiver_materials",0)+span.groups.size()
            else:
                for record in span.records:
                    var spec:Dictionary=record.spec
                    var group:Dictionary=record.group
                    _adopt_group(atlas,group,spec)
                    group.users=group.get("users",0)+record.rows.size()
        group_count+=command.groups.size()
        group_usec+=Time.get_ticks_usec()-group_started
    var transfer_started:int=Time.get_ticks_usec()
    var camera_matches:bool=work.cull_sample.key==atlas.projection_key(world)
    var culled_prepared:int=0;var hidden_prepared:int=0
    for record in work.bulk_sources.values():
        record.prepared.receivers=record.remaining
        if record.cull_all.is_empty():continue
        if camera_matches and record.prepared.entry.node.is_visible_in_tree()==record.source_visible:
            record.cull_owner.frame=atlas.sample_serial
            atlas.cull_dirty.merge(record.cull_shown)
            culled_prepared+=record.cull_all.size()
            hidden_prepared+=record.cull_all.size()-record.cull_shown.size()
        else:atlas.cull_dirty.merge(record.cull_all)
    for receiver in work.ready_retained:
        if not receiver.dynamic and receiver.cull_owner.frame==atlas.sample_serial and not receiver.cull_shown:
            atlas.cull_dirty.erase(receiver.id)
    atlas.last_reconcile_phases.prepared_bulk_transfer_ms=(Time.get_ticks_usec()-transfer_started)/1000.0
    atlas.last_reconcile_phases.prepared_bulk_ordered_bind_ms=bind_usec/1000.0
    atlas.last_reconcile_phases.prepared_bulk_group_register_ms=group_usec/1000.0
    atlas.last_reconcile_phases.prepared_bulk_repair_ms=repair_usec/1000.0
    atlas.last_reconcile_phases.prepared_bulk_ordered_binds=bind_count
    atlas.last_reconcile_phases.prepared_bulk_new_binds=0
    atlas.last_reconcile_phases.prepared_bulk_groups=group_count
    atlas.last_reconcile_phases.prepared_bulk_transfers=work.bulk_sources.size()
    atlas.last_reconcile_phases.prepared_cull_rows=culled_prepared
    atlas.last_reconcile_phases.prepared_cull_hidden=hidden_prepared
    atlas.last_reconcile_phases.prepared_row_created=work.prepared_created_rows
    atlas.last_reconcile_phases.prepared_row_numeric_projection=work.prepared_packet_rows
    atlas.last_reconcile_phases.prepared_projection_worker_ms=work.get("projection_worker_ms",0.0)
    atlas.last_reconcile_phases.prepared_group_worker_ms=work.get("group_worker_ms",0.0)
    atlas.last_reconcile_phases.prepared_output_worker_ms=work.get("output_worker_ms",0.0)
    atlas.last_reconcile_phases.prepared_worker_output_materials=work.get("worker_output_materials",0)
    atlas.last_reconcile_phases.prepared_group_worker_rid_ms=work.get("group_worker_rid_ms",0.0)
    atlas.last_reconcile_phases.prepared_worker_group_materials=work.get("worker_group_materials",0)
    atlas.last_reconcile_phases.prepared_worker_group_uniforms=work.get("worker_group_uniforms",0)
    atlas.last_reconcile_phases.prepared_resource_group_materials=work.get("prepared_group_materials",0)
    atlas.last_reconcile_phases.prepared_spec_worker_ms=work.get("spec_worker_ms",0.0)
    for name in work.get("spec_counts",{}):atlas.last_reconcile_phases["prepared_specs_"+name]=work.spec_counts[name]
    atlas.last_reconcile_phases.prepared_plan_specs_worker_ms=work.plan.get("specs_ms",0.0)
    atlas.last_reconcile_phases.prepared_plan_reservations_worker_ms=work.plan.get("reservations_ms",0.0)
    atlas.last_reconcile_phases.prepared_address_worker_ms=work.get("address_worker_ms",0.0)
    atlas.last_reconcile_phases.prepared_canvas_worker_ms=work.get("canvas_worker_ms",0.0)
    atlas.last_reconcile_phases.prepared_worker_canvas_items=work.get("worker_canvas_items",0)
    atlas.last_reconcile_phases.prepared_static_batches=int(work.get("static_batch")!=null)
    atlas.last_reconcile_phases.prepared_source_directory_binds=work.get("source_bind_ids",[]).size()
    atlas.last_reconcile_phases.prepared_worker_source_directories=work.get("worker_source_directories",0)
    atlas.last_reconcile_phases.prepared_worker_output_regions=work.get("worker_output_regions",0)
    atlas.last_reconcile_phases.prepared_dynamic_node_binds=work.get("dynamic_bind_ids",[]).size()
    atlas.last_reconcile_phases.prepared_receiver_record_worker_ms=work.get("receiver_record_worker_ms",0.0)
    for name in work.preparation_usec:atlas.last_reconcile_phases["preparation_"+name+"_ms"]=work.preparation_usec[name]/1000.0
    atlas.last_reconcile_phases.prepared_bulk_group_ms=(Time.get_ticks_usec()-started)/1000.0
    started=Time.get_ticks_usec()
    # Binding owns exact post-removal indices and partition order already.
    # Native bulk operations copy the prepared references; no row is derived,
    # reindexed or individually registered by this publication lane.
    atlas.receivers.append_array(work.ready_list)
    atlas.static_receivers.append_array(work.ready_static)
    atlas.dynamic_receivers.append_array(work.ready_dynamic)
    atlas.receiver_index.merge(work.ready_new);atlas.layout_members.merge(work.ready_members)
    atlas.packed_pixels+=work.ready_pixels
    atlas.last_reconcile_phases.prepared_registry_publish_ms=(Time.get_ticks_usec()-started)/1000.0
    var count:int=work.ready_list.size()
    atlas.last_reconcile_phases.prepared_bulk_registered=count
    atlas.prepared_style_receivers.merge(work.ready_style)
    for field in ["prepared_bulk_bindings","prepared_receiver_bindings","prepared_receiver_fast_bindings"]:
        atlas.last_reconcile_phases[field]=atlas.last_reconcile_phases.get(field,0)+count

# Transfer finished private containers to the existing scene retirement owner.
# Only these outer directories are private: their rows, supports and source
# records may now also belong to the displayed atlas and must never be cleared.
static func retire_candidate(record:Dictionary,prefix:Dictionary,bindings:Dictionary,retire_nodes:bool)->void:
    record.payloads.append({"prefix":prefix,"bindings":bindings,"retire_nodes":retire_nodes})

static func _retire_directory(record:Dictionary,values:Dictionary)->void:
    if not values.is_empty():record.directories.append({"values":values,"keys":[],"cursor":0})

static func retire_candidate_step(record:Dictionary)->Dictionary:
    if record.get("blocked",false):return {"done":false,"blocked":true}
    if record.get("task",-1)>=0:
        if not WorkerThreadPool.is_task_completed(record.task):return {"done":false,"blocked":true}
        WorkerThreadPool.wait_for_task_completion(record.task);record.task=-1
    if not record.get("unused",[]).is_empty():
        var receiver:Dictionary=record.unused.pop_back()
        var native_units:int=0
        if receiver.has("draw"):native_units=receiver.draw.dispose()
        elif is_instance_valid(receiver.get("node")):receiver.node.free();native_units=1
        return {"done":false,"node":native_units>0,"native_units":native_units}
    if not record.get("directories",[]).is_empty():
        var selected:Dictionary=record.directories.back()
        var native_units:int=0
        if selected.keys.is_empty():selected.keys=selected.values.keys()
        if selected.cursor<selected.keys.size():
            var key=selected.keys[selected.cursor]
            if selected.get("dispose_draws",false):
                native_units=selected.values[key].dispose()
            elif selected.get("dispose_receivers",false):
                var receiver:Dictionary=selected.values[key]
                if receiver.has("draw"):
                    native_units=receiver.draw.dispose()
                elif is_instance_valid(receiver.get("node")):
                    native_units=1;receiver.node.free()
            selected.values.erase(key);selected.cursor+=1
        if selected.cursor==selected.keys.size():record.directories.pop_back()
        return {"done":false,"node":native_units>0,"native_units":native_units}
    if not record.get("arrays",[]).is_empty():
        var values:Array=record.arrays.back()
        if not values.is_empty():values.pop_back()
        if values.is_empty():record.arrays.pop_back()
        return {"done":false}
    if not record.get("active",{}).is_empty():
        var active:Dictionary=record.active
        if active.cursor<active.keys.size():
            var binding:Dictionary=active.bindings[active.keys[active.cursor]];active.cursor+=1
            if active.retire_nodes:record.unused.append_array(binding.get("receivers",{}).values())
            for field in ["receivers","retired_receivers","specs","groups","snapshot","source","output"]:_retire_directory(record,binding.get(field,{}))
            _retire_directory(record,binding)
            return {"done":false}
        if not active.get("detached",false):
            active.detached=true
            # Finish each job/command separately: they may retain private
            # native material stores even after their top-level maps drained.
            record.arrays=[active.prefix.get("jobs",[]),active.prefix.get("bulk_commands",[])]
            _retire_directory(record,active.bindings)
            _retire_directory(record,active.prefix)
            return {"done":false}
        record.active={}
        return {"done":false}
    if not record.payloads.is_empty():
        var active:Dictionary=record.payloads.pop_back()
        active.keys=active.bindings.keys();active.cursor=0;record.active=active
        var prefix:Dictionary=active.prefix
        var private_draws:Dictionary=prefix.get("private_draws",{})
        if not private_draws.is_empty():record.directories.append({"values":private_draws,"keys":[],"cursor":0,"dispose_draws":true})
        var obsolete:Dictionary=prefix.get("obsolete_private_receivers",{})
        if not obsolete.is_empty():record.directories.append({"values":obsolete,"keys":[],"cursor":0,"dispose_receivers":true})
        for field in ["receiver_index","support_owners","published_supports","entry_specs"]:
            _retire_directory(record,prefix.get("passive",{}).get(field,{}))
        for field in ["positions","owners","specs"]:_retire_directory(record,prefix.get("plan",{}).get(field,{}))
        for field in ["specs","removed","source_patches","ready_new","ready_members","ready_cull","bulk_sources","binding_sources","group_proofs","outputs","source_proofs","projection_packets","source_ground_versions","group_inputs","private_groups"]:
            _retire_directory(record,prefix.get(field,{}))
        return {"done":false}
    return {"done":true}

static func candidate_base_matches(atlas,work:Dictionary,world,target_world:Node=null)->bool:
    # Check the current owner before the display cut. Future visibility and
    # ground versions are validated separately against private prepared output.
    if work.is_empty():return true
    if work.has("error") or not work.get("complete",false) or not work.get("bound",false):return false
    if work.token!=token(atlas) or work.get("base_basis",work.basis)!=world.camera.global_basis or work.screen!=world.get_viewport().get_visible_rect().size:return false
    if work.basis!=(world.camera.global_basis if target_world==null else target_world.camera.global_basis):return false
    if not _bulk_matches(atlas,work,work.removed):return false
    for proof in work.source_proofs.values():
        var entry:Dictionary=proof.entry
        if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion():return false
        if entry.cell!=proof.cell or entry.material!=proof.material:return false
        if entry.get("source_binding_revision",0)!=proof.binding_revision:return false
        if entry.get("ground_version",0)!=proof.get("base_ground_version",0):return false
    return true

static func candidate_matches(atlas,work:Dictionary,world,upserts:Dictionary,removed_sources:Dictionary)->bool:
    if work.is_empty() or work.has("error") or not work.get("complete",false) or not work.get("bound",false) or work.token!=token(atlas):return false
    if work.basis!=world.camera.global_basis or work.screen!=world.get_viewport().get_visible_rect().size:return false
    for id in work.removed_sources:
        if not removed_sources.has(id):return false
    for id in upserts:
        if work.source_patches.has(id):continue
        if not atlas._entry_info(upserts[id]).dynamic:return false
        if atlas.entry_specs.has(id) and atlas.entry_specs[id].signature[0]!=upserts[id].cell:return false
    for id in removed_sources:
        if work.removed_sources.has(id) or not atlas.entry_specs.has(id):continue
        if not atlas.entry_specs[id].info.dynamic:return false
    for id in work.source_patches:
        if not upserts.has(id):return false
        var source:Dictionary=work.source_patches[id]
        var proof:Dictionary=work.source_proofs[id];var entry:Dictionary=upserts[id]
        if not is_same(entry,proof.entry) or entry.cell!=proof.cell or entry.material!=proof.material:return false
        if entry.get("source_binding_revision",0)!=proof.binding_revision:return false
        if not source.info.dynamic:
            var record:Dictionary=entry.get("record",{})
            if record.get("path","")!=proof.record_path or record.get("rect",[])!=proof.record_rect:return false
            if entry.get("ground_version",0)!=proof.ground_version:return false
            var mesh:QuadMesh=entry.node.multimesh.mesh if entry.has("batch_rows") else entry.node.mesh
            if [entry.node.global_transform,mesh.size,mesh.center_offset]!=proof.geometry:return false
            if proof.scenery is Dictionary:
                for row_id in proof.scenery:
                    if entry.scenery_values[entry.ground_indices[row_id]]!=proof.scenery[row_id]:return false
            elif entry.get("scenery_values",entry.get("scenery_value",1.0))!=proof.scenery:return false
        if atlas._entry_info(entry)!=proof.info:return false
    return true

static func _install_output(entry:Dictionary,output:Dictionary)->void:
    entry.received_material=output.received_material
    if output.has("received_source_key"):entry.received_source_key=output.received_source_key
    if output.has("received_style"):entry.received_style=output.received_style
    else:entry.erase("received_style")

static func reconcile(atlas, world, changes: Dictionary) -> bool:
    if not atlas.delta_ready or atlas.delta_serial<0: return _fallback(atlas,"no_committed_delta")
    var serial: int=int(changes.serial)
    var new_world: bool=serial!=atlas.delta_serial
    if new_world and int(changes.base)==atlas.delta_serial and bool(changes.full) \
        and atlas.receivers.is_empty() and atlas.entry_specs.is_empty() and atlas.groups.is_empty() \
        and atlas.membership.is_empty() and atlas.prepared_delta.is_empty():
        var empty:bool=true
        for entries in [world.entries,world.actor_entries,world.fixture_entries,changes.upserts]:
            for entry in entries:
                if entry.has("cell") and is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion():empty=false;break
            if not empty:break
        if empty:
            # WorldPreparation can certify an empty initial base without any
            # private native jobs. This advances only its exact receipt; the
            # first future source still requires its own admitted preparation.
            atlas.delta_serial=serial
            atlas.last_reconcile_phases.delta_sources=0
            return true
    if new_world and (int(changes.base)!=atlas.delta_serial or (bool(changes.full) and not atlas.prepared_delta.get("admitted",false))): return _fallback(atlas,"full_or_missed_receipt")
    var screen=Vector2i(world.get_viewport().get_visible_rect().size)
    if screen.x>atlas.viewport.size.x or screen.y>atlas.viewport.size.y:
        if not atlas.prepared_delta.get("admitted",false) or screen.x>atlas.MAX_SIZE or screen.y>atlas.prepared_delta.plan.next_height:return _fallback(atlas,"screen_resize")
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
    if atlas.require_prepared_publication and not atlas.prepared_delta.get("admitted",false):
        return _fallback(atlas,"missing_prepared_publication")
    var source_patches={}; var removed={}; var specs={}; var floor_ids={}; var address_changes={}
    var candidate:Dictionary=atlas.prepared_delta
    var candidate_started:int=Time.get_ticks_usec()
    var staged:bool=candidate.get("admitted",false) or candidate_matches(atlas,candidate,world,upserts,removed_sources)
    atlas.last_reconcile_phases.prepared_candidate_check_ms=(Time.get_ticks_usec()-candidate_started)/1000.0
    if not candidate.is_empty() and not staged:
        atlas.last_reconcile_phases.prepared_prefix_rejected=candidate.get("error","changed_atlas_source_or_view")
        if candidate.get("plan",{}).has("error"):atlas.last_reconcile_phases.prepared_prefix_error=candidate.plan
    var plan:Dictionary={}
    var extra_specs:Array=[]
    var next_order: int=atlas.next_source_order
    if staged:
        source_patches=candidate.source_patches;floor_ids=candidate.floor_ids
        next_order=candidate.next_order;plan=candidate.plan
        for id in candidate.removed:removed[id]=atlas.receiver_index[id]
        for id in source_patches:
            var prepared:Dictionary=atlas.prepared_source_bindings.get(id,{})
            if not prepared.is_empty():prepared.accepted=true
        atlas.last_reconcile_phases.prepared_prefix_specs=plan.specs.size()
        atlas.last_reconcile_phases.prepared_prefix_worker_ms=candidate.worker_ms
    for id in removed_sources:
        if not atlas.entry_specs.has(id): continue
        for receiver in atlas.entry_specs[id].receivers.values(): removed[receiver.id]=receiver
    for id in upserts:
        if staged and source_patches.has(id):continue
        var entry: Dictionary=upserts[id]
        if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion() or not entry.has("cell"): continue
        var source=_source(atlas,entry,world)
        if source.crop.is_empty(): return _fallback(atlas,"missing_crop")
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
                if geometry.get("base_version",-1)!=before.ground_version or geometry.get("version",-1)!=source.ground_version: return _fallback(atlas,"ground_version")
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
    var planned_at:int=Time.get_ticks_usec()
    if staged and (not specs.is_empty() or removed.size()!=candidate.removed.size()):
        if candidate.get("admitted",false):return _fallback(atlas,"unprepared_dynamic_membership")
        # New actor/fixture cells are real publication-time inputs. They sort
        # after the static receipt's sources and cannot alter floor supports.
        var extra_base={"receiver_index":atlas.receiver_index,"support_owners":atlas.support_owners,
            "published_supports":plan.supports,"entry_specs":atlas.entry_specs,"shelf_cursor":plan.cursor,
            "viewport":{"size":Vector2i(atlas.MAX_SIZE,plan.next_height)},"MAX_SIZE":atlas.MAX_SIZE}
        var extra_started:int=Time.get_ticks_usec()
        var extra:Dictionary=_plan(extra_base,source_patches,{},specs)
        atlas.last_reconcile_phases.prepared_extra_plan_ms=(Time.get_ticks_usec()-extra_started)/1000.0
        if extra.has("error"):return _fallback(atlas,extra.error)
        extra_specs=extra.specs.values()
        plan.positions.merge(extra.positions,true);plan.specs.merge(extra.specs,true)
        plan.cursor=extra.cursor;plan.next_height=extra.next_height
        plan.growing=plan.next_height!=atlas.viewport.size.y
    elif not staged:
        plan=_plan(atlas,source_patches,removed,specs)
        if plan.has("error"):
            atlas.last_reconcile_phases.delta_rejected_plan=plan
            return _fallback(atlas,plan.error)
    var owners:Dictionary=plan.owners;var supports:Dictionary=plan.supports
    var positions:Dictionary=plan.positions;var cursor:Vector3i=plan.cursor
    var next_height:int=plan.next_height;var growing:bool=plan.growing
    specs=plan.specs
    atlas.last_reconcile_phases.specs_ms=(planned_at-started)/1000.0 if staged else (Time.get_ticks_usec()-started)/1000.0-plan.reservations_ms
    atlas.last_reconcile_phases.delta_sources=source_patches.size()
    atlas.last_reconcile_phases.delta_specs=specs.size()
    atlas.last_reconcile_phases.delta_support_cells=plan.support_cells
    # Commit only after every reservation and the same full-planner dimensions
    # have been validated. A rejected candidate cannot resize the live viewport.
    atlas.last_reconcile_phases.reservations_ms=(Time.get_ticks_usec()-started)/1000.0-atlas.last_reconcile_phases.specs_ms
    var bulk:bool=staged and (candidate.get("admitted",false) or _bulk_matches(atlas,candidate,removed))
    if staged and not bulk:return _fallback(atlas,"prepared_membership_changed")
    var phase=Time.get_ticks_usec()
    if growing:
        atlas.viewport.size=Vector2i(atlas.MAX_SIZE,next_height)
        atlas.repack_count+=1
    elif staged and candidate.get("rebased",false):atlas.repack_count+=1
    atlas.last_reconcile_phases.resize_ms=(Time.get_ticks_usec()-phase)/1000.0
    var binding_phase:int=Time.get_ticks_usec()
    for receiver in removed.values():
        atlas.packed_pixels-=receiver.crop.pixels.size.x*receiver.crop.pixels.size.y
        atlas.layout_members.erase(receiver.id)
        _remove(atlas,receiver)
    for id in removed_sources:
        atlas.entry_specs.erase(id); atlas.source_groups.erase(id)
    for id in source_patches:
        atlas.entry_specs[id]=source_patches[id]
        # The producer owns the material sample that was actually prepared.
        # Ordinary scalar sampling below still detects source/hover/sight
        # changes since that sample; no group/material re-certification here.
        var source:Dictionary=source_patches[id]
        var entry:Dictionary=source.entry
        if source.get("synced",false) and source.sync_version==entry.get("source_version",0) \
                and source.sync_highlighted==SourceMaterial.value(entry,"highlighted") \
                and source.sync_visibility==float(entry.get("scenery_value",1.0)):
            atlas.material_dirty.erase(id)
            atlas.last_reconcile_phases.prepared_material_sources=atlas.last_reconcile_phases.get("prepared_material_sources",0)+1
        else:atlas.material_dirty[id]=true
    for cell in owners:
        if owners[cell].is_empty(): atlas.support_owners.erase(cell)
        else: atlas.support_owners[cell]=owners[cell]
    for cell in owners:
        if supports.has(cell):atlas.published_supports[cell]=supports[cell]
        else:atlas.published_supports.erase(cell)
    atlas.last_reconcile_phases.registry_ms=(Time.get_ticks_usec()-binding_phase)/1000.0
    binding_phase=Time.get_ticks_usec()
    var new_receivers:Array=[];var admitted_groups:Dictionary={}
    var bindings:Array
    if bulk:
        _publish_bulk(atlas,candidate,positions,world)
        atlas.last_reconcile_phases.prepared_bulk_ms=(Time.get_ticks_usec()-binding_phase)/1000.0
        bindings=extra_specs
    else:bindings=specs.values()
    for spec in bindings:
        var ready:Dictionary=candidate.ready_new.get(spec.id,{}) if staged and not bulk else {}
        if not ready.is_empty():
            var key:Array=ready.group.id
            var group:Dictionary=admitted_groups.get(key,{})
            if group.is_empty():
                group=atlas._group(ready.entry,spec.crop,ready.visibility,spec.id,spec.info,spec.join_mask)
                admitted_groups[key]=group
            if not group.has("users"):group.users=0
            group.users+=1;ready.group=group
            atlas.set_receiver_material(ready,group.material)
            var rank:int=group.rank%1024
            if ready.get("rank",-1)!=rank:atlas.set_receiver_rank(ready,rank);ready.rank=rank
            atlas.prepared_source_bindings[spec.source_id].receivers.erase(spec.id)
            new_receivers.append(ready)
        else:
            if not atlas.layout_members.has(spec.id): atlas.packed_pixels+=spec.crop.pixels.size.x*spec.crop.pixels.size.y
            atlas.layout_members[spec.id]=spec.crop
            _bind(atlas,spec,positions[spec.id])
    if not new_receivers.is_empty():
        var start:int=atlas.receivers.size();var static_start:int=atlas.static_receivers.size()
        for index in new_receivers.size():
            new_receivers[index].list_index=start+index;new_receivers[index].partition_index=static_start+index
        atlas.receivers.append_array(new_receivers);atlas.static_receivers.append_array(new_receivers)
        atlas.receiver_index.merge(candidate.ready_new);atlas.layout_members.merge(candidate.ready_members)
        atlas.cull_dirty.merge(candidate.ready_cull);atlas.packed_pixels+=candidate.ready_pixels
        atlas.last_reconcile_phases.prepared_bulk_bindings=new_receivers.size()
        atlas.last_reconcile_phases.prepared_receiver_bindings=atlas.last_reconcile_phases.get("prepared_receiver_bindings",0)+new_receivers.size()
        atlas.last_reconcile_phases.prepared_receiver_fast_bindings=atlas.last_reconcile_phases.get("prepared_receiver_fast_bindings",0)+new_receivers.size()
    atlas.shelf_cursor=cursor; atlas.delta_serial=serial; atlas.next_source_order=next_order
    atlas.last_reconcile_phases.bindings_ms=(Time.get_ticks_usec()-binding_phase)/1000.0
    if bulk:atlas.last_reconcile_phases.unprepared_bindings_ms=atlas.last_reconcile_phases.bindings_ms-atlas.last_reconcile_phases.prepared_bulk_ms
    atlas.last_reconcile_phases.receivers_ms=(Time.get_ticks_usec()-phase)/1000.0
    phase=Time.get_ticks_usec()
    var outputs=[]; var floors={}
    var prepared_regions:Dictionary={}
    var output_target:Vector2=Vector2(atlas.viewport.size)
    var output_adopt_usec:int=0;var output_transport_usec:int=0
    var output_records_usec:int=0;var output_created:int=0
    var prepared_material_count:int=0;var prepared_binding_count:int=0;var prepared_region_count:int=0
    for id in source_patches:
        var output_started:int=Time.get_ticks_usec()
        var source: Dictionary=atlas.entry_specs[id]
        var entry: Dictionary=source.entry
        var shader: Shader=source.info.output
        var prepared_output: Dictionary=candidate.outputs[id] if staged and candidate.outputs.has(id) else source.get("prepared_output",{})
        if not prepared_output.is_empty():
            if not prepared_output.get("installed",false):_install_output(entry,prepared_output)
            prepared_material_count+=1
        if not staged or not candidate.outputs.has(id):
            source.erase("prepared_specs"); source.erase("prepared_output")
            for private_key in ["snapshot","proof","rows","complete"]:source.erase(private_key)
        output_adopt_usec+=Time.get_ticks_usec()-output_started;output_started=Time.get_ticks_usec()
        if not entry.has("received_material"):
            entry.received_material=ShaderMaterial.new();output_created+=1
        var output: ShaderMaterial=entry.received_material
        var prepared_transport:bool=staged and not prepared_output.is_empty()
        if not prepared_transport and output.shader!=shader:
            output.shader=shader; entry.erase("received_source_key")
        if not prepared_transport:
            output.set_shader_parameter("received",atlas.viewport.get_texture())
            output.set_shader_parameter("received_is_encoded_hdr",atlas._uses_hdr())
            output.set_shader_parameter("use_instance_atlas",entry.has("batch_rows"))
            output.set_shader_parameter("light_cap",atlas.light_cap)
        else:prepared_binding_count+=1
        if not prepared_output.get("installed",false):entry.node.material_override=output
        source.output=output
        if staged and candidate.source_patches.has(id) and prepared_output.get("region_target",Vector2.ZERO)==output_target:
            prepared_regions[id]=true
            prepared_region_count+=1
        atlas.output_changed(entry)
        output_transport_usec+=Time.get_ticks_usec()-output_started;output_started=Time.get_ticks_usec()
        if floor_ids.has(id):
            var repairs: Array=[]
            if address_changes.has(id):
                for row_id in address_changes[id]: repairs.append(source.receivers[str(row_id)])
            else: repairs=source.receivers.values()
            floors[id]={"entry":entry,"receivers":repairs,"crop":source.crop,"repair_indices":true,
                "preserved_rows":source.receivers.size()-repairs.size(),
                "coherent_addresses":entry.get("prepared_address_version",-1)==entry.get("ground_version",0),
                "region_prepared":prepared_regions.has(id)}
            if staged and source.has("prepared_addresses"):
                floors[id].prepared=source.prepared_addresses
                source.erase("prepared_addresses")
        elif not prepared_regions.has(id): outputs.append_array(source.receivers.values())
        output_records_usec+=Time.get_ticks_usec()-output_started
    atlas.last_reconcile_phases.output_materials_ms=(Time.get_ticks_usec()-phase)/1000.0
    atlas.last_reconcile_phases.output_adopt_ms=output_adopt_usec/1000.0
    atlas.last_reconcile_phases.output_transport_ms=output_transport_usec/1000.0
    atlas.last_reconcile_phases.output_certify_ms=0.0
    atlas.last_reconcile_phases.output_records_ms=output_records_usec/1000.0
    atlas.last_reconcile_phases.output_created=output_created
    atlas.last_reconcile_phases.prepared_output_materials=prepared_material_count
    atlas.last_reconcile_phases.prepared_output_bindings=prepared_binding_count
    atlas.last_reconcile_phases.prepared_output_regions=prepared_region_count
    var address_phase:int=Time.get_ticks_usec()
    atlas._publish_addresses(floors,outputs)
    atlas.last_reconcile_phases.address_publish_ms=(Time.get_ticks_usec()-address_phase)/1000.0
    address_phase=Time.get_ticks_usec()
    if growing:atlas._refresh_normalized_addresses(prepared_regions)
    atlas.last_reconcile_phases.address_resize_ms=(Time.get_ticks_usec()-address_phase)/1000.0
    atlas.last_reconcile_phases.addresses_ms=atlas.last_reconcile_phases.address_publish_ms+atlas.last_reconcile_phases.address_resize_ms
    atlas.last_reconcile_phases.layout_mode="delta_growth" if growing else "delta"
    if growing: atlas.last_reconcile_phases.grown_height=next_height
    atlas.revision+=1
    return true
