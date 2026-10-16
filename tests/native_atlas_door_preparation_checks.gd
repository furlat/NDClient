extends "res://tests/native_atlas_staged_checks.gd"
## Exact pre-bind capacity and ordered private registration versus full planning.
## Reuses the native source/framebuffer oracle; no gameplay latency claim.

func publish(side:Dictionary,full:bool,upserts:Array)->void:
    var base:int=side.serial;side.serial+=1
    var receipt={"base":base,"serial":side.serial,"full":full,"upserts":upserts,"removed":[]}
    side.atlas.sync(side.world,[side.serial],[side.serial,0,0,"solid"],receipt,true)
    side.atlas.sync_output(side.world,[side.serial],true)

func draw_pair(a:Dictionary,b:Dictionary,label:String)->void:
    if DisplayServer.get_name()=="headless":
        await process_frame
        return
    await first_draw(a,b,label)

func planned(side:Dictionary,entries:Array,packet:Dictionary={})->Dictionary:
    var bindings:Dictionary={};var jobs:Array=[]
    for entry in entries:
        var snapshot:Dictionary=entry.duplicate()
        var future:Dictionary=packet if is_same(entry,side.floor) else {}
        if not future.is_empty():
            snapshot.ground_version=entry.ground_version+1;snapshot.batch_rows=future.rows
            snapshot.ground_indices=future.indices;snapshot.ground_packets=future.packets
            snapshot.ground_buffer=future.buffer;snapshot.scenery_values=future.values;snapshot.placement=future.rows[0]
        var binding:Dictionary=side.atlas.prepare_source_binding(entry,snapshot,side.world,true,{"defer_static_output":true},true)
        check(not binding.is_empty(),"Selected source has its private native binding")
        binding.receiver_parent=side.atlas.projection_root
        bindings[entry.node.get_instance_id()]=binding
        jobs.append({"entry":entry,"prepared":binding,"packet":future,
            "rows":future.geometry_changes.changed if not future.is_empty() else [entry.placement],
            "source_visible":entry.node.visible})
    var prefix:Dictionary=Atlas.Delta.begin_candidate(side.atlas,jobs,{},side.world)
    while not Atlas.Delta.capture_candidate(side.atlas,prefix,side.world):pass
    var task:int=WorkerThreadPool.add_task(Atlas.Delta.compute_candidate.bind(prefix),false,"Prepare private final atlas resources")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    check(prefix.get("complete",false) and not prefix.has("error"),"Existing planner completes the passive candidate")
    check(bindings.values().all(func(binding):return binding.receivers.is_empty() and binding.created_rows==0),
        "Passive final projection planning allocates no receiving node or provisional material group")
    check(prefix.private_draws.size()==prefix.projection_packets.size() and prefix.private_draws.values().all(
        func(draw):return draw.rid.is_valid() and not draw.parent.is_valid() and not draw.visible),
        "Worker owns exactly the final static canvas items, hidden and unparented without a SceneTree Node")
    check(prefix.ready_style.size()==prefix.bind_ids.size() and prefix.bulk_sources.values().all(
        func(owner):return owner.prepared.is_empty() and owner.binding_receivers.size()>=owner.created_rows),
        "Worker completes actual receiver records, source directories and ordered leases before scene attachment")
    check(prefix.group_proofs.values().all(func(proof):return proof[0].rank==proof[4] and proof[0].users==proof[5]),
        "Private receiver assembly does not mutate displayed group ranks or user counts")
    return {"prefix":prefix,"bindings":bindings}

func bind_private(side:Dictionary,work:Dictionary)->void:
    while not Atlas.Delta.prepare_candidate_binding(side.atlas,work.prefix,work.bindings):pass
    check(work.prefix.get("bound",false) and not work.prefix.has("error"),"Candidate binds exact selected receivers and outputs")
    var expected:int=work.prefix.ready_list.size()+work.prefix.ready_retained.size()
    check(work.prefix.prepared_created_rows==expected,"Final scene binding creates each selected receiver exactly once")
    var compared:int=0;var exact:bool=true
    for receiver in work.prefix.ready_list+work.prefix.ready_retained:
        if receiver.dynamic:continue
        check(receiver.has("draw") and not receiver.has("node") and receiver.draw.parent==side.atlas.projection_root.get_canvas_item(),
            "Scene binding attaches the exact private static RID without constructing a Sprite2D")
        var prepared:Dictionary=work.bindings[receiver.spec.source_id]
        var reference:Dictionary=receiver.duplicate();reference.erase("draw");reference.node=Sprite2D.new()
        # Independent original scene arithmetic, including native quad/ground
        # operand reads, remains the qualification oracle for worker packets.
        side.atlas._project_entry(reference,prepared.snapshot,prepared.basis)
        exact=exact and Atlas.receiver_transform(receiver)==reference.node.transform and receiver.bounds==reference.bounds \
            and receiver.world_origin==reference.world_origin and receiver.projection==reference.projection
        reference.node.free();compared+=1
    check(exact and compared==work.prefix.prepared_packet_rows,
        "Final numeric static projections exactly match original scene projection arithmetic")
    var private_groups:int=0
    for groups in work.prefix.private_groups.values():
        for group in groups.values():
            private_groups+=1
            check(group.material.get_rid().is_valid() and group.target_material==group.material,
                "Only the new worker-owned receiving material reaches native attachment")
    check(private_groups==work.prefix.worker_group_materials,"Final binding retains every exact private material produced by its worker")
    check(work.prefix.preparation_usec.has("source_setup") and work.prefix.preparation_usec.has("output_materials") \
        and work.prefix.preparation_usec.has("row_creation") and work.prefix.preparation_usec.has("projection_apply"),
        "Profiled native preparation separates source setup, output, row allocation and projection application")

func admit(side:Dictionary,work:Dictionary)->void:
    check(Atlas.Delta.candidate_base_matches(side.atlas,work.prefix,side.world),"Candidate retains its exact live base at publication")
    work.prefix.admitted=true
    for binding in work.bindings.values():
        check(side.atlas.adopt_source_binding(binding),"Each private source transfers to the existing atlas owner once")
    side.atlas.prepared_delta=work.prefix

func dispose_pair(a:Dictionary,b:Dictionary)->void:
    a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free()
    await process_frame

func capacity_case(source:Image,label:String,normals:bool,cancel:bool)->void:
    var a=make_side(source,true,normals);var b=make_side(source,true,normals)
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    check(a.atlas.viewport.size==Vector2i(8192,1024),label+" starts at the actual shelf boundary")
    await draw_pair(a,b,label+"-initial")
    var old_positions:Dictionary=positions(a.atlas)
    var old_cursor:Vector3i=a.atlas.shelf_cursor
    var old_count:int=a.atlas.receivers.size()
    var old_buffer:PackedFloat32Array=a.floor.node.multimesh.buffer
    var candidate=Node3D.new();candidate.hide();a.world.add_child(candidate)
    var add_a:Array=[];var add_b:Array=[]
    for index in range(14,16):
        var entry:Dictionary=single(a.world,a.texture,index)
        entry.node.reparent(candidate,false);add_a.append(entry)
        var reference:Dictionary=single(b.world,b.texture,index);reference.node.hide();add_b.append(reference)
    var work:Dictionary=await planned(a,add_a)
    var stale:Dictionary=await planned(a,[a.world.entries[1]])
    bind_private(a,stale)
    check(Atlas.Delta.candidate_base_matches(a.atlas,stale.prefix,a.world),label+" another prepared candidate starts valid")
    var old_token:Array=work.prefix.token.duplicate()
    check(work.prefix.plan.growing and work.prefix.plan.next_height==2048,label+" worker derives only the exact needed height")
    check(Atlas.Delta.reserve_candidate_capacity(a.atlas,work.prefix),label+" exact capacity reservation succeeds")
    check(a.atlas.viewport.size==Vector2i(8192,2048) and work.prefix.get("capacity_reserved",false)
        and not work.prefix.plan.growing and work.prefix.token!=old_token,label+" capacity is reserved and only its candidate token rebases")
    check(positions(a.atlas)==old_positions and a.atlas.shelf_cursor==old_cursor and a.atlas.receivers.size()==old_count
        and a.floor.node.multimesh.buffer==old_buffer,label+" reservation changes no live pixel positions, membership, shelf or integer floor addresses")
    check(not Atlas.Delta.candidate_base_matches(a.atlas,stale.prefix,a.world),label+" reservation invalidates another candidate without rebasing it")
    var reserved_repack:int=a.atlas.repack_count
    check(Atlas.Delta.reserve_candidate_capacity(a.atlas,work.prefix) and a.atlas.repack_count==reserved_repack,
        label+" repeated reservation is a no-op")
    transport(a,label+" reserved current outputs")
    await draw_pair(a,b,label+"-reserved-old-frame")
    retire_private(stale)
    if cancel:
        retire_private(work);candidate.queue_free()
        for entry in add_b:entry.node.queue_free()
        await process_frame
        check(a.atlas.viewport.size==Vector2i(8192,2048) and a.atlas.repack_count==reserved_repack
            and positions(a.atlas)==old_positions and a.atlas.receivers.size()==old_count,
            label+" cancellation retains capacity and only the original displayed membership")
        await draw_pair(a,b,label+"-cancelled-old-frame")
    else:
        bind_private(a,work);admit(a,work)
        for entry in add_a:entry.node.reparent(a.world,false)
        for entry in add_b:entry.node.show()
        a.world.entries.append_array(add_a);b.world.entries.append_array(add_b)
        publish(a,false,add_a);publish(b,true,b.world.entries)
        check(a.atlas.repack_count==reserved_repack and a.atlas.last_reconcile_phases.get("layout_mode","")=="delta",
            label+" cue publication does not resize the already reserved target")
        check(positions(a.atlas)==positions(b.atlas) and a.atlas.shelf_cursor==b.atlas.shelf_cursor,
            label+" exact final positions and shelf equal complete planning")
        transport(a,label+" admitted outputs")
        await draw_pair(a,b,label+"-published")
        candidate.queue_free()
    await dispose_pair(a,b)

func cull_case(source:Image,mode:String)->void:
    var label:String="door-cull-"+mode
    var a=make_side(source,true,false);var b=make_side(source,true,false)
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    var candidate=Node3D.new();candidate.hide();a.world.add_child(candidate)
    var add_a:Array=[];var add_b:Array=[]
    for index in 2:
        var ea:Dictionary=single(a.world,a.texture,20+index,Vector2(64,64))
        var eb:Dictionary=single(b.world,b.texture,20+index,Vector2(64,64))
        ea.node.position=Vector3(0,0,0) if index==0 else Vector3(200,200,0)
        eb.node.position=ea.node.position
        ea.node.reparent(candidate,false);eb.node.hide();add_a.append(ea);add_b.append(eb)
    var work:Dictionary=await planned(a,add_a);bind_private(a,work)
    check(not work.prefix.plan.growing,label+" does not need capacity growth")
    if mode=="camera":
        for side in [a,b]:side.world.camera.position.x+=.75;side.world.camera.size+=.5
    for entry in add_a:entry.node.reparent(a.world,false)
    for entry in add_b:entry.node.show()
    if mode=="source":
        for entry in [add_a[0],add_b[0]]:entry.node.hide()
    admit(a,work)
    a.world.entries.append_array(add_a);b.world.entries.append_array(add_b)
    publish(a,false,add_a);publish(b,true,b.world.entries)
    var near_row:Dictionary=row_receiver(a.atlas,add_a[0])
    var far_row:Dictionary=row_receiver(a.atlas,add_a[1])
    check(not Atlas.receiver_visible(far_row) and not far_row.get("view_visible",false),label+" offscreen source remains admitted but not rendered")
    if mode=="stable":
        check(a.atlas.last_reconcile_phases.get("prepared_cull_rows",0)==2
            and a.atlas.last_reconcile_phases.get("prepared_cull_hidden",0)==1,
            label+" captured camera and published ancestry admit both decisions including the hidden row")
        check(near_row.cull_owner.frame==a.atlas.sample_serial and Atlas.receiver_visible(near_row),
            label+" visible source uses the prepared decision on its first sample")
    elif mode=="camera":
        check(a.atlas.last_reconcile_phases.get("prepared_cull_rows",0)==0
            and near_row.cull_owner.frame!=a.atlas.sample_serial,label+" changed camera uses ordinary current projection and culling")
    else:
        check(near_row.cull_owner.frame!=a.atlas.sample_serial and not Atlas.receiver_visible(near_row),
            label+" changed published ancestry rejects its stale prepared visibility")
    await draw_pair(a,b,label+"-published")
    # The one-publication decision must not mask subsequent current camera work.
    for side in [a,b]:side.world.camera.position.x+=1.25
    publish(a,false,[]);publish(b,true,b.world.entries)
    check(near_row.cull_owner.frame!=a.atlas.sample_serial,label+" prepared decision expires after the original sample")
    await draw_pair(a,b,label+"-next-camera")
    candidate.queue_free();await dispose_pair(a,b)

func packet_visibility(packet:Dictionary,id:String,value:float)->void:
    var index:int=packet.indices[id]
    packet.values[index]=value;packet.buffer[index*20+16]=value;packet.packets[id].data[16]=value

func group_case(source:Image)->void:
    var a=make_side(source,true,false);var b=make_side(source,true,false)
    # Group identity includes exposed-face join_mask as well as visibility.
    # Isolated cells give both old and future rows the same actual zero mask;
    # adjacent cells would legitimately select different material groups.
    for side in [a,b]:side.floor.batch_rows[1].position=[4,0]
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    var old_group:Dictionary=row_receiver(a.atlas,a.floor,"0").group
    var rows:Array=a.floor.batch_rows.duplicate(true)
    # A real retained-row geometry change selects this replacement before the
    # new rows. Visibility-only cuts are separately covered by WorldPrep's
    # visibility_changes source-row admission; geometry changes alone omit it.
    rows[0].base_height_steps=1
    for index in 4:
        var row:Dictionary=rows[0].duplicate(true)
        row.id="new-"+str(index);row.position=[(index+2)*4,0];rows.append(row)
    var pa:Dictionary=prepared_floor_packet(a.floor,[],a.atlas.floor_address_token(a.floor),rows)
    var pb:Dictionary=prepared_floor_packet(b.floor,[],b.atlas.floor_address_token(b.floor),rows)
    check(pa.geometry_changes.changed.has("0") and pa.geometry_changes.changed[0]=="0",
        "Actual producer selects the retained-row drop barrier before later new rows")
    for packet in [pa,pb]:
        packet_visibility(packet,"0",.5)
        packet_visibility(packet,"new-0",1.0)
        packet_visibility(packet,"new-1",0.0)
        packet_visibility(packet,"new-2",.75)
        packet_visibility(packet,"new-3",1.0)
    var work:Dictionary=await planned(a,[a.floor],pa);bind_private(a,work)
    check(work.prefix.plan.specs.values().all(func(spec):return spec.join_mask==0),
        "All selected test rows share the actual exposed-face group identity")
    var alternating:bool=false
    for command in work.prefix.bulk_commands:
        if not command.has("group_spans"):continue
        if command.group_spans.size()>=3:alternating=true
    check(alternating,"One new-row run retains private/retained/private registration spans in order")
    # Two new rows share the reintroduced group even though a retained-group
    # span intervenes; the first private registration owns their exact count.
    var future_group:Dictionary=work.prefix.ready_new[str(a.floor.node.get_instance_id())+":new-0"].group
    var repeated:bool=is_same(future_group,work.prefix.ready_new[str(a.floor.node.get_instance_id())+":new-3"].group) and future_group.users==2
    check(repeated and not is_same(future_group,old_group),"Zero-user old group is replaced once and reused across intervening registration spans")
    admit(a,work);publish_floor(a.floor,pa);publish_floor(b.floor,pb)
    publish(a,false,[a.floor]);publish(b,true,b.world.entries)
    check(a.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),"Ordered group spans publish through the prepared path")
    check(not is_same(row_receiver(a.atlas,a.floor,"new-0").group,old_group),"The reappearing key does not resurrect its dropped native group")
    for group in a.atlas.groups.values():
        var users:int=0
        for receiver in a.atlas.receivers:
            if is_same(receiver.group,group):users+=1
        check(group.users==users,"Every private/retained group owns exactly its admitted receiver users")
    check(positions(a.atlas)==positions(b.atlas),"Ordered group publication retains exact complete-planner addresses")
    await draw_pair(a,b,"door-group-drop-reappear")
    await dispose_pair(a,b)

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    var source:Image=pair_source()
    await capacity_case(source,"door-reserve",false,false)
    await capacity_case(source,"door-reserve-normals-cancel",true,true)
    for mode in ["stable","camera","source"]:await cull_case(source,mode)
    await group_case(source)
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"cases":cases,
        "scope":"Exact pre-bind capacity/token ownership and current-frame pixels, cancellation; prepared static cull with live camera/ancestry fallback; ordered private/retained group spans and zero/drop/reappear; native first-draw cell/final framebuffer parity against complete planning. No live gameplay latency claim."}
    FileAccess.open("res://generated/native_atlas_door_preparation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ATLAS_DOOR_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
