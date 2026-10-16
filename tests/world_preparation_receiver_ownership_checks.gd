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
        camera=Camera3D.new();add_child(camera)
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

func prepare(host:Probe,count:int,remember_first:bool=false,flames:bool=false)->Dictionary:
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
    var refs:Array=[]
    for binding in candidate.atlas_shells.values():
        for receiver in binding.receivers.values():refs.append(weakref(receiver.node))
    check(refs.size()==count,"real source preparation creates one receiver per source")
    check(refs.all(func(ref):return ref.get_ref().get_parent()==host.native_light_atlas.projection_root and not ref.get_ref().visible),
        "prepared receivers have their final canvas parent but remain hidden")
    check(host.native_light_atlas.receivers.is_empty() and host.native_light_atlas.prepared_source_bindings.is_empty(),
        "unpublished nodes do not enter displayed atlas ownership")
    return {"candidate":candidate,"receivers":refs,"sources":source_refs}

func drain(host:Probe,label:String)->void:
    var frames=0
    while host.retiring_node_count>0 and frames<80:
        await process_frame
        var before:int=host.retiring_node_count
        host._dispose_views()
        var after:int=host.retiring_node_count
        check(before-after>=0 and before-after<=16,label+" each cleanup slice releases at most sixteen native nodes while private metadata drains")
        host._dispose_views()
        check(host.retiring_node_count==after,label+" a repeated same-frame call cannot exceed the slice")
        frames+=1
    check(host.retiring_node_count==0 and host.retiring_views.is_empty(),label+" cleanup drains without orphaned handles")

func dispose(host:Probe)->void:
    host.queue_free();await process_frame;await process_frame

func cancelled(mode:String)->void:
    var host=make_host();var fixture=prepare(host,41)
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
    check(host.retiring_node_count==42,mode+" retains the candidate root and forty-one external receivers before bounded descendant discovery")
    check(fixture.receivers.all(func(ref):return ref.get_ref()!=null and not ref.get_ref().visible),mode+" cancellation does not synchronously free or show future receivers")
    await drain(host,mode)
    check(fixture.receivers.all(func(ref):return ref.get_ref()==null) and fixture.sources.all(func(ref):return ref.get_ref()==null),mode+" source and external receiver nodes are actually destroyed")
    check(displayed_ref.get_ref()!=null and displayed.visible,mode+" displayed canvas siblings remain owned and visible")
    check(retained_ref.get_ref()!=null,mode+" an ordinary retained source handle cannot retire a live external node")
    await dispose(host)

func accepted()->void:
    var host=make_host();var fixture=prepare(host,3)
    var candidate:Node=fixture.candidate
    candidate.publish_atlas_receivers()
    check(candidate.atlas_shells.is_empty() and host.native_light_atlas.prepared_source_bindings.size()==3,
        "successful publication transfers each private receiver binding exactly once")
    check(fixture.receivers.all(func(ref):return ref.get_ref().get_parent()==host.native_light_atlas.projection_root and not ref.get_ref().visible),
        "adoption preserves final parent and stays hidden until ordinary atlas visibility admission")
    for entry in candidate.entries:entry.node.reparent(host,false)
    candidate.admitted=true;host._finish_world_preparation()
    await process_frame;host._dispose_views()
    check(host.retiring_node_count>0 and fixture.receivers.all(func(ref):return ref.get_ref()!=null)
        and fixture.sources.all(func(ref):return ref.get_ref()!=null),
        "retirement waits for atlas consumption without destroying transferred receiving or displayed source nodes")
    host.native_light_atlas._release_prepared_receivers()
    check(fixture.receivers.all(func(ref):return ref.get_ref()!=null),"atlas release transfers unused nodes without synchronous destruction")
    await drain(host,"accepted")
    check(fixture.receivers.all(func(ref):return ref.get_ref()==null),"bounded retirement releases transferred unused bindings")
    check(fixture.sources.all(func(ref):return ref.get_ref()!=null),"bounded metadata cleanup never releases displayed sources")
    await dispose(host)

func rejected(free_parent:bool)->void:
    var host=make_host();var fixture=prepare(host,3)
    var candidate:Node=fixture.candidate
    var old_parent:Node=host.native_light_atlas.projection_root
    var replacement=Node2D.new();host.native_light_atlas.viewport.add_child(replacement)
    host.native_light_atlas.projection_root=replacement
    if free_parent:old_parent.free()
    candidate.publish_atlas_receivers()
    check(candidate.atlas_shells.size()==3 and host.native_light_atlas.prepared_source_bindings.is_empty(),
        "replaced or freed receiver parent is rejected without transferring candidate ownership")
    host._discard_world_preparation();await drain(host,"rejected")
    check(fixture.receivers.all(func(ref):return ref.get_ref()==null),"rejected receiver bindings leave no external orphan")
    check(is_instance_valid(replacement) and replacement.get_child_count()==0,"rejection never reparents stale nodes into the new atlas")
    await dispose(host)

func worker_cancelled()->void:
    var host=make_host();var fixture=prepare(host,41)
    var candidate:Node=fixture.candidate
    candidate.atlas_prefix=Preparation.AtlasDelta.begin_candidate(host.native_light_atlas,candidate.atlas_jobs,{},host)
    while not Preparation.AtlasDelta.capture_candidate(host.native_light_atlas,candidate.atlas_prefix,host):pass
    candidate.phase="atlas_prefix_wait"
    candidate.task=WorkerThreadPool.add_task(Preparation.AtlasDelta.compute_candidate.bind(candidate.atlas_prefix),false,"Cancelled private atlas prefix")
    host.timeline.initialization_revision+=1
    host._step_world_preparation()
    var frames:int=0
    while host.pending_world!=null and frames<80:
        await process_frame;host._step_world_preparation();frames+=1
    check(host.pending_world==null,"epoch cancellation waits for passive prefix completion then discards its owner")
    check(host.native_light_atlas.receivers.is_empty() and host.native_light_atlas.prepared_source_bindings.is_empty()
        and host.native_light_atlas.prepared_delta.is_empty(),"cancelled worker never publishes future receiver maps or address packets")
    await drain(host,"worker cancellation")
    check(fixture.receivers.all(func(ref):return ref.get_ref()==null) and fixture.sources.all(func(ref):return ref.get_ref()==null),
        "worker cancellation retires every private source and external receiver")
    await dispose(host)

func future_visibility()->void:
    var host=make_host();var fixture=prepare(host,2,true)
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
    candidate.atlas_prefix=prefix
    host._discard_world_preparation();await drain(host,"future visibility");await dispose(host)

func flame_material_refs(candidate:Node,mode:String)->Array:
    var refs:Array=[]
    for prepared in candidate.atlas_shells.values():
        check(prepared.receivers.size()==1 and prepared.specs.size()==1,
            mode+" each private flame source owns its exact hidden receiver and source specification")
        refs.append(weakref(prepared.output.received_material))
        for group in prepared.groups.values():refs.append(weakref(group.material))
    return refs

func flame_ownership(mode:String)->void:
    var host=make_host();var fixture=prepare(host,11,false,true)
    var candidate:Node=fixture.candidate
    check(candidate.atlas_shells.size()==11 and host.native_light_atlas.prepared_source_bindings.is_empty(),
        mode+" flame preparation exclusively owns complete source bindings")
    check(fixture.receivers.all(func(ref):return ref.get_ref().material!=null and not ref.get_ref().visible),
        mode+" prepared flame receivers have private receiving materials but remain hidden")
    var material_refs:Array=flame_material_refs(candidate,mode)
    var old_parent:Node=host.native_light_atlas.projection_root
    if mode=="replaced":
        var replacement=Node2D.new();host.native_light_atlas.viewport.add_child(replacement)
        host.native_light_atlas.projection_root=replacement
    if mode!="cancel":
        candidate.publish_atlas_receivers()
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
    check(fixture.receivers.all(func(ref):return ref.get_ref()==null),"Flame "+mode+" leaves no unowned receiver")
    check(fixture.sources.all(func(ref):return (ref.get_ref()!=null)==(mode=="unused")),
        "Flame "+mode+" preserves only admitted source ownership")
    check(material_refs.all(func(ref):return ref.get_ref()==null),"Flame "+mode+" releases every unconsumed private material without an owner cycle")
    await dispose(host)

func single_dynamic_preparation()->void:
    var host=make_host();var fixture=prepare(host,1,false,true)
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
    check(host.native_light_atlas.receivers.is_empty() and host.native_light_atlas.entry_specs.is_empty()
        and not fixture.receivers[0].get_ref().visible,
        "Scene-thread private planning publishes no future receiver, source or pixels")
    # Compare the complete transaction against the unchanged worker planner,
    # including its real future address, support state and receiver ordering.
    var reference:Dictionary=Preparation.AtlasDelta.begin_candidate(host.native_light_atlas,candidate.atlas_jobs,{},host)
    while not Preparation.AtlasDelta.capture_candidate(host.native_light_atlas,reference,host):pass
    var task:int=WorkerThreadPool.add_task(Preparation.AtlasDelta.compute_candidate.bind(reference))
    WorkerThreadPool.wait_for_task_completion(task)
    for key in ["owners","supports","specs","positions","cursor","next_height","growing"]:
        check(candidate.atlas_prefix.plan[key]==reference.plan[key],
            "Single dynamic transaction matches the original worker planner's "+key)
    host._discard_world_preparation();await drain(host,"single dynamic");await dispose(host)

func run()->void:
    for mode in ["cancel","epoch","quarter"]:await cancelled(mode)
    for mode in ["cancel","replaced","unused"]:await flame_ownership(mode)
    await single_dynamic_preparation()
    await accepted();await rejected(false);await rejected(true);await worker_cancelled();await future_visibility()
    var report={"checks":checks,"failures":failures,
        "scope":"Actual WorldPreparation source receiver creation and Play retirement: hidden final parenting, ownership transfer, cancellation, epoch/quarter rejection, atlas replacement/deletion, sixteen-node frame bound. No GPU pixel or timing claim."}
    FileAccess.open("res://generated/world_preparation_receiver_ownership_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("RECEIVER_OWNERSHIP ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
