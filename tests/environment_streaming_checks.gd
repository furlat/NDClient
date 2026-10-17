extends SceneTree
## The existing preparation owner must admit ready rows independently of an
## unrelated missing source, without changing the eventual canonical world.
const Sources=preload("res://presentation/sprite_sources.gd")
const Description=preload("res://presentation/environment_source.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
var checks:int=0
var failures:Array=[]
class FixtureHost extends Sources:
    func texture(path:String)->Texture2D:return textures.get(path)
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
    var cancelled:=Preparation.new();host.add_child(cancelled);cancelled.host=host;cancelled.initial=true
    cancelled.result={"wanted":wanted,"environment_packets":packets,"object_sources":sources,"worker_ms":0.0,"worker_phases":{}}
    cancelled.membership_base={"groups":{}};cancelled.environment_ids=packets.keys()
    cancelled._prepare_environment_resources(Time.get_ticks_usec()+1000000)
    check(cancelled.environment_task>=0,"Cancellation case owns a real finite producer task")
    var cancel_deadline:int=Time.get_ticks_msec()+10000
    while cancelled.environment_task>=0 and not WorkerThreadPool.is_task_completed(cancelled.environment_task) and Time.get_ticks_msec()<cancel_deadline:
        await process_frame
    check(cancelled.worker_finished(),"Cancellation waits for private work to finish before releasing its owner")
    var released:Array=cancelled.release_handles()
    check(released.is_empty() and cancelled.environment_task<0 and not cancelled.prepared and host.entries.size()==reference.size(),"Cancelled unadopted packets join once without exposing Nodes, state or displayed entries")
    cancelled.free()
    host.free()
    var report:Dictionary={"checks":checks,"failures":failures,"scope":"Two real authored rows, missing first-row dependency, joined row adoption during the next task, exact final source operands and quads, canonical input order, private scene ownership, actor-progress fairness, blocked-actor independence and a spent shared deadline; no framebuffer or latency claim."}
    FileAccess.open("res://generated/environment_streaming_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ENVIRONMENT_STREAMING ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
