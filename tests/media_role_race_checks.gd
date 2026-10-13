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
    for expected in wanted:
        var result = await loaded(data)
        peak = maxi(peak,int(Media.diagnostics(data).decode_jobs))
        check(result.has("image") and result.get("path")==expected,"Concurrent completion is published in original demand order: "+expected)
        if not result.has("image"): Media.close(data); return
        var reference: Image = original[expected]
        check(result.image.get_size()==reference.get_size() and result.image.get_format()==reference.get_format()
            and result.image.get_data()==reference.get_data(),"Worker pixels match independently loaded original bytes: "+expected)
        check(not Media.ready(data,{expected:true}),"Decoded source stays unavailable before caller publication: "+expected)
        Media.published(data,result)
        check(Media.ready(data,{expected:true}),"Caller publication makes only its completed source ready: "+expected)
        published.append(result.path)
        check(int(Media.diagnostics(data).decode_jobs)<=4,"Concurrent worker count remains bounded through refill")
    check(published==wanted.keys() and data.decoded==6 and data.pending.is_empty() and data.decode_jobs.is_empty()
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
    var report = {"checks":checks,"failures":failures,"source":path,"parallel":parallel_evidence,
        "scope":"Actual PNG worker dispatch, role promotion, bounded parallel publication order, original bytes and close; caller publication acknowledgements require no GPU allocation."}
    FileAccess.open("res://generated/media_role_race_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
