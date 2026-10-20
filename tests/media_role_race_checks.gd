extends SceneTree
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Journal = preload("res://sdk/journal.gd")
const Fixtures = preload("res://tests/recording_fixtures.gd")
const Catalog = preload("res://source_catalog.gd")
var checks = 0
var failures: Array = []
var parallel_evidence: Dictionary = {}

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("MEDIA_ROLE_RACE_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func loaded(data: Dictionary) -> Dictionary:
    var deadline = Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        var result = Media.poll(data)
        if not result.is_empty(): return result
        await process_frame
    return {}

func parallel_sources(environment: Dictionary) -> void:
    var wanted = {}
    for path in environment.required:
        wanted[path] = Catalog.media_path(path)
        if wanted.size()==6: break
    check(wanted.size()==6,"Recorded environment supplies six distinct original PNG requests")
    if wanted.size()!=6: return
    var original = {}
    for path in wanted:
        var image = Image.load_from_file(wanted[path])
        check(image!=null and not image.is_empty(),"Independent original PNG loads: "+path)
        if image==null or image.is_empty(): return
        original[path] = image
    var data = Media.create()
    Media.demand(data,wanted,wanted)
    check(not Media.ready(data,wanted),"Queued original sources are not render-ready")
    check(Media.poll(data).is_empty() and Media.diagnostics(data).decode_jobs==wanted.size(),
        "Six real PNG requests dispatch six single-image workers inside the current eight-worker limit before any publication")
    var published = []
    var peak = int(Media.diagnostics(data).decode_jobs)
    for _index in wanted.size():
        var result = await loaded(data)
        peak = maxi(peak,int(Media.diagnostics(data).decode_jobs))
        var expected: String = result.get("path","")
        check(result.has("image") and wanted.has(expected) and expected not in published,"Concurrent completion publishes one requested original: "+expected)
        if not result.has("image"): Media.close(data); return
        var reference: Image = original[expected]
        check(result.image.get_size()==reference.get_size() and result.image.get_format()==reference.get_format()
            and result.image.get_data()==reference.get_data(),"Worker pixels match independently loaded original bytes: "+expected)
        check(not Media.ready(data,{expected:true}),"Decoded source stays unavailable before caller publication: "+expected)
        Media.published(data,result)
        check(Media.ready(data,{expected:true}),"Caller publication makes only its completed source ready: "+expected)
        published.append(result.path)
        check(int(Media.diagnostics(data).decode_jobs)<=Media.DECODE_WORKERS,"Concurrent worker count remains bounded through refill")
    check(published.size()==wanted.size() and published.all(func(path):return wanted.has(path)) and Media.physical(data).decoded==6 and data.pending.is_empty() and data.decode_jobs.is_empty()
        and Media.ready(data,wanted),"Every original request publishes once with complete final readiness")
    Media.close(data)
    var closing = Media.create()
    Media.demand(closing,wanted,wanted)
    Media.poll(closing)
    check(Media.diagnostics(closing).decode_jobs==wanted.size() and Media.diagnostics(closing,true).pending==wanted.size(),"Close fixture owns bounded workers and accounts for every unpublished request")
    var started = Time.get_ticks_msec()
    Media.close(closing)
    check(closing.decode_jobs.is_empty() and closing.pending.is_empty() and closing.queued.is_empty()
        and Media.poll(closing).is_empty() and not Media.ready(closing,wanted),"Close joins every owned worker and never publishes unfinished sources")
    parallel_evidence = {"sources":wanted.keys(),"publication_order":published,"worker_limit":Media.DECODE_WORKERS,
        "observed_peak":peak,"close_ms":Time.get_ticks_msec()-started}

func finite_batches(environment:Dictionary)->void:
    var source:String=environment.required.keys()[0]
    var absolute:String=Catalog.media_path(source)
    var reference:Image=Image.load_from_file(absolute)
    var wanted:Dictionary={}
    for i in 18:wanted["batch-source-"+str(i)]=absolute
    var data=Media.create()
    Media.demand(data,wanted,wanted)
    Media.poll(data,false,false)
    var deadline=Time.get_ticks_msec()+10000
    while not data.decode_jobs.all(func(job):return WorkerThreadPool.is_task_completed(job.task)) and Time.get_ticks_msec()<deadline:await process_frame
    var completed:int=0
    for job in data.decode_jobs:completed+=job.result.get("images",[]).size()
    check(completed==16 and data.pending.size()==2 and data.decode_jobs.size()==Media.DECODE_WORKERS,
        "Eight finite workers decode sixteen real PNGs without a scene publication or per-image redispatch")
    check(data.resident.is_empty() and not Media.ready(data,wanted) and Media.diagnostics(data,true).pending==18,
        "Completed batches preserve exact unpublished readiness and pending accounting")
    # Cancellation can discard later members of an already completed batch.
    var remaining:Dictionary={}
    for i in [3,7,11,15,17]:remaining["batch-source-"+str(i)]=absolute
    Media.demand(data,remaining,remaining)
    var published:Array=[]
    deadline=Time.get_ticks_msec()+10000
    while (not data.decode_jobs.is_empty() or not data.pending.is_empty()) and Time.get_ticks_msec()<deadline:
        var result:Dictionary=Media.poll(data)
        if result.is_empty():await process_frame;continue
        check(remaining.has(result.path) and not published.has(result.path),"Changed demand publishes each retained batch member once")
        check(result.image.get_data()==reference.get_data(),"Batch worker preserves original PNG pixels")
        check(not Media.ready(data,{result.path:true}),"Completed batch member is not ready before publication")
        Media.published(data,result);published.append(result.path)
    check(published.size()==remaining.size() and Media.ready(data,remaining) and data.queued.is_empty(),
        "Changed demand drains retained sources and discards cancelled unpublished batch members")
    Media.close(data)

func held_decode(request: Dictionary, result: Dictionary, release: Semaphore) -> void:
    release.wait()
    Media._decode(request,result)

func completed_later(environment: Dictionary, optional_slots: bool) -> void:
    # Fill the actual pool and hold one genuine PNG worker, rather than relying
    # on scheduler timing or image size. The other seven complete first.
    var paths: Array = environment.required.keys().slice(0,Media.DECODE_WORKERS+2)
    check(paths.size()==Media.DECODE_WORKERS+2,"Original environment provides ten distinct full-pool/queued-worker sources")
    if paths.size()!=Media.DECODE_WORKERS+2:return
    var all_paths = {}; var wanted = {}
    for i in paths.size():
        all_paths[paths[i]] = Catalog.media_path(paths[i])
        if not optional_slots or i in [0,Media.DECODE_WORKERS,Media.DECODE_WORKERS+1]: wanted[paths[i]] = all_paths[paths[i]]
    var data = Media.create()
    Media.adopt_encounter(data,{"revision":1,"paths":all_paths,"environment":all_paths,
        "estimates":Encounter.estimates(all_paths,all_paths,{},{}),"errors":[]},1)
    Media.demand(data,wanted,all_paths)
    Media.prepare_optional(data)
    var requests = {}
    for request in data.pending: requests[request.path] = request
    data.pending.clear()
    for i in [Media.DECODE_WORKERS,Media.DECODE_WORKERS+1]: data.pending.append(requests[paths[i]])
    var release = Semaphore.new()
    for i in range(Media.DECODE_WORKERS):
        var result = {}
        var request: Dictionary = requests[paths[i]]
        var work = held_decode.bind(request,result,release) if i==0 else Media._decode.bind(request,result)
        var task = WorkerThreadPool.add_task(work)
        data.decode_jobs.append({"task":task,"path":paths[i],"result":result})
    var deadline = Time.get_ticks_msec()+10000
    while data.decode_jobs.slice(1).any(func(job):return not WorkerThreadPool.is_task_completed(job.task)) and Time.get_ticks_msec()<deadline:
        await process_frame
    var prefix = "Completed optional slots" if optional_slots else "Slow first required"
    check(not WorkerThreadPool.is_task_completed(data.decode_jobs[0].task),prefix+": first worker remains deliberately held")
    var next:Dictionary
    if optional_slots:
        # Full decode slots contain completed optional results, while two
        # required requests wait. The existing priority contract reclaims one
        # completed slot; withholding publication must still preserve it.
        check(not Media.physical(data).worker_upload,"Role fixture uses the original CPU-only worker path")
        check(Media.poll(data,true,false).is_empty() and data.decode_jobs.size()==Media.DECODE_WORKERS and data.pending.size()==2,
            prefix+": no publication allowance leaves completed optional slots owned")
        next=Media.poll(data,true)
        check(next.get("path")==paths[1] and next.has("image"),
            prefix+": required-only poll reclaims exactly one completed optional slot blocking required work")
        check(not Media.ready(data,{paths[1]:true}),prefix+": reclaim does not publish optional readiness")
    else:next=Media.poll(data)
    check(next.get("path")==paths[1] and next.has("image"),prefix+": ready later worker publishes without the held first worker")
    var published:Dictionary={}
    if next.has("image"): Media.published(data,next);published[next.path]=true
    check(data.decode_jobs.size()==Media.DECODE_WORKERS and data.decode_jobs.any(func(job):return job.path==paths[Media.DECODE_WORKERS]),prefix+": freed slot immediately admits queued required work")
    check(not Media.ready(data,wanted) and not Media.boot_ready(data),prefix+": missing required image still holds exact readiness and boot")
    if optional_slots:
        deadline=Time.get_ticks_msec()+10000
        while data.decode_jobs.any(func(job):return job.path==paths[Media.DECODE_WORKERS] and not WorkerThreadPool.is_task_completed(job.task)) and Time.get_ticks_msec()<deadline:
            await process_frame
        var required = Media.poll(data,true)
        check(required.get("path")==paths[Media.DECODE_WORKERS] and required.has("image"),prefix+": newly ready required result precedes completed optional results")
        if required.has("image"): Media.published(data,required);published[required.path]=true
    release.post()
    while not data.decode_jobs.is_empty() or not data.pending.is_empty():
        var result = await loaded(data)
        if result.is_empty(): check(false,prefix+": remaining original workers complete"); break
        check(not published.has(result.path),prefix+": no repeated source publication")
        published[result.path]=true
        if result.has("image"):
            check(result.image.get_data()==Image.load_from_file(all_paths[result.path]).get_data(),prefix+": original image bytes preserved")
            Media.published(data,result)
    check(Media.ready(data,wanted) and Media.boot_ready(data) and Media.physical(data).decoded==paths.size(),prefix+": final required gate completes after all originals publish once")
    Media.close(data)

func externally_satisfied_worker(path:String) -> void:
    var data:Dictionary=Media.create()
    var exact:Dictionary={path:Catalog.media_path(path)}
    var encounter:Dictionary={"revision":1,"paths":exact,"environment":{path:true},"fixtures":{},"gpu_only":{},"cpu_required":{path:true},
        "estimates":Encounter.estimates(exact,{path:true},{},{}),"errors":[]}
    encounter.estimate_summary=Encounter.estimate_summary(encounter)
    Media.adopt_encounter(data,encounter,1)
    Media.demand(data,exact,{path:true})
    Media.poll(data)
    check(data.decode_jobs.size()==1 and data.pending.is_empty() and data.queued.has(path),
        "External-publication fixture retains one real PNG worker owner")
    var image:Image=Image.new()
    check(image.load(Catalog.media_path(path))==OK,"External publication reads the same actual PNG")
    var loaded_source:Dictionary={"path":path,"cpu_bytes":image.get_data_size(),"gpu_bytes":image.get_width()*image.get_height()*4}
    Media.published(data,loaded_source)
    var noops:int=data.demand_noops
    Media.demand(data,exact,{path:true})
    check(data.demand_noops==noops+1 and Media.ready(data,exact) and data.queued.has(path) and data.decode_jobs.size()==1,
        "Satisfied external publication keeps immutable demand eligible without releasing an active worker")
    check(Media.diagnostics(data,true).pending==1,"Active worker remains accounted after external publication")
    var completed:Dictionary=await loaded(data)
    check(completed.has("image") and completed.image.get_data()==image.get_data(),
        "Retained worker completion preserves the exact external PNG bytes")
    if completed.has("image"):Media.published(data,completed)
    check(data.queued.is_empty() and Media.diagnostics(data,true).pending==0 and Media.ready(data,exact),
        "Ordinary worker completion clears ownership once without losing published readiness")
    Media.close(data)

func removed_optional_cpu(path:String) -> void:
    var data:Dictionary=Media.create()
    var absolute:String=Catalog.media_path(path)
    var estimates:Dictionary=Encounter.estimates({path:absolute},{path:true},{},{})
    for synthetic in ["a","c","outside"]:estimates[synthetic]={"bytes":16}
    var family:Dictionary={"revision":1,"paths":{"a":"/test/a.png",path:absolute,"c":"/test/c.png"},
        "environment":{},"fixtures":{},"gpu_only":{path:true},"cpu_required":{},"errors":[],"estimates":estimates}
    family.estimate_bytes=Encounter.estimate_bytes(estimates)
    family.estimate_summary=Encounter.estimate_summary(family)
    for field in ["paths","environment","fixtures","gpu_only","cpu_required","estimate_bytes","estimate_summary"]:family[field].make_read_only()
    family.selection_index=Encounter.selection_index(family)
    family.selection_index.positions.make_read_only();family.selection_index.ordered_paths.make_read_only()
    family.selection_index.make_read_only();family.make_read_only()
    data.budget_bytes=int(estimates[path].bytes)+32
    Media.adopt_encounter(data,family,1)
    var old:Dictionary={"a":"/test/a.png",path:absolute,"outside":"/test/outside.png"}
    Media.demand(data,old)
    for synthetic in ["a","outside"]:Media.published(data,{"path":synthetic,"cpu_bytes":8,"gpu_bytes":8})
    var original:Dictionary=await loaded(data)
    check(original.has("image") and original.path==path,"Removed-role fixture decodes actual original PNG with initial CPU ownership")
    if not original.has("image"):Media.close(data);return
    Media.published(data,original);Media.boot_ready(data);Media.demand(data,old)
    # Used colour pixels are retained under budget. Explicit pressure, with no
    # current CPU role, is what now permits their retirement; optional source
    # ownership must not be mistaken for permission to discard required pixels.
    data.budget_bytes=int(original.gpu_bytes)+48
    Media.demand(data,old,{},{},{path:true})
    Media.prepare_optional(data)
    check(Media.release_cold_images(data,-1)==[path] and data.resident[path].cpu_bytes==0,
        "Actual GPU-only role under explicit byte pressure releases only its unrequired CPU copy")
    var current:Dictionary={"a":"/test/a.png"}
    var cpu_family:Dictionary=family.duplicate(true)
    cpu_family.gpu_only={};cpu_family.cpu_required={path:true};cpu_family.make_read_only()
    data.budget_bytes=int(original.gpu_bytes)+int(original.cpu_bytes)+48
    Media.adopt_encounter(data,cpu_family,1)
    Media.demand(data,current)
    Media.published(data,{"path":"c","cpu_bytes":8,"gpu_bytes":8})
    var deadline:int=Time.get_ticks_msec()+10000
    while not data.pending.any(func(request):return request.path==path) and Time.get_ticks_msec()<deadline:
        Media.prepare_optional(data)
        if not data.pending.any(func(request):return request.path==path):await process_frame
    check(data.preload_selected.has(path) and Media.ready(data,current),
        "Actual CPU-family replacement retains capped optional source without holding current received source")
    check(not data.selected_ready.has(path) and data.pending.size()==1 and data.pending[0].path==path,
        "A newly required optional CPU role truthfully queues its missing image even with no old backlog")
    var restored:Dictionary=await loaded(data)
    check(restored.has("image") and restored.path==path and restored.image.get_data()==original.image.get_data(),
        "Optional CPU recovery preserves exact original PNG pixels")
    if restored.has("image"):Media.published(data,restored)
    check(Media.ready(data,current) and data.selected_ready.has(path) and data.resident[path].cpu_bytes>0 \
        and data.pending.is_empty() and Media.diagnostics(data).pinned_bytes<=data.budget_bytes,
        "Recovered removed-role source restores CPU readiness and exact capped accounting")
    Media.close(data)

func run() -> void:
    var journal=Journal.new()
    var opened:Dictionary=journal.open(Fixtures.journal("door"),true,false)
    check(opened.ok,"Durable original schema16 door journal opens")
    if not opened.ok:quit(1);return
    var folded:Dictionary=journal.replay(0)
    check(folded.ok,"Original disclosed fixture sources fold through the current SDK")
    if not folded.ok:quit(1);return
    var environment = EnvironmentMedia.plan(journal.state,[],{})
    var path: String = environment.fixtures.keys()[0]
    var data = Media.create()
    var exact = {path:Catalog.media_path(path)}
    var encounter = {"revision":1,"paths":exact,"environment":{path:true},"fixtures":{},"gpu_only":{},"cpu_required":{path:true},
        "estimates":Encounter.estimates(exact,{path:true},{},{}),"errors":[]}
    encounter.estimate_summary = Encounter.estimate_summary(encounter)
    Media.adopt_encounter(data,encounter,1)
    Media.demand(data,{path:Catalog.media_path(path)},{path:true})
    check(Media.poll(data).is_empty() and data.decode_jobs.size()==1 and data.decode_jobs[0].path==path,"Original source decode is dispatched with the colour-only role")
    # The worker now owns its immutable request; even a fast completed worker
    # cannot retroactively acquire the role below before its result is polled.
    Media.demand(data,{path:Catalog.media_path(path)},{path:true},{path:true})
    check(data.pending.is_empty() and data.queued.has(path),"Promotion retains the existing in-flight source request")
    Media.demand(data,{path:Catalog.media_path(path)},{path:true},{path:true})
    check(data.demand_noops==1 and data.decode_jobs.size()==1,"Identical promoted demand is a no-op while original worker remains in flight")
    var first = await loaded(data)
    check(first.has("image") and not first.has("energy") and not first.has("emission_centroid"),"First real worker result retains its original role")
    if not first.has("image"): Media.close(data); quit(1); return
    Media.published(data,first)
    check(not Media.ready(data,{path:true}) and data.pending.size()==1 and data.pending[0].fixture,
        "Unsatisfied publication immediately queues exactly the required fixture preprocessing")
    check(Media.diagnostics(data,true).pending==1,"Replacement work is accounted once")
    var noops: int = data.demand_noops
    Media.demand(data,{path:Catalog.media_path(path)},{path:true},{path:true})
    var corrective:Dictionary=data.pending[0]
    check(data.demand_noops==noops+1 and data.pending.size()==1 and corrective.fixture and not Media.ready(data,{path:true}),
        "Identical immutable demand preserves the exact corrective fixture request and truthful not-ready state")
    Media.demand(data,{path:Catalog.media_path(path)},{path:true},{path:true})
    check(data.demand_noops==noops+2 and data.pending.size()==1 and is_same(data.pending[0],corrective),"Repeated corrective demand does not duplicate or replace its exact worker request")
    var second = await loaded(data)
    check(second.has("image") and second.has("energy") and second.has("emission_centroid"),"Existing worker completes the upgraded role without a new scene plan")
    if second.has("image"):
        Media.published(data,second)
        Media.demand(data,{path:Catalog.media_path(path)},{path:true},{path:true})
        check(data.demand_noops==noops+3,"Complete fixture publication keeps the exact demand no-op eligible")
        check(second.image.get_data()==first.image.get_data(),"Role preprocessing preserves original source pixels")
        check(Media.ready(data,{path:true}) and data.pending.is_empty() and data.queued.is_empty(),"Newest mandatory role becomes ready with no repeat loop")
        check(Media.physical(data).decoded==2 and Media.diagnostics(data,true).pending==0 and Media.diagnostics(data,true).resident_sheets==1,
            "Two worker requests retain one original source residency and truthful queue accounting")
    Media.close(data)
    await removed_optional_cpu(path)
    await externally_satisfied_worker(path)
    await parallel_sources(environment)
    await finite_batches(environment)
    await completed_later(environment,false)
    await completed_later(environment,true)
    var report = {"checks":checks,"failures":failures,"source":path,"parallel":parallel_evidence,
        "scope":"Actual PNG worker dispatch, role promotion, bounded completion-driven publication, original bytes and close; caller publication acknowledgements require no GPU allocation."}
    FileAccess.open("res://generated/media_role_race_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
