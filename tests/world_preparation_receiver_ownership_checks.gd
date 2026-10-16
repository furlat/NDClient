extends SceneTree
## Real candidate preparation/publication/retirement with small mathematical
## source images. This qualifies ownership and bounded cleanup, not pixels/FPS.
const Preparation=preload("res://presentation/world_preparation.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
var checks=0
var failures:Array=[]

class Probe extends "res://play.gd":
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false)
        add_child(context_menu)
        camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.position.z=10;add_child(camera)
    func _process(_delta:float)->void:pass

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("RECEIVER_OWNERSHIP_FAIL ",label)

func _initialize()->void:run.call_deferred()

func make_host()->Probe:
    var host=Probe.new();root.add_child(host)
    host.native_light_atlas.attach(host)
    var image=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
    host.source_images={"fixture":image}
    return host

func prepare(host:Probe,count:int,remember_first:bool=false,flames:bool=false,bind:bool=true)->Dictionary:
    var candidate=Preparation.new();host.add_child(candidate);host.pending_world=candidate
    candidate.host=host;candidate.visible=false;candidate.epoch=host.timeline.initialization_revision
    candidate.quarter=host.quarter
    candidate.result={"visibility":{},"visibility_changes":{},"supports":{},"worker_ms":0.0}
    var source_refs:Array=[]
    for index in count:
        var node=MeshInstance3D.new();node.mesh=QuadMesh.new();candidate.add_child(node)
        var material=ShaderMaterial.new();material.shader=host.FIXTURE_FLAME_SHADER if flames else host.ENVIRONMENT_SHADER
        node.material_override=material
        var row={"id":"fixture-"+str(index),"kind":"wall","position":[index,0],"base_height_steps":0}
        var entry={"id":row.id,"node":node,"material":material,"cell":Vector2(4,4),
            "record":{"path":"fixture","rect":[0,0,4,4]},"placement":row,"role":"wall","source_version":1}
        SourceMaterial.initialize(entry)
        if flames:
            var frames=Texture2DArray.new();var images:Array[Image]=[host.source_images.fixture]
            check(frames.create_from_images(images)==OK,"Fixture flame uses an explicit native source frame")
            SourceMaterial.apply(entry,{"frames":frames,"frame_index":0})
        else:SourceMaterial.apply(entry,{"colour_texture":host.native_light_atlas.white,"colour_size":Vector2(4,4),"colour_rect":Vector4(0,0,4,4)})
        candidate.entries.append(entry)
        if not remember_first or index>0:candidate.result.visibility[row.id]=true
        candidate.atlas_jobs.append({"entry":entry,"rows":[row],"packet":{}})
        source_refs.append(weakref(node))
    while candidate.atlas_cursor<candidate.atlas_jobs.size():candidate._prepare_atlas_receiver()
    if bind:finish_receivers(host,candidate)
    var refs:Array=receiver_refs(host,candidate)
    check(refs.size()==count if bind else refs.is_empty(),
        "Receiver resources exist only after the actual final planner and binding stage")
    check(refs.all(func(ref):return hidden_receiver(host,ref.get_ref())),
        "Prepared static draws stay under a hidden private batch; dynamic Nodes stay hidden under the actual parent")
    check(host.native_light_atlas.receivers.is_empty() and host.native_light_atlas.prepared_source_bindings.is_empty(),
        "Unpublished receiving resources do not enter displayed atlas ownership")
    return {"candidate":candidate,"receivers":refs,"sources":source_refs}

func finish_receivers(host:Probe,candidate:Node)->void:
    var prefix:Dictionary=Preparation.AtlasDelta.begin_candidate(host.native_light_atlas,candidate.atlas_jobs,{},host)
    while not Preparation.AtlasDelta.capture_candidate(host.native_light_atlas,prefix,host):pass
    Preparation.AtlasDelta.compute_candidate(prefix)
    check(not prefix.has("error") and prefix.get("complete",false),"Actual private receiver planner completes")
    while not Preparation.AtlasDelta.prepare_candidate_binding(host.native_light_atlas,prefix,candidate.atlas_shells):pass
    check(not prefix.has("error") and prefix.get("bound",false),"Actual final receiving bindings complete")
    candidate.atlas_prefix=prefix

func receiver_refs(host:Probe,candidate:Node)->Array:
    var refs:Array=[]
    for binding in candidate.atlas_shells.values():
        for receiver in binding.receivers.values():refs.append(weakref(host.native_light_atlas.receiver_handle(receiver)))
    return refs

func hidden_receiver(host:Probe,handle)->bool:
    if handle is Node:return handle.get_parent()==host.native_light_atlas.projection_root and not handle.visible
    return handle.batch!=null and handle.batch.rid.is_valid() and not handle.batch.adopted and handle.parent==handle.batch.rid

func released_handle(ref:WeakRef)->bool:
    var handle=ref.get_ref()
    return handle==null or (not handle is Node and not handle.rid.is_valid())

func tracked_handles(fixture:Dictionary)->Array:
    var refs:Array=fixture.receivers.duplicate();refs.append_array(fixture.sources)
    refs.append(weakref(fixture.candidate))
    var batches:Dictionary={}
    for ref in fixture.receivers:
        var handle=ref.get_ref()
        if handle!=null and not handle is Node and handle.batch!=null:
            batches[handle.batch.get_instance_id()]=weakref(handle.batch)
    refs.append_array(batches.values())
    return refs

func live_handles(refs:Array)->int:
    var count:int=0
    for ref in refs:
        var handle=ref.get_ref()
        if handle!=null and (handle is Node or handle.rid.is_valid()):count+=1
    return count

func drain(host:Probe,label:String,tracked:Array=[])->void:
    var frames=0
    while not host.retiring_views.is_empty() and frames<80:
        await process_frame
        var before:int=host.retiring_node_count
        var native_before:int=live_handles(tracked)
        host._dispose_views()
        var after:int=host.retiring_node_count
        check(before-after<=16,label+" each cleanup slice releases at most sixteen native nodes while private metadata drains")
        if not tracked.is_empty():
            check(native_before-live_handles(tracked)<=16,label+" actual scene, draw and final batch-root disposal stays within sixteen native handles")
        var native_after:int=live_handles(tracked)
        host._dispose_views()
        check(host.retiring_node_count==after and live_handles(tracked)==native_after,label+" a repeated same-frame call cannot exceed the slice")
        frames+=1
    check(host.retiring_node_count==0 and host.retiring_views.is_empty(),label+" cleanup drains without orphaned handles")

func dispose(host:Probe)->void:
    host.queue_free();await process_frame;await process_frame

func cancelled(mode:String,count:int=41)->void:
    var host=make_host();var fixture=prepare(host,count)
    var tracked:Array=tracked_handles(fixture)
    var displayed=Sprite2D.new();host.native_light_atlas.projection_root.add_child(displayed)
    displayed.visible=true
    var displayed_ref=weakref(displayed)
    # A retained source handle does not transfer ownership of a live external
    # node. Only explicitly candidate-owned receiver records may retire there.
    var retained=Node3D.new();host.add_child(retained)
    fixture.candidate.entries.append({"node":retained})
    var retained_ref=weakref(retained)
    if mode=="epoch":
        host.timeline.initialization_revision+=1;host._step_world_preparation()
    elif mode=="quarter":
        host.quarter=(host.quarter+1)%4;host._step_world_preparation()
    else:host._discard_world_preparation()
    check(host.pending_world==null,mode+" discards the candidate through the real Play boundary")
    check(host.retiring_node_count==1 and fixture.candidate.atlas_retirement.unused.size()==count,
        mode+" retains one scene root and every private draw on their distinct retirement lanes")
    check(fixture.receivers.all(func(ref):return ref.get_ref()!=null and hidden_receiver(host,ref.get_ref())),mode+" cancellation does not synchronously free or expose future receivers")
    await drain(host,mode,tracked)
    check(fixture.receivers.all(func(ref):return released_handle(ref)) and fixture.sources.all(func(ref):return ref.get_ref()==null),mode+" source and external receiver nodes are actually destroyed")
    check(displayed_ref.get_ref()!=null and displayed.visible,mode+" displayed canvas siblings remain owned and visible")
    check(retained_ref.get_ref()!=null,mode+" an ordinary retained source handle cannot retire a live external node")
    await dispose(host)

func accepted()->void:
    var host=make_host();var fixture=prepare(host,3)
    var candidate:Node=fixture.candidate
    candidate.publish_atlas_receivers()
    check(candidate.atlas_shells.is_empty() and host.native_light_atlas.prepared_source_bindings.size()==3,
        "successful publication transfers each private receiver binding exactly once")
    check(fixture.receivers.all(func(ref):return hidden_receiver(host,ref.get_ref())),
        "binding-directory adoption leaves the private batch hidden until ordinary atlas visibility admission")
    var bindings:Array=host.native_light_atlas.prepared_source_bindings.values()
    var receivers:Array=[]
    for binding in bindings:receivers.append_array(binding.receivers.values())
    check(receivers.size()==3 and receivers.all(func(receiver):return not host.native_light_atlas._visibility(receiver,Rect2(-10000,-10000,20000,20000))),
        "Actual scene visibility cannot expose a batch while its future sources are still unpublished")
    for entry in candidate.entries:entry.node.reparent(host,false)
    check(receivers.all(func(receiver):return host.native_light_atlas._visibility(receiver,Rect2(-10000,-10000,20000,20000)))
        and fixture.receivers.all(func(ref):return ref.get_ref().batch.adopted and ref.get_ref().visible),
        "Only current scene visibility at the admitted source cue attaches and exposes the completed batch")
    candidate.admitted=true;host._finish_world_preparation()
    await process_frame;host._dispose_views()
    check(host.retiring_node_count>0 and fixture.receivers.all(func(ref):return ref.get_ref()!=null)
        and fixture.sources.all(func(ref):return ref.get_ref()!=null),
        "retirement waits for atlas consumption without destroying transferred receiving or displayed source nodes")
    host.native_light_atlas._release_prepared_receivers()
    check(fixture.receivers.all(func(ref):return ref.get_ref()!=null),"atlas release transfers unused nodes without synchronous destruction")
    await drain(host,"accepted")
    check(fixture.receivers.all(func(ref):return released_handle(ref)),"bounded retirement releases transferred unused bindings")
    check(fixture.sources.all(func(ref):return ref.get_ref()!=null),"bounded metadata cleanup never releases displayed sources")
    await dispose(host)

func rejected(free_parent:bool)->void:
    var host=make_host();var fixture=prepare(host,3)
    var candidate:Node=fixture.candidate
    var old_parent:Node=host.native_light_atlas.projection_root
    var replacement=Node2D.new();host.native_light_atlas.viewport.add_child(replacement)
    host.native_light_atlas.projection_root=replacement
    if free_parent:old_parent.free()
    for binding in candidate.atlas_shells.values():
        check(not host.native_light_atlas.adopt_source_binding(binding),"Actual atlas admission rejects the replaced canvas parent")
    check(candidate.atlas_shells.size()==3 and host.native_light_atlas.prepared_source_bindings.is_empty(),
        "replaced or freed receiver parent is rejected without transferring candidate ownership")
    check(fixture.receivers.all(func(ref):return hidden_receiver(host,ref.get_ref())),
        "Replacing or freeing the live parent cannot expose an unadopted private batch")
    var tracked:Array=tracked_handles(fixture)
    host._discard_world_preparation();await drain(host,"rejected",tracked)
    check(fixture.receivers.all(func(ref):return released_handle(ref)),"rejected receiver bindings leave no external orphan")
    check(is_instance_valid(replacement) and replacement.get_child_count()==0,"rejection never reparents stale nodes into the new atlas")
    await dispose(host)

func worker_cancelled()->void:
    var host=make_host();var fixture=prepare(host,41,false,false,false)
    var candidate:Node=fixture.candidate
    candidate.atlas_prefix=Preparation.AtlasDelta.begin_candidate(host.native_light_atlas,candidate.atlas_jobs,{},host)
    while not Preparation.AtlasDelta.capture_candidate(host.native_light_atlas,candidate.atlas_prefix,host):pass
    candidate.phase="atlas_prefix_wait"
    var release=Semaphore.new()
    var compute:Callable=Preparation.AtlasDelta.compute_candidate.bind(candidate.atlas_prefix)
    candidate.task=WorkerThreadPool.add_task(func():release.wait();compute.call(),false,"Cancelled private atlas prefix")
    host.timeline.initialization_revision+=1
    host._step_world_preparation()
    check(host.pending_world==candidate,"Epoch cancellation does not join an unfinished planner on the scene thread")
    release.post()
    while not WorkerThreadPool.is_task_completed(candidate.task):await process_frame
    for receiver in candidate.atlas_prefix.ready_style.values():
        fixture.receivers.append(weakref(host.native_light_atlas.receiver_handle(receiver)))
    var tracked:Array=tracked_handles(fixture)
    check(fixture.receivers.all(func(ref):return hidden_receiver(host,ref.get_ref())),
        "A completed epoch-stale worker still owns only hidden private receiving draws")
    var frames:int=0
    while host.pending_world!=null and frames<80:
        await process_frame;host._step_world_preparation();frames+=1
    check(host.pending_world==null,"epoch cancellation waits for passive prefix completion then discards its owner")
    check(host.native_light_atlas.receivers.is_empty() and host.native_light_atlas.prepared_source_bindings.is_empty()
        and host.native_light_atlas.prepared_delta.is_empty(),"cancelled worker never publishes future receiver maps or address packets")
    await drain(host,"worker cancellation",tracked)
    check(fixture.receivers.all(func(ref):return released_handle(ref)) and fixture.sources.all(func(ref):return ref.get_ref()==null),
        "worker cancellation retires every private source and external receiver")
    await dispose(host)

func future_visibility()->void:
    var host=make_host();var fixture=prepare(host,2,true,false,false)
    var candidate:Node=fixture.candidate
    var original:Dictionary=candidate.entries[0]
    var material:ShaderMaterial=original.material.duplicate()
    var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
    multi.use_colors=true;multi.use_custom_data=true;multi.mesh=QuadMesh.new();multi.instance_count=2
    var rows:Array=[];var packets:Dictionary={};var indices:Dictionary={};var buffer=PackedFloat32Array()
    for i in 2:
        var row={"id":"floor-"+str(i),"kind":"terrain","position":[i,2],"base_height_steps":0}
        var data=PackedFloat32Array([1,0,0,i,0,1,0,0,0,0,1,2,1,1,1,1,0,0,0,0])
        rows.append(row);packets[row.id]={"data":data};indices[row.id]=i;buffer.append_array(data)
    multi.buffer=buffer
    var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=material;candidate.add_child(node)
    var floor={"id":"new-floor","node":node,"material":material,"cell":Vector2(4,4),"record":original.record,
        "placement":rows[0],"role":"terrain","source_version":1,"batch_rows":rows,"ground_packets":packets,
        "ground_indices":indices,"ground_buffer":buffer,"scenery_values":[0.0,0.0]}
    SourceMaterial.initialize(floor);SourceMaterial.apply(floor,original.source_parameters)
    candidate.entries.append(floor);candidate.result.visibility["floor-0"]=true
    candidate.atlas_jobs.append({"entry":floor,"rows":rows,"packet":{}})
    while candidate.atlas_cursor<candidate.atlas_jobs.size():candidate._prepare_atlas_receiver()
    var sampled:Dictionary=candidate.atlas_shells[node.get_instance_id()].snapshot
    check(sampled.scenery_values==[1.0,0.0],"new floor snapshot uses future visibility for visible and remembered cells")
    check(sampled.ground_buffer[16]==1.0 and sampled.ground_packets["floor-0"].data[16]==1.0,
        "future native address buffer and row packet retain exactly the prepared visibility")
    check(floor.scenery_values==[0.0,0.0] and floor.ground_buffer[16]==0.0 and floor.ground_packets["floor-0"].data[16]==0.0,
        "future visibility never mutates the unpublished source buffer or shared packet")
    check(candidate.atlas_shells[original.node.get_instance_id()].snapshot.scenery_value==0.0
        and original.scenery_value==0.0 and not original.node.is_visible_in_tree() and original not in host.entries,
        "Remembered private source and receiving snapshot agree before publication without touching a displayed entry")
    # A complete replacement may have native shells only for its changed
    # subset. Retained rows still require exact passive source metadata.
    candidate.atlas_shells[node.get_instance_id()].specs.erase("floor-1")
    var prefix:Dictionary=Preparation.AtlasDelta.begin_candidate(host.native_light_atlas,candidate.atlas_jobs,{},host)
    while not Preparation.AtlasDelta.capture_candidate(host.native_light_atlas,prefix,host):pass
    Preparation.AtlasDelta.compute_candidate(prefix)
    check(prefix.get("complete",false) and not prefix.has("error"),"missing native shell metadata does not lose a complete replacement floor row")
    var retained_id:String=str(node.get_instance_id())+":floor-1"
    check(prefix.plan.positions.has(retained_id) and prefix.plan.specs[retained_id].row_rank==1
        and not prefix.plan.specs[retained_id].source_geometry.is_empty(),"retained floor row keeps its future rank and real source geometry")
    check(not prefix.get("bound",false),"worker completion alone cannot publish receiving bindings")
    while not Preparation.AtlasDelta.prepare_candidate_binding(host.native_light_atlas,prefix,candidate.atlas_shells):pass
    check(prefix.worker_source_directories==3 and prefix.source_bind_ids.is_empty() and prefix.bind_ids.size()==4 and prefix.dynamic_bind_cursor==0,
        "Worker source finalization retains every floor-row draw without scene reconstruction of captured source directories")
    var upserts:Dictionary={}
    for entry in candidate.entries:
        upserts[entry.node.get_instance_id()]=entry
        if not entry.has("batch_rows"):entry.scenery_value=1.0 if candidate.result.visibility.has(str(entry.placement.id)) else 0.0
    floor.scenery_values=[1.0,0.0]
    check(Preparation.AtlasDelta.candidate_matches(host.native_light_atlas,prefix,host,upserts,{}),
        "actual publication of prepared sight accepts the private new-source prefix")
    floor.scenery_values=[0.0,0.0]
    check(not Preparation.AtlasDelta.candidate_matches(host.native_light_atlas,prefix,host,upserts,{}),
        "different actual sight still rejects the private prefix")
    check(receiver_refs(host,candidate).all(func(ref):return hidden_receiver(host,ref.get_ref())),
        "Rejected current sight cannot expose prepared static rows even when their local visibility was sampled true")
    candidate.atlas_prefix=prefix
    host._discard_world_preparation();await drain(host,"future visibility");await dispose(host)

func flame_material_refs(candidate:Node,mode:String)->Dictionary:
    var refs={"outputs":[],"groups":[]}
    for prepared in candidate.atlas_shells.values():
        check(prepared.receivers.size()==1 and prepared.specs.size()==1,
            mode+" each private flame source owns its exact hidden receiver and source specification")
        refs.outputs.append(weakref(prepared.output.received_material))
        for group in prepared.groups.values():refs.groups.append(weakref(group.material))
    return refs

func flame_ownership(mode:String)->void:
    var host=make_host();var fixture=prepare(host,11,false,true)
    var candidate:Node=fixture.candidate
    check(candidate.atlas_shells.size()==11 and host.native_light_atlas.prepared_source_bindings.is_empty(),
        mode+" flame preparation exclusively owns complete source bindings")
    check(fixture.receivers.all(func(ref):return ref.get_ref().material!=null and not ref.get_ref().visible),
        mode+" prepared flame receivers have private receiving materials but remain hidden")
    var material_refs:Dictionary=flame_material_refs(candidate,mode)
    var old_parent:Node=host.native_light_atlas.projection_root
    if mode=="replaced":
        var replacement=Node2D.new();host.native_light_atlas.viewport.add_child(replacement)
        host.native_light_atlas.projection_root=replacement
    if mode!="cancel":
        if mode=="replaced":
            for binding in candidate.atlas_shells.values():
                check(not host.native_light_atlas.adopt_source_binding(binding),"Actual flame admission rejects the replaced canvas parent")
        else:candidate.publish_atlas_receivers()
        if mode=="replaced":
            check(candidate.atlas_shells.size()==11 and host.native_light_atlas.prepared_source_bindings.is_empty(),
                "Replaced atlas refuses stale flame shells without moving them to its new parent")
        else:
            check(candidate.atlas_shells.is_empty() and host.native_light_atlas.prepared_source_bindings.size()==11,
                "Flame adoption transfers the existing shells once")
            check(fixture.receivers.all(func(ref):return ref.get_ref().get_parent()==old_parent and not ref.get_ref().visible),
                "Flame adoption preserves their exact final parent and hidden state")
            for entry in candidate.entries:entry.node.reparent(host,false)
            candidate.admitted=true;host._finish_world_preparation()
            host.native_light_atlas._release_prepared_receivers()
            check(fixture.receivers.all(func(ref):return ref.get_ref()!=null and not ref.get_ref().is_queued_for_deletion()),
                "Unused adopted flame shells enter bounded retirement rather than immediate native destruction")
    if mode!="unused":host._discard_world_preparation()
    await drain(host,"flame "+mode)
    check(fixture.receivers.all(func(ref):return released_handle(ref)),"Flame "+mode+" leaves no unowned receiver")
    check(fixture.sources.all(func(ref):return (ref.get_ref()!=null)==(mode=="unused")),
        "Flame "+mode+" preserves only admitted source ownership")
    check(material_refs.groups.all(func(ref):return ref.get_ref()==null),"Flame "+mode+" releases every unconsumed receiving material without an owner cycle")
    check(material_refs.outputs.all(func(ref):return (ref.get_ref()!=null)==(mode=="unused")),
        "Flame "+mode+" keeps exactly the output materials installed on admitted source nodes")
    await dispose(host)

func single_dynamic_preparation()->void:
    var host=make_host();var fixture=prepare(host,1,false,true,false)
    var candidate:Node=fixture.candidate
    candidate.phase="atlas_receivers";candidate.membership={"removed":{}}
    candidate.step(0)
    check(candidate.atlas_prefix.is_empty() and not candidate.prepared,
        "A spent allowance cannot begin even a single dynamic atlas transaction")
    candidate.step(100000)
    check(candidate.prepared and candidate.task<0 and candidate.atlas_prefix.get("planning_lane")=="scene_single_dynamic",
        "One prepared dynamic receiver completes planning/binding without a worker scheduling frame")
    if not candidate.prepared:
        host._discard_world_preparation();await drain(host,"failed single dynamic");await dispose(host);return
    fixture.receivers=receiver_refs(host,candidate)
    check(fixture.receivers.size()==1 and host.native_light_atlas.receivers.is_empty() and host.native_light_atlas.entry_specs.is_empty()
        and not fixture.receivers[0].get_ref().visible,
        "Scene-thread private planning publishes no future receiver, source or pixels")
    # Compare the complete transaction against the unchanged worker planner,
    # including its real future address, support state and receiver ordering.
    var reference_jobs:Array=[];var reference_bindings:Dictionary={}
    for job in candidate.atlas_jobs:
        var prepared:Dictionary=host.native_light_atlas.prepare_source_binding(job.entry,{},host,true)
        prepared.receiver_parent=host.native_light_atlas.projection_root
        reference_bindings[job.entry.node.get_instance_id()]=prepared
        var private_job:Dictionary=job.duplicate();private_job.prepared=prepared;reference_jobs.append(private_job)
    var reference:Dictionary=Preparation.AtlasDelta.begin_candidate(host.native_light_atlas,reference_jobs,{},host)
    while not Preparation.AtlasDelta.capture_candidate(host.native_light_atlas,reference,host):pass
    var task:int=WorkerThreadPool.add_task(Preparation.AtlasDelta.compute_candidate.bind(reference))
    WorkerThreadPool.wait_for_task_completion(task)
    for key in ["owners","supports","specs","positions","cursor","next_height","growing"]:
        check(candidate.atlas_prefix.plan[key]==reference.plan[key],
            "Single dynamic transaction matches the original worker planner's "+key)
    var reference_retirement={"blocked":false,"payloads":[],"directories":[],"unused":[],"active":{}}
    Preparation.AtlasDelta.retire_candidate(reference_retirement,reference,reference_bindings,true)
    while not Preparation.AtlasDelta.retire_candidate_step(reference_retirement).done:pass
    host._discard_world_preparation();await drain(host,"single dynamic");await dispose(host)

func dynamic_worker_cancelled()->void:
    var host=make_host();var fixture=prepare(host,3,false,true,false)
    var candidate:Node=fixture.candidate
    candidate.atlas_prefix=Preparation.AtlasDelta.begin_candidate(host.native_light_atlas,candidate.atlas_jobs,{},host)
    while not Preparation.AtlasDelta.capture_candidate(host.native_light_atlas,candidate.atlas_prefix,host):pass
    candidate.phase="atlas_prefix_wait"
    candidate.task=WorkerThreadPool.add_task(Preparation.AtlasDelta.compute_candidate.bind(candidate.atlas_prefix))
    while not WorkerThreadPool.is_task_completed(candidate.task):await process_frame
    check(candidate.atlas_prefix.ready_style.size()==3 and candidate.atlas_prefix.ready_style.values().all(func(receiver):return not receiver.has("node") and not receiver.has("draw")),
        "Completed dynamic planning owns exact private records before any scene receiver exists")
    var materials:Dictionary=flame_material_refs(candidate,"unbound dynamic cancellation")
    host.timeline.initialization_revision+=1;host._step_world_preparation()
    check(host.pending_world==null and host.native_light_atlas.receivers.is_empty() and host.native_light_atlas.prepared_source_bindings.is_empty(),
        "Epoch cancellation retires unbound dynamic records without inventing native handles or publishing membership")
    await drain(host,"unbound dynamic cancellation")
    check(materials.outputs.all(func(ref):return ref.get_ref()==null) and materials.groups.all(func(ref):return ref.get_ref()==null),
        "Unbound dynamic cancellation releases every private output and receiving material")
    await dispose(host)

func unbound_handle_accounting()->void:
    var host=make_host();var fixture=prepare(host,3,false,false,false)
    var candidate:Node=fixture.candidate
    var prefix:Dictionary=Preparation.AtlasDelta.begin_candidate(host.native_light_atlas,candidate.atlas_jobs,{},host)
    while not Preparation.AtlasDelta.capture_candidate(host.native_light_atlas,prefix,host):pass
    Preparation.AtlasDelta.compute_candidate(prefix)
    var draws:Array=prefix.private_draws.values()
    var batch=prefix.static_batch
    var batch_ref:WeakRef=weakref(batch)
    check(draws.size()==3 and draws.all(func(draw):return draw.rid.is_valid() and draw.parent==batch.rid and hidden_receiver(host,draw))
        and batch.draws==3,
        "Worker completion owns three draws beneath one unadopted hidden native batch")
    var retirement={"blocked":false,"payloads":[],"directories":[],"unused":[],"active":{}}
    Preparation.AtlasDelta.retire_candidate(retirement,prefix,{},true)
    var steps:int=0;var freed:int=0;var native_freed:int=0;var done:bool=false
    while not done and steps<2000:
        var before:int=draws.filter(func(draw):return draw.rid.is_valid()).size()
        var root_before:bool=batch.rid.is_valid()
        var progress:Dictionary=Preparation.AtlasDelta.retire_candidate_step(retirement)
        var after:int=draws.filter(func(draw):return draw.rid.is_valid()).size()
        var released:int=before-after+int(root_before and not batch.rid.is_valid())
        check(int(progress.get("native_units",0))==released and progress.get("node",false)==(released>0),
            "Retirement reports actual draw and last batch-root native disposals exactly")
        native_freed+=released
        if before!=after:
            check(before-after==1,"Each unbound disposal releases one draw, plus its root only on the final child")
            freed+=before-after
        done=progress.done;steps+=1
    check(done and freed==3 and native_freed==4 and not batch.rid.is_valid() and batch.draws==0
        and draws.all(func(draw):return not draw.rid.is_valid() and draw.batch==null),
        "Explicit retirement frees all three draws and their root even while diagnostics retain their records")
    check(draws.all(func(draw):return draw.dispose()==0),"Repeated released-draw disposal cannot release the root twice")
    batch=null
    check(batch_ref.get_ref()==null,"Released batch has no child-directory reference cycle after prefix retirement")
    host._discard_world_preparation();await drain(host,"unbound handles");await dispose(host)

func run()->void:
    await unbound_handle_accounting()
    for mode in ["cancel","epoch","quarter"]:await cancelled(mode)
    await cancelled("sixteen-draw boundary",16)
    for mode in ["cancel","replaced","unused"]:await flame_ownership(mode)
    await single_dynamic_preparation()
    await dynamic_worker_cancelled()
    await accepted();await rejected(false);await rejected(true);await worker_cancelled();await future_visibility()
    var report={"checks":checks,"failures":failures,
        "scope":"Actual WorldPreparation source receiver creation and Play retirement: hidden final parenting, ownership transfer, cancellation, epoch/quarter rejection, atlas replacement/deletion, separate static RID/dynamic Node ownership and sixteen-native-handle frame bound. No GPU pixel or timing claim."}
    FileAccess.open("res://generated/world_preparation_receiver_ownership_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("RECEIVER_OWNERSHIP ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
