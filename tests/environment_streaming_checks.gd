extends SceneTree
## The existing preparation owner must admit ready rows independently of an
## unrelated missing source, without changing the eventual canonical world.
const Sources=preload("res://presentation/sprite_sources.gd")
const Description=preload("res://presentation/environment_source.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
const Resources=preload("res://presentation/environment_resources.gd")
const BackgroundRelease=preload("res://presentation/background_release.gd")
var checks:int=0
var failures:Array=[]
class FixtureHost extends Sources:
    func texture(path:String)->Texture2D:return textures.get(path)
class RetirementHost extends "res://play.gd":
    func _ready()->void:
        # The ordinary Studio host parents its constructor-owned native nodes.
        # Suppressing Play._ready would leave unrelated GUI resources detached.
        external_playback=true
        super._ready()
        set_process(false);set_process_unhandled_input(false)
    func _process(_delta:float)->void:pass
class ConstructionProbe extends Preparation:
    # Controlled actor readiness isolates the dispatcher while the object lane
    # uses real authored descriptors/resources and actual Node adoption below.
    var actor_progress:bool=true
    var actor_turns:int=0
    func _prepare_actor(_deadline:int=9223372036854775807)->bool:
        actor_turns+=1
        return actor_progress
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ENVIRONMENT_STREAMING_FAIL ",label)
func finish_batch(job:Node)->void:
    var deadline:int=Time.get_ticks_msec()+10000
    while job.environment_task>=0 and not WorkerThreadPool.is_task_completed(job.environment_task) and Time.get_ticks_msec()<deadline:
        await process_frame
    check(job.environment_task>=0 and WorkerThreadPool.is_task_completed(job.environment_task),"Resident resource task completes causally")
    if job.environment_task>=0 and WorkerThreadPool.is_task_completed(job.environment_task):job._poll_environment_resources()
func resource_candidate(parent:Node,packets:Dictionary,textures:Dictionary)->Node:
    var candidate:=Preparation.new();parent.add_child(candidate)
    candidate.host=parent;candidate.initial=true
    candidate.result={"worker_ms":0.0,"worker_phases":{}}
    candidate.environment_batch_output={}
    candidate.environment_task=WorkerThreadPool.add_task(Resources.build_private.bind(packets,textures,Sources.environment_parameter_names(),candidate.environment_batch_output),false,"Environment ownership control")
    return candidate

func wait_private(candidate:Node,label:String)->bool:
    var deadline:int=Time.get_ticks_msec()+10000
    while candidate.environment_task>=0 and not WorkerThreadPool.is_task_completed(candidate.environment_task) and Time.get_ticks_msec()<deadline:await process_frame
    var complete:bool=candidate.environment_task>=0 and WorkerThreadPool.is_task_completed(candidate.environment_task)
    check(complete,label+" original resource producer finishes before its result is inspected")
    return complete

func private_entries(candidate:Node)->Array:
    var result:Array=[]
    for output in [candidate.environment_output,candidate.environment_batch_output]:
        for entries in output.get("rows",{}).values():result.append_array(entries)
    return result

func entry_ids(entries:Array)->Array:
    var result:Array=entries.map(func(entry):return entry.node.get_instance_id())
    result.sort();return result

func weak_nodes(entries:Array)->Array:
    return entries.map(func(entry):return weakref(entry.node))

func ownership_cases(host:Node,rows:Array,packets:Dictionary,textures:Dictionary,missing_path:String)->void:
    var shown:Array=host.entries.map(func(entry):return entry.node.get_instance_id())
    var unpolled:Node=resource_candidate(host,packets,textures)
    if not await wait_private(unpolled,"Unpolled cancellation"):unpolled.free();return
    var pending:Array=private_entries(unpolled)
    var expected:Array=entry_ids(pending)
    var pending_refs:Array=weak_nodes(pending)
    check(not pending.is_empty() and unpolled.environment_output.is_empty() and unpolled.environment_task>=0,"Completed but unpolled batch owns detached original nodes, not adopted output")
    check(pending.all(func(entry):return entry.node.get_parent()==null),"Completed resource nodes remain outside the displayed scene")
    # A private table-alias control verifies identity deduplication at retirement;
    # it is not an additional gameplay packet or producer allocation.
    unpolled.environment_output=unpolled.environment_batch_output
    var released:Array=unpolled.release_handles()
    check(entry_ids(released)==expected and released.all(func(entry):return entry.retire_external),"Cancellation transfers every unpolled node exactly once even if result tables alias")
    check(unpolled.environment_task<0 and unpolled.release_handles().is_empty(),"Cancellation joins its task once and release is idempotent")
    check(pending_refs.all(func(reference):return reference.get_ref()!=null),"Transferring handles does not destroy nodes before their retirement owner")
    unpolled.free()
    check(pending_refs.all(func(reference):return reference.get_ref()==null),"Direct owner teardown frees unpolled detached nodes after handle transfer")
    check(host.entries.map(func(entry):return entry.node.get_instance_id())==shown,"Unpolled cancellation preserves every displayed source node")

    var joined:Node=resource_candidate(host,packets,textures)
    if not await wait_private(joined,"Joined cancellation"):joined.free();return
    joined._poll_environment_resources()
    var joined_entries:Array=private_entries(joined)
    var joined_refs:Array=weak_nodes(joined_entries)
    check(joined.environment_task<0 and joined.environment_batch_output.is_empty() and not joined_entries.is_empty(),"Joined unadopted rows reside in completed output")
    released=joined.release_handles()
    check(entry_ids(released)==entry_ids(joined_entries) and released.all(func(entry):return entry.retire_external),"Joined cancellation transfers the exact still-unadopted environment nodes")
    joined.free()
    check(joined_refs.all(func(reference):return reference.get_ref()==null),"Joined owner teardown frees all remaining detached nodes")

    var adopted_host:=FixtureHost.new();root.add_child(adopted_host)
    var partial:Node=resource_candidate(adopted_host,packets,textures)
    if not await wait_private(partial,"Partial adoption"):adopted_host.free();return
    partial._poll_environment_resources()
    var adopted:Array=partial.environment_output.rows[rows[0].id]
    adopted_host.adopt_environment_row(rows[0],adopted)
    var adopted_ids:Array=entry_ids(adopted)
    var detached:Array=private_entries(partial).filter(func(entry):return entry.node.get_parent()==null)
    var detached_refs:Array=weak_nodes(detached)
    check(not adopted.is_empty() and not detached.is_empty(),"One actual authored row adopts while another remains private")
    released=partial.release_handles()
    check(entry_ids(released)==entry_ids(detached) and released.all(func(entry):return entry.node.get_instance_id() not in adopted_ids),"Cancellation never retires an environment node adopted by the displayed parent")
    partial.free()
    check(detached_refs.all(func(reference):return reference.get_ref()==null) and adopted.all(func(entry):return is_instance_valid(entry.node) and entry.node.get_parent()==adopted_host),"Adopted source nodes survive private-owner teardown while detached siblings are freed")
    adopted_host.free()

    var direct:Node=resource_candidate(host,packets,textures)
    if not await wait_private(direct,"Direct cancellation"):direct.free();return
    var direct_refs:Array=weak_nodes(private_entries(direct))
    direct.free()
    check(not direct_refs.is_empty() and direct_refs.all(func(reference):return reference.get_ref()==null),"Direct free without release_handles still joins and frees unadopted resource nodes")

    # Keep both original packets unmodified, but submit the independent row
    # first. Withholding the other row's actual dependency then fails only
    # after genuine native allocations have already entered the output table.
    var failure_packet:Dictionary={}
    failure_packet[rows[1].id]=packets[rows[1].id]
    failure_packet[rows[0].id]=packets[rows[0].id]
    var expected_partial:int=packets[rows[1].id].entries.size()
    for selected in packets[rows[0].id].entries:
        if missing_path in selected.descriptor.get("texture_parameters",{}).values():break
        expected_partial+=1
    check(expected_partial>0 and missing_path not in packets[rows[1].id].paths,"Original independent source row allocates before the later row's missing texture")
    if expected_partial>0:
        var failure_textures:Dictionary=textures.duplicate()
        failure_textures.erase(missing_path)
        var failed:Node=resource_candidate(host,failure_packet,failure_textures)
        if not await wait_private(failed,"Partial failure"):failed.free();return
        var allocated:Array=private_entries(failed)
        var allocated_refs:Array=weak_nodes(allocated)
        check(not failed.environment_batch_output.get("complete",true) and failed.environment_batch_output.get("error","")=="Missing prepared environment texture: "+missing_path,"Real producer reports the exact missing later dependency")
        check(failed.environment_batch_output.rows.has(rows[0].id) and failed.environment_batch_output.rows[rows[1].id].size()==packets[rows[1].id].entries.size(),"Late failure retains the completed first row and the actual failing row's partial table")
        check(allocated.size()==expected_partial and allocated.all(func(entry):return entry.node.get_parent()==null),"Failed batch retains every node allocated before the failing descriptor")
        failed._poll_environment_resources()
        check(failed.phase=="failed" and not failed.prepared and failed.entries.is_empty(),"Failed resource rows never become scene membership or prepared publication")
        released=failed.release_handles()
        check(entry_ids(released)==entry_ids(allocated) and released.all(func(entry):return entry.retire_external),"Failed producer's partial row transfers all its exact native cleanup handles")
        check(failed.release_handles().is_empty(),"Failed producer release remains idempotent")
        failed.free()
        check(allocated_refs.all(func(reference):return reference.get_ref()==null),"Late-failure teardown frees every allocated detached node")

    var retirement:=RetirementHost.new();root.add_child(retirement)
    var retired:Node=resource_candidate(retirement,packets,textures)
    if not await wait_private(retired,"Budgeted retirement"):retirement.free();return
    var retired_refs:Array=weak_nodes(private_entries(retired));var owner_ref:WeakRef=weakref(retired)
    retirement._retire_view(retired,null,[])
    check(retirement.retiring_node_count==retired_refs.size()+1,"Normal retirement captures every external handle before owner tables detach")
    var deadline:int=Time.get_ticks_msec()+10000
    while retirement.retiring_node_count>0 and Time.get_ticks_msec()<deadline:
        retirement._dispose_views();await process_frame
    BackgroundRelease.join()
    check(retirement.retiring_node_count==0 and retirement.retiring_views.is_empty(),"Existing budgeted native retirement drains the complete canceled owner")
    check(owner_ref.get_ref()==null and retired_refs.all(func(reference):return reference.get_ref()==null),"Table detachment cannot strand the canceled owner or its external nodes")
    retirement.free()
    check(host.entries.map(func(entry):return entry.node.get_instance_id())==shown,"All ownership controls preserve the original displayed sources")

func run()->void:
    var host:=FixtureHost.new();root.add_child(host)
    host.camera=Camera3D.new();host.add_child(host.camera)
    host.camera.transform=Sources.Placement.camera_transform(Vector3.ZERO,0)
    var authored:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scenes.json"))
    var rows:Array=[];var packets:Dictionary={};var missing_path:String=""
    for row in authored.scenes[0].placements:
        if row.kind=="actor":continue
        var packet:Dictionary=Description.row_packet(row,0,host.camera.basis,host.catalog_cache,true,true)
        if not packet.eligible or packet.paths.is_empty():continue
        if rows.is_empty():rows.append(row);packets[row.id]=packet;continue
        for path in packets[rows[0].id].paths:
            if not packet.paths.has(path):missing_path=path;break
        if not missing_path.is_empty():rows.append(row);packets[row.id]=packet;break
    check(rows.size()==2,"Two actual authored rows have an independent source dependency")
    if rows.size()!=2:host.free();quit(1);return
    var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color(.3,.6,.2,1))
    var pixels:Texture2D=ImageTexture.create_from_image(image)
    for packet in packets.values():
        for path in packet.paths:host.textures[path]=pixels;host.source_images[path]=image
    host.textures.erase(missing_path);host.source_images.erase(missing_path)
    var job:=ConstructionProbe.new();host.add_child(job);job.host=host;job.initial=true
    job.camera=Camera3D.new();job.add_child(job.camera);job.camera.basis=host.camera.basis
    job.membership_base={"groups":{}}
    var wanted:Dictionary={};var sources:Dictionary={}
    for row in rows:wanted[row.id]=row;sources[row.id]={"paths":packets[row.id].paths,"fixtures":{}}
    job.result={"wanted":wanted,"environment_packets":packets,"object_sources":sources,"worker_ms":0.0,"worker_phases":{}}
    job.wanted_ids=wanted.keys();job.environment_ids=packets.keys()
    job._prepare_environment_resources(Time.get_ticks_usec()+1000000)
    check(job.environment_task>=0 and not job.environment_capture_complete,"Ready row submits while the first canonical row lacks its source")
    check(job.environment_inputs.has(rows[1].id) and not job.environment_inputs.has(rows[0].id),"Submission is per complete row, independent of canonical input order")
    await finish_batch(job)
    check(job.environment_output.get("rows",{}).has(rows[1].id) and not job.environment_output.get("rows",{}).has(rows[0].id),"Join transfers only the complete resident packet")
    check(job.entries.is_empty() and host.entries.is_empty(),"Private resource completion has not published or constructed scene entries")
    job.result.light_resolution={"sources":[{}]};job.light_preparation={"complete":false}
    job.construction_turn=2
    check(job._prepare_construction_turn(Time.get_ticks_usec()+1000000) and job.actor_turns==1 and job.native_groups.is_empty(),
        "One progressing actor turn leaves ready objects their next finite construction turn")
    check(job._prepare_construction_turn(Time.get_ticks_usec()+1000000) and job.native_groups.has(rows[1].id),
        "Actual joined environment resources adopt before a continuously progressing actor can monopolize construction")
    check(job.cookie_source_cursor==0 and not job.light_preparation.complete and not job.native_groups.has(rows[0].id),
        "Ready object construction needs neither unrelated cookie/light completion nor the missing first row")
    var turns:int=job.actor_turns;var nodes:int=job.static_entries.size()
    check(not job._prepare_construction_turn(Time.get_ticks_usec()) and job.actor_turns==turns and job.static_entries.size()==nodes,
        "A spent shared deadline starts no constructor lane")
    host.textures[missing_path]=pixels
    job._prepare_environment_resources(Time.get_ticks_usec()+1000000)
    check(job.environment_task<0 and not job.environment_capture_complete,"GPU texture alone cannot bypass the original CPU-image role")
    host.source_images[missing_path]=image
    job._prepare_environment_resources(Time.get_ticks_usec()+1000000)
    check(job.environment_task>=0 and job.environment_capture_complete,"Remaining source starts the second and only active task")
    check(not job.prepared,"Resource submission does not bypass the final world gate")
    job._prepare_object_step(Time.get_ticks_usec()+1000000,false)
    check(job.native_groups.has(rows[1].id) and not job.native_groups.has(rows[0].id),"A joined row adopts even while a later resource task is active")
    check(host.entries.is_empty() and job.static_entries.size()==packets[rows[1].id].entries.size(),"Adopted entries remain owned by the unpublished world")
    await finish_batch(job)
    check(job.media_issue.is_empty() and job.environment_output.rows.size()==2 and job.environment_output.batches==2,"Both private batches complete without loss or duplicate rows")
    check(job.result.worker_ms==job.environment_output.worker_ms and job.result.worker_phases.environment_resources==job.environment_output.worker_ms,"Joined worker time accumulates once across batches")
    job.actor_progress=false;job.construction_turn=2
    check(job._prepare_construction_turn(Time.get_ticks_usec()+1000000) and job.native_groups.has(rows[0].id),
        "A missing actor source yields the same construction turn to an actually ready later object")
    check(not job.light_preparation.complete and job.cookie_source_cursor==0 and not job.prepared,
        "Independent constructor progress preserves light completion and final publication gates")
    var deadline:int=Time.get_ticks_msec()+10000
    while job.objects_complete.size()<2 and Time.get_ticks_msec()<deadline:
        if not job._prepare_object_step(Time.get_ticks_usec()+1000000,false):break
    check(job.objects_complete.size()==2 and job.wanted_ids==[rows[0].id,rows[1].id],"Eventual construction keeps the original canonical membership order")
    for row in rows:host._environment_row(row.duplicate(true))
    var reference:Dictionary={}
    for entry in host.static_entries:reference[entry.id]=entry
    check(reference.size()==job.static_entries.size(),"Streaming and ordinary construction have equal draw membership")
    for entry in job.static_entries:
        var other:Dictionary=reference[entry.id]
        check(entry.placement==other.placement and entry.source_parameters==other.source_parameters,"Exact authored source parameters "+entry.id)
        check(entry.node.transform==other.node.transform and entry.node.mesh.size==other.node.mesh.size and entry.node.mesh.center_offset==other.node.mesh.center_offset,"Exact authored quad and transform "+entry.id)
    check(not job.prepared and host.entries.size()==reference.size(),"Resource completion alone never publishes the candidate or changes the displayed owner")
    var retained:=Preparation.new();host.add_child(retained);retained.host=host;retained.initial=true
    retained.result={"wanted":wanted,"environment_packets":packets,"object_sources":sources,"worker_ms":0.0,"worker_phases":{}}
    retained.membership_base={"groups":{}}
    for row in rows:retained.membership_base.groups[row.id]={"row":row}
    retained.environment_ids=packets.keys()
    retained._prepare_environment_resources(Time.get_ticks_usec()+1000000)
    check(retained.environment_capture_complete and retained.environment_task<0 and retained.environment_output.is_empty(),"Retained unchanged rows submit no resource task or duplicate packet")
    retained.free()
    await ownership_cases(host,rows,packets,host.textures.duplicate(),missing_path)
    host.free()
    await process_frame;await process_frame;await RenderingServer.frame_post_draw
    var report:Dictionary={"checks":checks,"failures":failures,"scope":"Two real authored rows, missing first-row dependency, joined row adoption during the next task, exact final source operands and quads, canonical input order, private scene ownership, actor-progress fairness, blocked-actor independence, a spent shared deadline, completed/unpolled and joined cancellation, adopted-node survival, true later-row texture failure, idempotent release, direct teardown and budgeted retirement; no framebuffer or latency claim."}
    FileAccess.open("res://generated/environment_streaming_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ENVIRONMENT_STREAMING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
