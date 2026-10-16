extends "res://tests/native_atlas_growth_checks.gd"
## Private receiving resources and future ground packets versus the unchanged
## complete planner. No gameplay events or modified artwork are used here.
const Preparation=preload("res://presentation/world_preparation.gd")
const FullCapture=preload("res://tests/native_light_capture_reference.gd")
const Construction=preload("res://presentation/actor_construction.gd")
class ActorMaterialHost extends Node3D:
    var camera:Camera3D
    var textures:Dictionary={}
    var resources:Dictionary={}
    var catalog_cache:Dictionary={}
    var source_depth:bool=false
    var source_normals:bool=false
    var character_light_profile:String="original"
    func texture(path:String)->Texture2D:return textures.get(path)

func prepared_dynamic_actor(side:Dictionary,prepare_copy:bool)->Dictionary:
    var host=ActorMaterialHost.new();side.world.add_child(host);host.camera=side.world.camera
    var path="/fixture/staged-actor.png";host.textures[path]=side.texture
    host.catalog_cache[Construction.CharacterGeometry.TABLE]={"records":{}}
    var entry:Dictionary=single(side.world,side.texture,19,Vector2(256,512),true)
    entry.material=ShaderMaterial.new();entry.material.shader=Construction.MODULAR_SHADER
    entry.node.material_override=entry.material;entry.node.hide()
    SourceMaterial.initialize(entry)
    entry.actor_layer={"slot":"body","paths":{"Idle":path}};entry.scale=1.0;entry.placement.scale_x=1.0
    var state:Dictionary=Construction.Conditions.material("actor",[])
    var parameters:Dictionary=Construction.Conditions.parameters(state,host.textures,host.resources)
    var rig={"cell_width":256,"cell_height":512,"facing_rows":{"SW":0}}
    Construction.bind_source(host,entry,rig,path,0,"SW",parameters)
    if prepare_copy:
        var material:Dictionary=side.atlas.prepare_source_binding(entry,{},host,true)
        side.dynamic_output=weakref(material.output.received_material)
        check(side.atlas.adopt_source_binding(material),"Actual producer private actor materials enter the existing atlas preparation owner")
    Construction.bind_source(host,entry,rig,path,1,"SW",parameters)
    return entry

class EmptyPreparationHost extends Node3D:
    var native_light_atlas
    var camera:Camera3D
    var visual_actors:Dictionary={}
    var scenery_consumers:Dictionary={}
    var scenery_batches:Array=[]
    var profile:Dictionary={}

func empty_membership(candidate:Node)->void:
    # Completed empty constructor lanes, before the real prefix phase. The
    # overlap owner now derives removals from the same passive membership base.
    candidate.membership_base={"groups":{},"ground":{}}
    candidate.result={"wanted":{},"ground":{},"actors":{},"packets":{},
        "full_membership":false,"worker_ms":0.0}
    candidate.membership={"upserts":[],"removed":{},"ground_updates":[]}

func empty_static_case(source:Image)->void:
    var a=make_side(source,true,false);var b=make_side(source,true,false)
    for side in [a,b]:
        var actor:Dictionary=single(side.world,side.texture,19,Vector2(512,512),true)
        side.world.entries.append(actor);side.world.actor_entries=[actor]
        publish(side,true,side.world.entries)
    await first_draw(a,b,"empty-static-initial")
    for step in 2:
        var host=EmptyPreparationHost.new();host.native_light_atlas=a.atlas;host.camera=a.world.camera;a.world.add_child(host)
        var candidate=Preparation.new();host.add_child(candidate);candidate.host=host
        empty_membership(candidate)
        var before:Dictionary=positions(a.atlas)
        candidate._begin_atlas_preparation()
        while candidate.atlas_stage=="sources":candidate._step_atlas_overlap()
        check(not candidate.prepared and candidate.phase=="native_receivers" and candidate.atlas_prefix.is_empty()
            and candidate.atlas_jobs.is_empty() and candidate.task==-1 and candidate.atlas_task==-1,
            "Empty static receipt reaches ordinary native readiness without an atlas capture or worker")
        candidate.publish_atlas_receivers()
        check(positions(a.atlas)==before and a.atlas.prepared_delta.is_empty(),
            "Empty static preparation does not publish or replace lighting geometry")
        if step==0:
            var removal=Preparation.new();host.add_child(removal);removal.host=host
            empty_membership(removal)
            removal.membership_base.ground={"floor":{"rows":a.floor.batch_rows,"entries":[a.floor]}}
            removal.result.ground={"floor":[]}
            removal._begin_atlas_preparation()
            check(not removal.prepared and removal.phase=="atlas_overlap"
                and removal.atlas_prefix.removed_sources.has(a.floor.node.get_instance_id()),
                "A real static removal still enters exact atlas preparation")
        for side in [a,b]:
            if step==0:
                var actor:Dictionary=side.world.actor_entries[0]
                actor.node.position+=Vector3(.4,.3,0)
                SourceMaterial.set_parameter(actor,"source_tint",Color(.6,1,.8,1))
                side.world.entries[1].scenery_value=0.0
                side.world.camera.position.x+=.5;side.world.camera.size+=.25
            else:
                var actor:Dictionary=single(side.world,side.texture,20,Vector2(512,512),true)
                side.world.entries.append(actor);side.world.actor_entries.append(actor)
                side.world.camera.rotate_y(.15)
        publish(a,false,[]);publish(b,true,b.world.entries)
        check(a.atlas.dynamic_receivers.size()==step+1,
            "Ordinary synchronization retains or admits the actual dynamic actor after an empty static receipt")
        await first_draw(a,b,"empty-static-current-samples-"+str(step))
        host.queue_free();await process_frame
    a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free();await process_frame

func retire_private(work:Dictionary)->void:
    var retirement={"blocked":false,"payloads":[],"directories":[],"unused":[],"active":{}}
    Atlas.Delta.retire_candidate(retirement,work.prefix,work.bindings,true)
    while not Atlas.Delta.retire_candidate_step(retirement).get("done",false):pass

func prepare_future(side:Dictionary,entries:Array,packet:Dictionary,label:String,missing_shell:bool=false,early_capture:bool=false)->Dictionary:
    var bindings:Dictionary={};var jobs:Array=[]
    var node_materials:Dictionary={}
    for entry in entries:
        node_materials[entry.node.get_instance_id()]=entry.node.material_override
        var snapshot:Dictionary=entry.duplicate()
        var future:Dictionary=packet if entry==side.floor else {}
        if not future.is_empty():
            snapshot.ground_version=entry.ground_version+1;snapshot.batch_rows=future.rows
            snapshot.ground_indices=future.indices;snapshot.ground_packets=future.packets
            snapshot.ground_buffer=future.buffer;snapshot.scenery_values=future.values;snapshot.placement=future.rows[0]
        var prepared:Dictionary=side.atlas.prepare_source_binding(entry,snapshot,side.world,true)
        check(not prepared.is_empty(),label+" source has a private receiving/output owner")
        prepared.receiver_parent=side.atlas.projection_root
        bindings[entry.node.get_instance_id()]=prepared
        jobs.append({"entry":entry,"prepared":prepared,"packet":future,
            "rows":future.geometry_changes.changed if not future.is_empty() else [entry.placement]})
    if missing_shell:
        var value:Dictionary=bindings[entries[0].node.get_instance_id()]
        side.atlas.prepare_source_row(value,entries[0].placement,value.receiver_parent,side.atlas.published_supports,1.0)
        var id:String=value.receivers.keys()[0]
        side.atlas.dispose_receiver(value.receivers[id]);value.receivers.erase(id)
    var reference:Dictionary=FullCapture.begin_candidate(side.atlas,jobs,{},side.world)
    while not FullCapture.capture_candidate(side.atlas,reference,side.world):pass
    FullCapture.compute_candidate(reference)
    var prefix:Dictionary=Atlas.Delta.begin_candidate(side.atlas,[] if early_capture else jobs,{},side.world)
    check(prefix.output_region.get_object()!=side.atlas,
        label+" private worker helper does not retain its live atlas owner")
    if early_capture:
        # The first canonical source is deliberately still pending while later
        # actual sources arrive backwards. No synthetic identity is introduced.
        for index in range(jobs.size()-1,0,-1):
            check(Atlas.Delta.capture_source_job(side.atlas,prefix,side.world,jobs[index]),
                label+" ready source capture can overlap an earlier unfinished scene source")
        check(not prefix.get("complete",false) and not prefix.get("bound",false),
            label+" partial source arrival cannot compute or publish a future atlas")
        Atlas.Delta.seal_candidate_jobs(side.atlas,prefix,jobs)
    while not Atlas.Delta.capture_candidate(side.atlas,prefix,side.world):pass
    var task:int=WorkerThreadPool.add_task(Atlas.Delta.compute_candidate.bind(prefix),false,"Qualify private atlas plan")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    check(prefix.get("error","")==reference.get("error",""),label+" sparse capture has the frozen complete-prefix outcome")
    if prefix.get("complete",false) and reference.get("complete",false):
        if early_capture:
            check(prefix.source_patches.keys()==jobs.map(func(job):return job.entry.node.get_instance_id())
                and prefix.next_order==reference.next_order,
                label+" canonical sealing restores exact source traversal and final next-source order")
        var captured:int=0
        var target:Vector2=Vector2(side.atlas.MAX_SIZE,prefix.plan.next_height)
        for id in bindings:
            if not prefix.bulk_sources.has(id):continue
            captured+=1
            check(is_same(bindings[id].receivers,prefix.bulk_sources[id].binding_receivers)
                and is_same(bindings[id].specs,prefix.bulk_sources[id].binding_specs),
                label+" worker completes the private source directories before scene binding")
            var output:Dictionary=prefix.outputs[id]
            check(output.region_target==target and output.received_material.get_shader_parameter("source_crop")==prefix.source_patches[id].crop.uv,
                label+" private output owns the final planned region and exact crop before scene binding")
            check(bindings[id].entry.node.material_override==node_materials[id],
                label+" worker output finalization never changes the live or hidden source Node material")
        check(prefix.worker_source_directories==captured and prefix.source_bind_ids.all(func(id):return not bindings.has(id)),
            label+" scene source construction contains only uncaptured incident fallback sources")
        var plan:Dictionary=prefix.plan.duplicate();var expected:Dictionary=reference.plan.duplicate()
        # Sparse capture owns only incident cells. Compare its effective result
        # over the untouched published base against the frozen complete map.
        var supports:Dictionary=side.atlas.published_supports.duplicate()
        supports.merge(plan.supports,true)
        for cell in plan.owners:
            if plan.owners[cell].is_empty():supports.erase(cell)
        plan.supports=supports
        for field in ["specs_ms","reservations_ms"]:plan.erase(field);expected.erase(field)
        check(plan==expected and prefix.bind_ids==reference.bind_ids,label+" effective supports/specs/reservations/order equal frozen complete capture")
        for id in prefix.floor_ids:
            var expected_addresses:Dictionary=reference.source_patches[id].prepared_addresses.duplicate()
            # The frozen producer also carried an eager per-receiver slot
            # repair list. Current consumers resolve the one floor directory.
            expected_addresses.erase("indices")
            check(prefix.source_patches[id].prepared_addresses==expected_addresses,label+" complete future floor addresses equal frozen complete capture")
    while not Atlas.Delta.prepare_candidate_binding(side.atlas,prefix,bindings):pass
    check(not prefix.has("error"),label+" private binding completes for every exact source")
    return {"prefix":prefix,"bindings":bindings}

func staged_case(source:Image,label:String,cap:bool,normals:bool,stale:bool=false,view_change:String="",changed_visibility:bool=false,extra_mode:String="",early_capture:bool=false)->void:
    var a=make_side(source,cap,normals);var b=make_side(source,cap,normals)
    if extra_mode=="dynamic_replace":
        for side in [a,b]:
            var actor:Dictionary=prepared_dynamic_actor(side,false)
            actor.node.show()
            side.world.entries.append(actor);side.world.actor_entries=[actor]
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    await first_draw(a,b,label+"-initial")
    var before:Image=a.view.get_texture().get_image()
    var old_positions:Dictionary=positions(a.atlas)
    var initial_atlas_size:Vector2i=a.atlas.viewport.size
    var old_buffer:PackedFloat32Array=a.floor.ground_buffer.duplicate()
    var old_output:ShaderMaterial=a.floor.received_material
    var candidate=Node3D.new();candidate.visible=false;a.world.add_child(candidate)
    var add_a:Array=[];var add_b:Array=[]
    for index in range(14,16):
        var entry:Dictionary=single(a.world,a.texture,index)
        entry.node.reparent(candidate,false);add_a.append(entry)
        add_b.append(single(b.world,b.texture,index));add_b.back().node.hide()
    if extra_mode=="water":
        for entry in [add_a[1],add_b[1]]:
            var material=ShaderMaterial.new();material.shader=WaterSource
            var parameters={"mask_texture":a.texture,"ripple_texture":a.texture,"cell":Vector2(512,512),"image_scale":1.0,
                "shallow_color":Color(.2,.4,.6,1),"deep_color":Color(.1,.2,.4,1),"tint":Color.WHITE,
                "uv_scale":1.0,"ripple_pan":Vector2(.5,0),"ripple_tiling":1.0,"ripple_amount":.3,
                "overall_alpha":1.0,"alpha_cutoff":.001,"sheen_sharpness":2.0}
            entry.material=material;entry.node.material_override=material;entry.role="terrain"
            SourceMaterial.initialize(entry);SourceMaterial.apply(entry,parameters)
            entry.placement={"id":"water-new","kind":"terrain","material":"water","position":[0,2],"base_height_steps":0}
    var rows_a:Array=a.floor.batch_rows.duplicate(true)
    var rows_b:Array=b.floor.batch_rows.duplicate(true)
    if extra_mode not in ["plain_append","group_replaced"]:
        rows_a[0].base_height_steps=1;rows_b[0].base_height_steps=1
    for rows in [rows_a,rows_b]:
        var template:Dictionary=rows[0].duplicate(true)
        if extra_mode=="removed_floor":rows.remove_at(1)
        if extra_mode=="replace_floor":rows.clear()
        for index in 2:
            var row:Dictionary=template.duplicate(true)
            row.id="new-"+str(index);row.position=[2+index*2,2];row.base_height_steps=0
            rows.append(row)
    if extra_mode in ["append","prepared_dynamic_append"]:
        for side in [a,b]:side.late_actor=prepared_dynamic_actor(side,false)
    var packet_a:Dictionary=prepared_floor_packet(a.floor,[],a.atlas.floor_address_token(a.floor),rows_a)
    var packet_b:Dictionary=prepared_floor_packet(b.floor,[],b.atlas.floor_address_token(b.floor),rows_b)
    if changed_visibility:
        for packet in [packet_a,packet_b]:
            var index:int=packet.indices["new-1"]
            packet.values[index]=1.0;packet.buffer[index*20+16]=1.0
            packet.packets["new-1"].data[16]=1.0
    var job_entries:Array=add_a+[a.floor]
    if extra_mode in ["append","prepared_dynamic_append"]:job_entries.append(a.late_actor)
    if extra_mode=="dynamic_replace":
        for side in [a,b]:
            var actor:Dictionary=side.world.actor_entries[0].duplicate()
            side.next_actor=actor
        job_entries.append(a.next_actor)
    var work:Dictionary=await prepare_future(a,job_entries,packet_a,label,extra_mode=="missing_shell",early_capture)
    var prefix:Dictionary=work.prefix;var bindings:Dictionary=work.bindings
    await process_frame;await RenderingServer.frame_post_draw
    check(before.get_data()==a.view.get_texture().get_image().get_data(),label+" private preparation exposes no pixels")
    check(positions(a.atlas)==old_positions and a.floor.ground_buffer==old_buffer and a.floor.received_material==old_output,
        label+" private preparation changes no live addresses, buffers or output material")
    check(a.atlas.prepared_source_bindings.is_empty(),label+" preparation remains exclusively candidate-owned")
    if extra_mode=="group_replaced":
        for side in [a,b]:
            var group:Dictionary=row_receiver(side.atlas,side.floor,str(side.floor.batch_rows[0].id)).group
            group.material=group.material.duplicate(true)
            for receiver in side.atlas.receivers:
                if is_same(receiver.group,group):side.atlas.set_receiver_material(receiver,group.material)
    if extra_mode=="changed_base":
        for side in [a,b]:
            var actor:Dictionary=prepared_dynamic_actor(side,false);actor.node.show()
            side.world.actor_entries.append(actor);side.world.entries.append(actor);publish(side,false,[actor])
    if extra_mode=="hover_after_prepare":
        for entry in [add_a[0],add_b[0],a.floor,b.floor]:SourceMaterial.set_parameter(entry,"highlighted",true)
    if extra_mode=="retained_output_changed":
        for side in [a,b]:
            var retained:Dictionary=side.world.entries[1]
            SourceMaterial.set_parameter(retained,"source_tint",Color(.4,.8,.6,1))
            SourceMaterial.set_parameter(retained,"highlighted",true)
    if extra_mode=="water":
        for entry in [add_a[1],add_b[1]]:SourceMaterial.set_parameter(entry,"displayed_time_seconds",2.5)
    if stale:
        for entry in [add_a[0],add_b[0]]:
            SourceMaterial.set_parameter(entry,"wall_opacity",.41)
            SourceMaterial.set_parameter(entry,"colour_texture",ImageTexture.create_from_image(source),true)
    if not view_change.is_empty():
        for side in [a,b]:
            if view_change=="basis":side.world.camera.rotate_y(.25)
            else:side.world.camera.position.x+=.75;side.world.camera.size+=.5
            publish(side,false,[])
    var reject:bool=stale or not view_change.is_empty() or extra_mode in ["changed_base","group_replaced"]
    if reject:
        var displayed:Dictionary=positions(a.atlas)
        var buffer:PackedFloat32Array=a.floor.node.multimesh.buffer
        var output:ShaderMaterial=a.floor.received_material
        var members:int=a.world.entries.size()
        check(not Atlas.Delta.candidate_base_matches(a.atlas,prefix,a.world),label+" stale candidate rejects before display mutation")
        check(positions(a.atlas)==displayed and a.floor.node.multimesh.buffer==buffer and a.floor.received_material==output
            and a.world.entries.size()==members and not add_a[0].node.is_visible_in_tree(),label+" rejected cut retains the current displayed resources and membership")
        retire_private(work)
        # A fresh capture uses the current base, view and source version. The
        # desired floor packet stays private until this replacement is admitted.
        work=await prepare_future(a,job_entries,packet_a,label+"-retry")
        prefix=work.prefix;bindings=work.bindings
    check(Atlas.Delta.candidate_base_matches(a.atlas,prefix,a.world),label+" exact private work passes preflight")
    var prepared_nodes:Dictionary={};var prepared_outputs:Dictionary={}
    for receiver in prefix.ready_list+prefix.ready_retained:prepared_nodes[receiver.id]=Atlas.receiver_handle(receiver)
    for id in prefix.outputs:prepared_outputs[id]=prefix.outputs[id].get("received_material")
    prefix.admitted=true
    for value in bindings.values():check(a.atlas.adopt_source_binding(value),label+" exact private source transfers ownership once")
    a.atlas.prepared_delta=prefix
    for entry in add_a:entry.node.reparent(a.world,false)
    for entry in add_b:entry.node.show()
    a.world.entries.append_array(add_a);b.world.entries.append_array(add_b)
    if extra_mode in ["append","prepared_dynamic_append"]:
        for side in [a,b]:
            side.world.entries.append(side.late_actor);side.world.actor_entries.append(side.late_actor);side.late_actor.node.show()
    if extra_mode=="dynamic_replace":
        for side in [a,b]:
            var index:int=side.world.entries.find(side.world.actor_entries[0])
            side.world.entries[index]=side.next_actor;side.world.actor_entries=[side.next_actor]
    publish_floor(a.floor,packet_a);publish_floor(b.floor,packet_b)
    publish(a,false,job_entries);publish(b,true,b.world.entries)
    check(a.atlas.last_reconcile_phases.get("prepared_prefix_specs",0)>0
        and a.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),label+" accepted cut publishes the prepared plan without recovery planning")
    check(a.atlas.prepared_source_bindings.is_empty(),label+" publication releases temporary preparation ownership")
    for id in prepared_nodes:check(Atlas.receiver_handle(a.atlas.receiver_index[id])==prepared_nodes[id],label+" publication adopts the exact prepared receiver node")
    for id in prepared_outputs:
        check(a.atlas.entry_specs[id].entry.received_material==prepared_outputs[id],label+" publication adopts the exact prepared output material")
    if extra_mode=="hover_after_prepare":
        for entry in [add_a[0],a.floor]:check(entry.received_material.get_shader_parameter("highlighted")==true,label+" current hover reaches the adopted output")
    check(a.atlas.viewport.size==Vector2i(8192,initial_atlas_size.y*2) and a.atlas.viewport.size==b.atlas.viewport.size,label+" prepared append grows using the unchanged bounded planner")
    check(positions(a.atlas)==positions(b.atlas),label+" every reserved pixel address equals complete planning")
    var first_group:Dictionary=row_receiver(a.atlas,a.floor,"new-0").group
    var second_group:Dictionary=row_receiver(a.atlas,a.floor,"new-1").group
    check(is_same(first_group,second_group)!=changed_visibility,label+" shared floor material splits only for the actual changed visibility")
    for index in a.atlas.receivers.size():
        var receiver:Dictionary=a.atlas.receivers[index]
        check(receiver.list_index==index,label+" admitted receiver owns its exact live list offset")
    for index in a.atlas.static_receivers.size():check(a.atlas.static_receivers[index].partition_index==index,label+" admitted static receiver owns its exact partition offset")
    for group in a.atlas.groups.values():
        check(group.users==a.atlas.receivers.filter(func(receiver):return is_same(receiver.group,group)).size(),label+" each material group owns exactly its actual receiver count")
    if extra_mode=="water":
        for side in [a,b]:
            var receiver:Dictionary=row_receiver(side.atlas,side.world.entries.filter(func(entry):return entry.placement.id=="water-new")[0])
            check(receiver.group.material.get_shader_parameter("receiver_world_origin")==receiver.entry.node.global_position,label+" prepared water retains the actual optical support origin")
    transport(a,label);transport(b,label+" reference")
    await first_draw(a,b,label+"-accepted")
    var cancelled=Node3D.new();cancelled.visible=false;a.world.add_child(cancelled)
    var unused:Dictionary=single(a.world,a.texture,18);unused.node.reparent(cancelled,false)
    var discarded:Dictionary=a.atlas.prepare_source_binding(unused,unused.duplicate(),a.world)
    a.atlas.prepare_source_row(discarded,unused.placement,cancelled,a.atlas.published_supports,1.0)
    var node_ref:WeakRef=weakref(Atlas.receiver_handle(discarded.receivers.values()[0]))
    var count:int=a.atlas.receivers.size()
    cancelled.queue_free();discarded={};await process_frame;await process_frame
    check(node_ref.get_ref()==null and a.atlas.receivers.size()==count,label+" cancellation releases private nodes without publishing membership")
    candidate.queue_free();a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free();await process_frame

func flame_shell_case(source:Image,label:String,cap:bool,normals:bool)->void:
    var a=make_side(source,cap,normals);var b=make_side(source,cap,normals)
    publish(a,true,a.world.entries);publish(b,true,b.world.entries)
    await first_draw(a,b,label+"-initial")
    var images:Array[Image]=[]
    for index in 2:
        var image=Image.create(64,64,false,Image.FORMAT_RGBA8)
        image.fill_rect(Rect2i(10+index*9,6,26,52),Color(1,.25+index*.35,.08,.75))
        images.append(image)
    var frames=Texture2DArray.new();check(frames.create_from_images(images)==OK,label+" original fixture frames load")
    var added:Array=[]
    for side in [a,b]:
        var entry:Dictionary=single(side.world,side.texture,16,Vector2(64,64))
        var material=ShaderMaterial.new();material.shader=Sources.FIXTURE_FLAME_SHADER
        entry.material=material;entry.node.material_override=material;entry.role="body"
        SourceMaterial.initialize(entry);SourceMaterial.apply(entry,{"frames":frames,"frame_index":0})
        entry.node.position=Vector3(0,1.5,0);entry.record={"path":"fixture","rect":[0,0,64,64]}
        added.append(entry)
    var candidate=Node3D.new();candidate.visible=false;a.world.add_child(candidate)
    added[0].node.reparent(candidate,false);added[1].node.hide()
    var work:Dictionary=await prepare_future(a,[added[0]],{},label)
    var prefix:Dictionary=work.prefix;var bindings:Dictionary=work.bindings
    var receiver:Dictionary=prefix.ready_list[0]
    var shell:Sprite2D=receiver.node;var shell_id:int=shell.get_instance_id()
    var material_id:int=receiver.group.material.get_instance_id()
    var output_id:int=prefix.outputs[added[0].node.get_instance_id()].received_material.get_instance_id()
    check(not shell.visible and not added[0].node.is_visible_in_tree(),label+" complete private flame receiver exposes no visible pixels")
    await first_draw(a,b,label+"-private")
    # Continuous frame sampling can advance while preparation is private.
    for entry in added:SourceMaterial.set_parameter(entry,"frame_index",1)
    check(Atlas.Delta.candidate_base_matches(a.atlas,prefix,a.world),label+" continuous flame frame does not invalidate structural admission")
    prefix.admitted=true
    for value in bindings.values():check(a.atlas.adopt_source_binding(value),label+" exact private flame source is adopted")
    a.atlas.prepared_delta=prefix
    for index in 2:
        var side:Dictionary=a if index==0 else b
        var entry:Dictionary=added[index]
        if entry.node.get_parent()!=side.world:entry.node.reparent(side.world,false)
        entry.node.show();side.world.entries.append(entry);side.world.fixture_entries.append(entry)
    publish(a,false,[added[0]]);publish(b,true,b.world.entries)
    check(row_receiver(a.atlas,added[0]).node.get_instance_id()==shell_id,label+" first actual sample adopts the prepared flame node")
    check(a.atlas.last_reconcile_phases.get("prepared_prefix_specs",0)>0
        and a.atlas.last_reconcile_phases.get("delta_fallback","").is_empty(),label+" flame publishes its exact prepared plan")
    check(row_receiver(a.atlas,added[0]).group.material.get_instance_id()==material_id and added[0].received_material.get_instance_id()==output_id,
        label+" first draw uses the private receiving/output material owners")
    if not normals:
        check(row_receiver(a.atlas,added[0]).group.material.get_shader_parameter("frame_index")==1,label+" receiving material uses the current fixture frame")
    await first_draw(a,b,label+"-current-frame")
    for entry in added:SourceMaterial.set_parameter(entry,"frame_index",0)
    publish(a,false,[]);publish(b,true,b.world.entries)
    await first_draw(a,b,label+"-next-frame")
    candidate.queue_free();a.atlas.close();b.atlas.close();a.view.queue_free();b.view.queue_free();await process_frame

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    var source:Image=pair_source()
    await empty_static_case(source)
    await flame_shell_case(source,"flame-shell-ldr",false,false)
    await flame_shell_case(source,"flame-shell-capped",true,false)
    await flame_shell_case(source,"flame-shell-normals",true,true)
    await staged_case(source,"staged-ldr",false,false)
    await staged_case(source,"staged-capped",true,false)
    await staged_case(source,"staged-normals",true,true)
    await staged_case(source,"staged-version-rejection",true,false,true)
    await staged_case(source,"staged-view-rejection",true,false,false,"basis")
    await staged_case(source,"staged-pan-reuse",true,false,false,"pan")
    await staged_case(source,"staged-row-visibility",true,false,false,"",true)
    await staged_case(source,"staged-dynamic-append",true,false,false,"",false,"append")
    await staged_case(source,"staged-base-rejection",true,false,false,"",false,"changed_base")
    await staged_case(source,"staged-ground-removal",true,false,false,"",false,"removed_floor")
    await staged_case(source,"staged-whole-floor-replacement",true,false,false,"",false,"replace_floor")
    await staged_case(source,"staged-water-origin",true,false,false,"",false,"water")
    await staged_case(source,"staged-dynamic-replacement",true,false,false,"",false,"dynamic_replace")
    await staged_case(source,"staged-bulk-append",true,false,false,"",false,"plain_append")
    await staged_case(source,"staged-bulk-group-replaced",true,false,false,"",false,"group_replaced")
    await staged_case(source,"staged-bulk-missing-shell",true,false,false,"",false,"missing_shell")
    await staged_case(source,"staged-current-hover",true,false,false,"",false,"hover_after_prepare")
    await staged_case(source,"staged-prepared-actor-extra",true,false,false,"",false,"prepared_dynamic_append")
    await staged_case(source,"staged-retained-output-changed",true,false,false,"",false,"retained_output_changed")
    await staged_case(source,"staged-early-row-visibility",true,false,false,"",true,"",true)
    await staged_case(source,"staged-early-ground-removal",true,false,false,"",false,"removed_floor",true)
    await staged_case(source,"staged-early-dynamic-append",true,false,false,"",false,"append",true)
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"cases":cases,
        "scope":"Private future source/spec/material/receiver preparation; exact source-version admission; changed ground packets; growth, cancellation and first-draw byte parity against complete original planning. No gameplay latency claim."}
    FileAccess.open("res://generated/native_atlas_staged_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ATLAS_STAGED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
