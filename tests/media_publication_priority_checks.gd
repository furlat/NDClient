extends SceneTree
## Real physical source owner: priority changes scheduling, never residency,
## CPU/fixture readiness, canonical state or another consumer's leases.
const Player=preload("res://play.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
const Media=preload("res://presentation/media_warmup.gd")
const CURRENT="/priority/current.png"
const ACTOR="/priority/next-colour.png"
const NORMAL="/priority/next-normal.png"
const LATER="/priority/later-clip.png"
const FLOOR="/priority/floor.png"
const FIXTURE="/priority/flame.png"
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("MEDIA_PUBLICATION_PRIORITY_FAIL ",label)

func publish(host:Node,path:String,cpu:bool,facts:bool=false)->void:
    var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL)
    if not host.textures.has(path):host.textures[path]=ImageTexture.create_from_image(image)
    if cpu:host.source_images[path]=image
    var loaded={"path":path,"cpu_bytes":image.get_data_size() if cpu else 0,"gpu_bytes":image.get_data_size()}
    if facts:
        loaded.energy=0.5;loaded.emission_centroid=Vector2.ONE
        host.fixture_frame_energy[path]=loaded.energy;host.fixture_frame_centroids[path]=loaded.emission_centroid
    Media.published(host.media_warmup,loaded)

func queued(owner:Dictionary)->Array:
    var result:Array=[]
    for request in owner.pending:result.append(request.path)
    return result

func roles(owner:Dictionary)->Dictionary:
    var result:Dictionary={}
    # The sixth cell is an estimated byte size legitimately refined by actual
    # publication. Only the five consumer role counts must stay invariant.
    for path in owner.interests:result[path]=owner.interests[path].slice(0,5)
    return result

func dispose(host:Node)->void:
    Media.close(host.media_warmup);host.context_menu.free();host.free()

func completed_texture(path:String,image:Image,fixture:bool=false)->Dictionary:
    var loaded:Dictionary={"path":path,"image":image,"texture":ImageTexture.create_from_image(image),
        "cpu_bytes":image.get_data_size(),"gpu_bytes":image.get_data_size(),"complete":true}
    if fixture:loaded.energy=0.5;loaded.emission_centroid=Vector2.ONE
    # A completed private worker receipt is admitted through the real physical
    # queue; no source has become ready or visible merely by producing it.
    return {"task":-1,"joined":true,"path":path,"paths":[path],"result":loaded}

func background_handoff()->void:
    var host=Player.new();host.attach_media_sources()
    var data:Dictionary=host.media_warmup;var owner:Dictionary=Media.physical(data)
    var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL)
    var disk_path:String="res://.runtime/media-background-next.png"
    check(image.save_png(disk_path)==OK,"The next finite worker has an actual original PNG")
    Media.adopt_required(data,9)
    Media.demand(data,{CURRENT:CURRENT});publish(host,CURRENT,true)
    check(Media.boot_ready(data),"Completed initial display owns a real ready source before subsequent preparation")
    var all:Dictionary={CURRENT:CURRENT}
    var paths:Array=[]
    for i in Media.DECODE_WORKERS*Media.DECODE_BATCH_IMAGES:
        var path:String="/priority/private-"+str(i)+".png";paths.append(path);all[path]=path
    all[disk_path]=ProjectSettings.globalize_path(disk_path)
    var fixtures:Dictionary={paths[0]:true}
    Media.demand(data,all,{},fixtures)
    var private_texture:Texture2D
    for worker in Media.DECODE_WORKERS:
        var batch_paths:Array=[];var images:Array=[]
        for member in Media.DECODE_BATCH_IMAGES:
            var i:int=worker*Media.DECODE_BATCH_IMAGES+member
            var path:String=paths[i]
            var request:Dictionary=owner.queued[path]
            owner.pending.erase(request);request.pending=false
            var job:Dictionary=completed_texture(path,image,i==0)
            if i==0:private_texture=job.result.texture
            images.append(job.result);batch_paths.append(path)
        owner.decode_jobs.append({"task":-1,"joined":true,"path":batch_paths[0],"paths":batch_paths,
            "result":{"images":images,"mutex":Mutex.new()}})
    var optional_paths:Dictionary={"/priority/unrelated-library.png":"/no-such-library.png"}
    var optional_family:Dictionary={"paths":optional_paths,"ordered_paths":optional_paths.keys()}
    Media._family_interest(owner,optional_family,1,true)
    var optional_before:int=owner.optional_updates
    check(owner.decode_jobs.size()==Media.DECODE_WORKERS and owner.pending.size()==1
        and not Media.ready(data,{paths[0]:true}),"Completed private batches fill finite worker slots while the next PNG remains pending and unready")
    owner.worker_upload=true
    host.media_metadata_ready=true;host.world_revision=0
    host.timeline.initialization_revision=9;host.timeline.current={"id":"current","duration_ms":100.0}
    host.media_plan={"required":{CURRENT:CURRENT},"errors":[]}
    host.media_group_plans={"current":{"character":{CURRENT:CURRENT},
        "character_timeline":{"initial":{CURRENT:CURRENT},"changes":[]},
        "source_records":{host.character_light_profile:owner.consumers[data.consumer_id].records}}}
    var pending=Preparation.new();pending.epoch=9;pending.quarter=host.quarter
    pending.boundary={"source_group_id":"future","source_local_ms":0.0};pending.result={"environment_paths":{}}
    host.pending_world=pending
    var budget:Dictionary=host._preparation_budget()
    check(budget.limit_usec==2000 and Media.PUBLICATION_BUDGET_USEC==2000,
        "Expanded private pointer receipts retain both the shared and publication two-millisecond budgets")
    budget.used_usec=budget.limit_usec
    host._warm_media(true,budget)
    check(owner.decoded==0 and not host.textures.has(paths[0]),
        "An allowance spent by required world work cannot publish even an already prepared GPU pointer")
    var spent_frame:int=Engine.get_process_frames()
    while Engine.get_process_frames()==spent_frame:await process_frame
    budget=host._preparation_budget()
    host._warm_media(true,budget)
    check(Media.ready(data,{paths[0]:true}) and budget.get("background_source_handoffs",0)==Media.PUBLICATIONS_PER_FRAME,
        "Completed GPU pointers may receive the existing sixteen-private-image window while a world is pending")
    check(is_same(host.textures.get(paths[0]),private_texture) and host.source_images[paths[0]].get_data()==image.get_data(),
        "Background publication adopts the exact private GPU handle and unchanged original pixels")
    check(host.fixture_frame_energy.get(paths[0])==0.5 and host.fixture_frame_centroids.get(paths[0])==Vector2.ONE,
        "The same handoff preserves the fixture optical facts required by the source owner")
    check(owner.decode_jobs.size()<=Media.DECODE_WORKERS and owner.decode_jobs.back().get("task",-1)>=0
        and owner.pending.is_empty(),"Releasing one completed slot dispatches the real pending PNG without waiting for world completion")
    var decoded:int=owner.decoded
    host._warm_media(true,budget)
    check(owner.decoded==decoded and decoded==16 and not host.textures.has(disk_path),
        "A second urgent poll cannot receive a seventeenth image in the same host frame")
    check(owner.optional_updates==optional_before and owner.families.back().cursor==0,
        "Receiving finished source handles does not advance unrelated optional-library selection or family accounting")
    var publication_frame:int=Engine.get_process_frames()
    # SceneTree emits process_frame before its process-frame counter advances;
    # resume only after the actual host-frame identity has changed.
    while Engine.get_process_frames()==publication_frame:await process_frame
    var completion_deadline:int=Time.get_ticks_msec()+10000
    while owner.decode_jobs.any(func(job):return not job.get("joined",false) and job.get("task",-1)>=0 and not WorkerThreadPool.is_task_completed(job.task)) and Time.get_ticks_msec()<completion_deadline:await process_frame
    budget=host._preparation_budget()
    host._warm_media(true,budget)
    check(owner.decoded==decoded+1 and host.textures.has(disk_path)
        and host.source_images[disk_path].get_data()==image.get_data() and budget.get("background_source_handoffs",0)==1,
        "A later host frame receives the one real pending PNG after the sixteen-image window without waiting for world completion")
    check(not pending.prepared and host.timeline.display_ms==0.0 and host.timeline.state.is_empty(),
        "Independent source progress neither completes the private world nor advances authoritative display")
    host.pending_world=null;pending.free();dispose(host)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(disk_path))

func run()->void:
    var host=Player.new();host.attach_media_sources()
    var data:Dictionary=host.media_warmup;var owner:Dictionary=Media.physical(data)
    Media.adopt_required(data,7)
    # This scenario changes future priority after the initial empty picture
    # has published. Unfinished startup retains its own exact source pins.
    Media.demand(data,{})
    check(Media.boot_ready(data),"Initial picture completes before future candidate scheduling and cancellation")
    # Deliberately queue scenery first. After the displayed cut is ready,
    # independent future resource producers share urgency and retain FIFO.
    var all:Dictionary={FLOOR:FLOOR,FIXTURE:FIXTURE,ACTOR:ACTOR,NORMAL:NORMAL,LATER:LATER,CURRENT:CURRENT}
    var environment:Dictionary={FLOOR:true,FIXTURE:true};var fixture:Dictionary={FIXTURE:true}
    var gpu_only:Dictionary={NORMAL:true,LATER:true}
    Media.demand(data,all,environment,fixture,gpu_only)
    check(queued(owner)==[FLOOR,FIXTURE,ACTOR,NORMAL,LATER,CURRENT],"Actual demand initially retains authored FIFO source order")
    check(is_same(data.pending,owner.pending) and is_same(host.textures,owner.textures),"Player uses the actual physical queue and texture directories")
    var strong_roles:Dictionary=roles(owner)
    var required:Dictionary=owner.wanted.duplicate()
    var current_record=Media.source_record({CURRENT:CURRENT})
    var next_paths=all.duplicate();next_paths.erase(CURRENT)
    var next_record=Media.source_record(next_paths,environment,fixture,gpu_only)
    var current_records:Array=[current_record];var next_records:Array=[next_record]
    var profile:String=host.character_light_profile
    var selected:Dictionary={ACTOR:ACTOR,NORMAL:NORMAL}
    var later_selected:Dictionary=selected.duplicate();later_selected[LATER]=LATER
    host.media_metadata_ready=true;host.world_revision=0
    host.timeline.initialization_revision=7;host.timeline.current={"id":"current","duration_ms":100.0}
    host.timeline.state={"sentinel":"authoritative"}
    host.media_plan={"required":{CURRENT:CURRENT},"errors":[]}
    host.media_group_plans={
        "current":{"character":{CURRENT:CURRENT},"character_timeline":{"initial":{CURRENT:CURRENT},"changes":[]},
            "source_records":{profile:current_records}},
        "next":{"character":later_selected,"character_timeline":{"initial":selected,
            "changes":[{"at_ms":20.0,"paths":later_selected}]},"source_records":{profile:next_records}}}
    var pending=Preparation.new();pending.epoch=7;pending.quarter=host.quarter
    pending.boundary={"source_group_id":"next","source_local_ms":10.0}
    pending.result={"environment_paths":environment};host.pending_world=pending
    var due:Dictionary=host._prioritize_media(0.0)
    check(due.keys()==[CURRENT] and queued(owner).front()==CURRENT,"Missing current source outranks future actors and earlier scenery requests")
    check(not due.has(ACTOR) and not due.has(FLOOR),"Later construction cannot fill urgent slots while current display is unready")
    check(owner.wanted==required and roles(owner)==strong_roles,"Priority keeps all required CPU, GPU and fixture role contributions")

    publish(host,CURRENT,true)
    var current_texture:Texture2D=host.textures[CURRENT]
    due=host._prioritize_media(0.0)
    check(Media.ready(data,{CURRENT:true}) and due.has(ACTOR) and due.has(NORMAL),"Real current publication promotes the exact future character cut")
    check(not due.has(LATER) and due.has(FLOOR) and due.has(FIXTURE),"Exact future room and actor operands become urgent together before an unrelated later clip")
    check(queued(owner).slice(0,4)==[FLOOR,FIXTURE,ACTOR,NORMAL],"Equal-urgency future producers retain their original FIFO order")
    check(Media._decode_priority(owner,FLOOR)==0 and Media._decode_priority(owner,FIXTURE)==0,"Future room resources need not wait for unrelated actor publication")
    check(not Media.ready(data,selected),"Scheduling intent does not fabricate future character readiness")

    publish(host,ACTOR,false);publish(host,NORMAL,false)
    due=host._prioritize_media(0.0)
    check(not Media.ready(data,{ACTOR:true}) and Media.ready(data,{NORMAL:true}),"Original-pixel character role still waits for CPU pixels while its GPU-only normal is ready")
    check(due.has(FLOOR) and due.has(FIXTURE) and queued(owner).has(ACTOR),"A missing actor CPU role preserves its own gate while independent scenery remains urgent")
    var actor_texture:Texture2D=host.textures[ACTOR]
    publish(host,ACTOR,true)
    due=host._prioritize_media(0.0)
    check(Media.ready(data,selected) and due.has(FLOOR) and due.has(FIXTURE),"Actor completion leaves the already urgent room closure unchanged")
    check(queued(owner).slice(0,2)==[FLOOR,FIXTURE] and not due.has(LATER),"Ready actors release urgent slots to exact current-quarter scenery before an unrelated later clip")
    check(is_same(actor_texture,host.textures[ACTOR]) and is_same(current_texture,host.textures[CURRENT]),"CPU promotion and scheduling preserve existing uploaded textures")
    check(owner.wanted==required and roles(owner)==strong_roles,"All priority transitions preserve the same strong pins and source roles")

    publish(host,FLOOR,false);publish(host,FIXTURE,true)
    check(not Media.ready(data,{FLOOR:true}) and not Media.ready(data,{FIXTURE:true}),"Environment CPU pixels and fixture optical facts remain mandatory despite urgent GPU publication")
    publish(host,FLOOR,true);publish(host,FIXTURE,true,true)
    check(Media.ready(data,environment),"Publishing the exact environment originals and fixture facts satisfies their real consumer gate")

    var other=Player.new();Media.share(other.media_warmup,data);other.attach_media_sources()
    Media.demand(other.media_warmup,{LATER:LATER},{},{},{LATER:true})
    Media.prioritize(other.media_warmup,{LATER:true})
    host.pending_world=null
    host._prioritize_media(0.0)
    check(owner.wanted.has(LATER) and owner.queued.has(LATER) and owner.due_paths.get(LATER,0)==1,"Cancelling one candidate preserves another consumer's exact pending pin and priority")
    check(not owner.wanted.has(ACTOR) and Media.ready(data,{CURRENT:true}) and is_same(current_texture,host.textures[CURRENT]),"Candidate cancellation retires only its future lease and preserves the current display")
    check(host.timeline.state=={"sentinel":"authoritative"} and host.timeline.display_ms==0.0 and host.timeline.current.id=="current", "Source scheduling changes no canonical state, event selection or animation clock")
    dispose(other);pending.free();dispose(host)
    await background_handoff()
    var report={"checks":checks,"failures":failures,"scope":"Actual shared physical source owner and Play priority; original-pixel/fixture readiness, exact future cut, retained pins, cancellation and texture identity. No live latency claim."}
    FileAccess.open("res://.runtime/media-publication-priority-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_PUBLICATION_PRIORITY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
