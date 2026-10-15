extends SceneTree
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Protocol = preload("res://sdk/protocol.gd")
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
    check(Media.poll(data).is_empty() and Media.diagnostics(data).decode_jobs==4,
        "Six real PNG requests dispatch exactly four owned workers before any publication")
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
        check(int(Media.diagnostics(data).decode_jobs)<=4,"Concurrent worker count remains bounded through refill")
    check(published.size()==wanted.size() and published.all(func(path):return wanted.has(path)) and data.decoded==6 and data.pending.is_empty() and data.decode_jobs.is_empty()
        and Media.ready(data,wanted),"Every original request publishes once with complete final readiness")
    Media.close(data)
    var closing = Media.create()
    Media.demand(closing,wanted,wanted)
    Media.poll(closing)
    check(Media.diagnostics(closing).decode_jobs==4 and closing.pending.size()==2,"Close fixture owns four actual workers and two undispatched requests")
    var started = Time.get_ticks_msec()
    Media.close(closing)
    check(closing.decode_jobs.is_empty() and closing.pending.is_empty() and closing.queued.is_empty()
        and Media.poll(closing).is_empty() and not Media.ready(closing,wanted),"Close joins every owned worker and never publishes unfinished sources")
    parallel_evidence = {"sources":wanted.keys(),"publication_order":published,"worker_limit":4,
        "observed_peak":peak,"close_ms":Time.get_ticks_msec()-started}

func held_decode(request: Dictionary, result: Dictionary, release: Semaphore) -> void:
    release.wait()
    Media._decode(request,result)

func completed_later(environment: Dictionary, optional_slots: bool) -> void:
    # Hold one genuine PNG worker, rather than relying on scheduler timing or
    # image size. The other three complete before any publication is attempted.
    var paths: Array = environment.required.keys().slice(0,6)
    var all_paths = {}; var wanted = {}
    for i in paths.size():
        all_paths[paths[i]] = Catalog.media_path(paths[i])
        if not optional_slots or i in [0,4,5]: wanted[paths[i]] = all_paths[paths[i]]
    var data = Media.create()
    Media.adopt_encounter(data,{"revision":1,"paths":all_paths,"environment":all_paths,
        "estimates":Encounter.estimates(all_paths,all_paths,{},{}),"errors":[]},1)
    Media.demand(data,wanted,all_paths)
    var requests = {}
    for request in data.pending: requests[request.path] = request
    data.pending.clear()
    for i in [4,5]: data.pending.append(requests[paths[i]])
    var release = Semaphore.new()
    for i in range(4):
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
        check(not data.worker_upload,"Role fixture uses the original CPU-only worker path")
        check(Media.poll(data,true,false).is_empty() and data.decode_jobs.size()==4 and data.pending.size()==2,
            prefix+": no publication allowance leaves completed optional slots owned")
        next=Media.poll(data,true)
        check(next.get("path")==paths[1] and next.has("image"),
            prefix+": required-only poll reclaims exactly one completed optional slot blocking required work")
        check(not Media.ready(data,{paths[1]:true}),prefix+": reclaim does not publish optional readiness")
    else:next=Media.poll(data)
    check(next.get("path")==paths[1] and next.has("image"),prefix+": ready later worker publishes without the held first worker")
    var published:Dictionary={}
    if next.has("image"): Media.published(data,next);published[next.path]=true
    check(data.decode_jobs.size()==4 and data.decode_jobs.any(func(job):return job.path==paths[4]),prefix+": freed slot immediately admits queued required work")
    check(not Media.ready(data,wanted) and not Media.boot_ready(data),prefix+": missing required image still holds exact readiness and boot")
    if optional_slots:
        deadline=Time.get_ticks_msec()+10000
        while data.decode_jobs.any(func(job):return job.path==paths[4] and not WorkerThreadPool.is_task_completed(job.task)) and Time.get_ticks_msec()<deadline:
            await process_frame
        var required = Media.poll(data,true)
        check(required.get("path")==paths[4] and required.has("image"),prefix+": newly ready required result precedes completed optional results")
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
    check(Media.ready(data,wanted) and Media.boot_ready(data) and data.decoded==6,prefix+": final required gate completes after all originals publish once")
    Media.close(data)

func run() -> void:
    var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json"))
    check(parsed.ok,"Actual disclosed fixture source state parses")
    if not parsed.ok: quit(1); return
    var environment = EnvironmentMedia.plan(parsed.value,[],{})
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
    check(data.demand_noops==noops and data.pending.size()==1 and data.pending[0].fixture,
        "Corrective fixture requeue invalidates no-op and retains exact mandatory priority")
    Media.demand(data,{path:Catalog.media_path(path)},{path:true},{path:true})
    check(data.demand_noops==noops+1 and data.pending.size()==1,"Repeated corrective demand does not duplicate its exact worker request")
    var second = await loaded(data)
    check(second.has("image") and second.has("energy") and second.has("emission_centroid"),"Existing worker completes the upgraded role without a new scene plan")
    if second.has("image"):
        Media.published(data,second)
        Media.demand(data,{path:Catalog.media_path(path)},{path:true},{path:true})
        check(data.demand_noops==noops+2,"Complete fixture publication keeps the exact demand no-op eligible")
        check(second.image.get_data()==first.image.get_data(),"Role preprocessing preserves original source pixels")
        check(Media.ready(data,{path:true}) and data.pending.is_empty() and data.queued.is_empty(),"Newest mandatory role becomes ready with no repeat loop")
        check(data.decoded==2 and Media.diagnostics(data,true).pending==0 and Media.diagnostics(data,true).resident_sheets==1,
            "Two worker requests retain one original source residency and truthful queue accounting")
    Media.close(data)
    await parallel_sources(environment)
    await completed_later(environment,false)
    await completed_later(environment,true)
    var report = {"checks":checks,"failures":failures,"source":path,"parallel":parallel_evidence,
        "scope":"Actual PNG worker dispatch, role promotion, bounded completion-driven publication, original bytes and close; caller publication acknowledgements require no GPU allocation."}
    FileAccess.open("res://generated/media_role_race_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
