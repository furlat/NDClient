extends SceneTree
## Real candidate preparation/publication/retirement with small mathematical
## source images. This qualifies ownership and bounded cleanup, not pixels/FPS.
## Sprites light themselves: a candidate owns only its hidden source nodes,
## their materials and explicitly external light records.
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
    var image=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
    host.source_images={"fixture":image}
    host.textures["fixture"]=ImageTexture.create_from_image(image)
    return host

func source_entry(host:Probe,parent:Node,id:String,x:int,flames:bool)->Dictionary:
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();parent.add_child(node)
    var material=ShaderMaterial.new();material.shader=host.FIXTURE_FLAME_SHADER if flames else host.ENVIRONMENT_SHADER
    node.material_override=material
    var row={"id":id,"kind":"wall","position":[x,0],"base_height_steps":0}
    var entry={"id":row.id,"node":node,"material":material,"cell":Vector2(4,4),
        "record":{"path":"fixture","rect":[0,0,4,4]},"placement":row,"role":"wall","source_version":1}
    SourceMaterial.initialize(entry)
    if flames:
        var frames=Texture2DArray.new();var images:Array[Image]=[host.source_images.fixture]
        check(frames.create_from_images(images)==OK,"Fixture flame uses an explicit native source frame")
        SourceMaterial.apply(entry,{"frames":frames,"frame_index":0})
    else:SourceMaterial.apply(entry,{"colour_texture":host.textures.fixture,"colour_size":Vector2(4,4),"colour_rect":Vector4(0,0,4,4)})
    return entry

func prepare(host:Probe,count:int,remember_first:bool=false,flames:bool=false)->Dictionary:
    var candidate=Preparation.new();host.add_child(candidate);host.pending_world=candidate
    candidate.host=host;candidate.visible=false;candidate.epoch=host.timeline.initialization_revision
    candidate.quarter=host.quarter
    candidate.result={"visibility":{},"visibility_changes":{},"supports":{},"worker_ms":0.0}
    var source_refs:Array=[];var material_refs:Array=[]
    for index in count:
        var entry:Dictionary=source_entry(host,candidate,"fixture-"+str(index),index,flames)
        candidate.entries.append(entry)
        if not remember_first or index>0:candidate.result.visibility[entry.placement.id]=true
        source_refs.append(weakref(entry.node));material_refs.append(weakref(entry.material))
    for entry in candidate.entries:check(candidate._prepare_private_source(entry),"Private source preparation completes in one step")
    check(candidate.entries.all(func(entry):return not entry.node.is_visible_in_tree() and entry not in host.entries),
        "Prepared sources stay hidden under the private candidate and out of the displayed directory")
    return {"candidate":candidate,"sources":source_refs,"materials":material_refs}

func live_handles(refs:Array)->int:
    var count:int=0
    for ref in refs:
        if ref.get_ref()!=null:count+=1
    return count

func drain(host:Probe,label:String,tracked:Array=[])->void:
    var frames=0
    while not host.retiring_views.is_empty() and frames<80:
        await process_frame
        var before:int=host.retiring_node_count
        var native_before:int=live_handles(tracked)
        host._dispose_views()
        var after:int=host.retiring_node_count
        check(before-after<=16,label+" each cleanup slice releases at most sixteen native nodes")
        if not tracked.is_empty():
            check(native_before-live_handles(tracked)<=16,label+" actual scene node disposal stays within sixteen native handles")
        var native_after:int=live_handles(tracked)
        host._dispose_views()
        check(host.retiring_node_count==after and live_handles(tracked)==native_after,label+" a repeated same-frame call cannot exceed the slice")
        frames+=1
    check(host.retiring_node_count==0 and host.retiring_views.is_empty(),label+" cleanup drains without orphaned handles")

func dispose(host:Probe)->void:
    host.queue_free();await process_frame;await process_frame

func finish_receivers()->void:
    var host=make_host();var fixture=prepare(host,3)
    var candidate:Node=fixture.candidate
    candidate.membership={"upserts":candidate.entries.duplicate(),"removed":{}}
    candidate._finish_receivers()
    check(candidate.boundary_jobs.map(func(job):return job.entry)==candidate.entries,
        "Every new entry joins the spell receiver boundary once, in membership order")
    check(candidate.phase=="native_receivers" and not candidate.prepared,
        "Receiver boundary hands off to native receivers without publishing")
    host._discard_world_preparation();await drain(host,"receiver boundary");await dispose(host)

func cancelled(mode:String,count:int=41)->void:
    var host=make_host();var fixture=prepare(host,count)
    var tracked:Array=fixture.sources.duplicate();tracked.append(weakref(fixture.candidate))
    var displayed=MeshInstance3D.new();host.add_child(displayed)
    displayed.visible=true
    var displayed_ref=weakref(displayed)
    # A retained source handle does not transfer ownership of a live external
    # node. Only explicitly candidate-owned external records may retire there.
    var retained=Node3D.new();host.add_child(retained)
    fixture.candidate.entries.append({"node":retained})
    var retained_ref=weakref(retained)
    # Prepared light nodes live under the receiving page, outside the candidate.
    var light=PointLight2D.new();light.enabled=false;host.add_child(light)
    var light_ref=weakref(light)
    fixture.candidate.light_preparation={"nodes":[{"node":light}]}
    tracked.append(light_ref)
    if mode=="epoch":
        host.timeline.initialization_revision+=1;host._step_world_preparation()
    elif mode=="quarter":
        host.quarter=(host.quarter+1)%4;host._step_world_preparation()
    else:host._discard_world_preparation()
    check(host.pending_world==null,mode+" discards the candidate through the real Play boundary")
    check(host.retiring_node_count==2,mode+" retains one scene root and its one external light on the bounded lane")
    check(fixture.sources.all(func(ref):return ref.get_ref()!=null and not ref.get_ref().is_visible_in_tree()) and light_ref.get_ref()!=null,
        mode+" cancellation does not synchronously free or expose future sources")
    await drain(host,mode,tracked)
    check(fixture.sources.all(func(ref):return ref.get_ref()==null) and light_ref.get_ref()==null,mode+" source and external light nodes are actually destroyed")
    await process_frame
    check(fixture.materials.all(func(ref):return ref.get_ref()==null),mode+" retired sources release their materials without an owner cycle")
    check(displayed_ref.get_ref()!=null and displayed.visible,mode+" displayed siblings remain owned and visible")
    check(retained_ref.get_ref()!=null,mode+" an ordinary retained source handle cannot retire a live external node")
    await dispose(host)

func accepted()->void:
    var host=make_host();var fixture=prepare(host,3)
    var candidate:Node=fixture.candidate
    var published:Array=candidate.entries.duplicate()
    for entry in published:entry.node.reparent(host,false)
    candidate.admitted=true;host._finish_world_preparation()
    check(host.pending_world==null and host.retiring_node_count>0,"Publication retires the private owner on the bounded lane")
    check(published.all(func(entry):return entry.node.get_parent()==host and entry.node.is_visible_in_tree()),
        "Adopted sources move to the displayed parent and become visible with it")
    await drain(host,"accepted")
    check(fixture.sources.all(func(ref):return ref.get_ref()!=null),"bounded owner cleanup never releases displayed sources")
    check(fixture.materials.all(func(ref):return ref.get_ref()!=null),"bounded owner cleanup keeps the displayed source materials")
    await dispose(host)

func worker_cancelled()->void:
    var host=make_host();var fixture=prepare(host,41)
    var candidate:Node=fixture.candidate
    candidate.phase="projection"
    var release=Semaphore.new()
    candidate.task=WorkerThreadPool.add_task(func():release.wait(),false,"Cancelled private world projection")
    host.timeline.initialization_revision+=1
    host._step_world_preparation()
    check(host.pending_world==candidate,"Epoch cancellation does not join an unfinished worker on the scene thread")
    check(fixture.sources.all(func(ref):return ref.get_ref()!=null and not ref.get_ref().is_visible_in_tree()),
        "An epoch-stale candidate keeps owning only hidden private sources while its worker runs")
    release.post()
    while not WorkerThreadPool.is_task_completed(candidate.task):await process_frame
    var frames:int=0
    while host.pending_world!=null and frames<80:
        await process_frame;host._step_world_preparation();frames+=1
    check(host.pending_world==null,"epoch cancellation waits for passive worker completion then discards its owner")
    check(host.entries.is_empty() and host.static_entries.is_empty(),"cancelled worker never publishes future membership")
    var tracked:Array=fixture.sources.duplicate()
    await drain(host,"worker cancellation",tracked)
    check(fixture.sources.all(func(ref):return ref.get_ref()==null),"worker cancellation retires every private source")
    await dispose(host)

func future_visibility()->void:
    var host=make_host()
    var displayed:Dictionary=source_entry(host,host,"fixture-0",0,false)
    host.entries.append(displayed);host.static_entries.append(displayed)
    SourceMaterial.set_parameter(displayed,"current_visibility",1.0);displayed.scenery_value=1.0
    var fixture=prepare(host,3,true)
    var candidate:Node=fixture.candidate
    var remembered:Dictionary=candidate.entries[0];var visible:Dictionary=candidate.entries[1]
    check(SourceMaterial.value(remembered,"current_visibility")==0.0 and remembered.scenery_value==0.0,
        "Remembered private source starts with its future visibility")
    check(SourceMaterial.value(visible,"current_visibility")==1.0 and visible.scenery_value==1.0,
        "Visible private source starts with its future visibility")
    check(SourceMaterial.value(displayed,"current_visibility")==1.0 and displayed.scenery_value==1.0 and displayed.node.is_visible_in_tree(),
        "Future visibility never mutates the displayed source with the same row identity")
    # A sight cut names explicit changes; they win over the candidate snapshot.
    candidate.result.visibility_changes={"fixture-0":true,"fixture-1":false}
    candidate._prepare_private_source(remembered);candidate._prepare_private_source(visible)
    check(SourceMaterial.value(remembered,"current_visibility")==1.0 and SourceMaterial.value(visible,"current_visibility")==0.0,
        "Explicit sight changes select the future visibility of each private source")
    var actor:Dictionary=source_entry(host,candidate,"actor-0",9,false);actor.placement.kind="actor"
    candidate._prepare_private_source(actor)
    check(SourceMaterial.value(actor,"current_visibility")==1.0,"Private actor layers are always visible")
    var initial:Dictionary=source_entry(host,candidate,"fixture-9",9,false)
    SourceMaterial.set_parameter(initial,"current_visibility",.25);initial.scenery_value=.25
    candidate.initial=true;candidate._prepare_private_source(initial)
    check(SourceMaterial.value(initial,"current_visibility")==.25 and initial.scenery_value==.25,
        "Initial preparation leaves source visibility to the first scenery publication")
    candidate.entries.append_array([actor,initial])
    host._discard_world_preparation();await drain(host,"future visibility");await dispose(host)

func flame_ownership(mode:String)->void:
    var host=make_host();var fixture=prepare(host,11,false,true)
    var candidate:Node=fixture.candidate
    check(candidate.entries.all(func(entry):return entry.material.shader==host.FIXTURE_FLAME_SHADER and entry.node.material_override==entry.material),
        mode+" each private flame source owns its exact lit material")
    if mode=="unused":
        for entry in candidate.entries:entry.node.reparent(host,false)
        candidate.admitted=true;host._finish_world_preparation()
    else:host._discard_world_preparation()
    await drain(host,"flame "+mode)
    await process_frame
    var kept:bool=mode=="unused"
    check(fixture.sources.all(func(ref):return (ref.get_ref()!=null)==kept),"Flame "+mode+" preserves only admitted source ownership")
    check(fixture.materials.all(func(ref):return (ref.get_ref()!=null)==kept),"Flame "+mode+" keeps exactly the materials installed on admitted source nodes")
    await dispose(host)

func run()->void:
    await finish_receivers()
    for mode in ["cancel","epoch","quarter"]:await cancelled(mode)
    await cancelled("sixteen-node boundary",16)
    for mode in ["cancel","unused"]:await flame_ownership(mode)
    await accepted();await worker_cancelled();await future_visibility()
    var report={"checks":checks,"failures":failures,
        "scope":"Actual WorldPreparation private sources and Play retirement: hidden private ownership, spell receiver boundary, publication transfer, cancellation, epoch/quarter rejection, external light retirement, material release and sixteen-native-node frame bound. No GPU pixel or timing claim."}
    FileAccess.open("res://generated/world_preparation_receiver_ownership_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("RECEIVER_OWNERSHIP ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
