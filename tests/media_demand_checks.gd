extends SceneTree
# Passive queue/selection fixtures compare the shortcut with the original full
# demand body (reference cache invalidated before each call), without PNG/GPU work.
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
var checks = 0
var failures: Array = []
var fast: Dictionary
var reference: Dictionary

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("MEDIA_DEMAND_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func family() -> Dictionary:
    var result = {"revision":1,"paths":{"a":"/test/a.png","b":"/test/b.png","c":"/test/c.png"},
        "environment":{},"fixtures":{},"gpu_only":{},"cpu_required":{},"errors":[],
        "estimates":{"a":{"bytes":16},"b":{"bytes":16},"c":{"bytes":16}}}
    result.estimate_summary = Encounter.estimate_summary(result)
    return result

func reset(plan: Dictionary, budget: int = 48) -> void:
    if not fast.is_empty(): Media.close(fast); Media.close(reference)
    fast = Media.create(); reference = Media.create()
    for data in [fast,reference]:
        data.budget_bytes = budget
        Media.adopt_encounter(data,plan,1)

func observable(data: Dictionary) -> Dictionary:
    var result = {}
    for key in ["pending","queued","wanted","environment","fixtures","gpu_only","cpu_required","failed",
        "preload_selected","preload_skipped","preload_estimated_bytes","required_estimated_bytes","unknown_required",
        "boot_paths","boot_started","boot_complete","ready_paths","boot_waiting","selected_ready","selected_failed"]:
        result[key] = data[key]
    for category in [false,true]:
        var stats = Media.diagnostics(data,category)
        for key in ["demand_runs","demand_noops","demand_phases","demand_counts","metadata_ms","decode_ms"]: stats.erase(key)
        result[str(category)] = stats
    return result

func demand(label: String, paths: Dictionary, roles: Array = [{},{},{},{}], noop: bool = false) -> void:
    var count: int = fast.demand_noops
    # Explicitly select the unchanged original exhaustive path, with identical
    # prior publication/selection state and request ordering in both instances.
    reference.demand_snapshot = {}
    Media.demand(fast,paths,roles[0],roles[1],roles[2],roles[3])
    Media.demand(reference,paths,roles[0],roles[1],roles[2],roles[3])
    check(observable(fast)==observable(reference),label+": queue, pins, estimates, readiness, errors and boot equal full demand")
    check((fast.demand_noops>count)==noop,label+": expected strict no-op eligibility")
    var phases: Dictionary = fast.demand_phases
    var elapsed = 0.0
    for phase in phases:
        if phase!="total": elapsed += phases[phase]
    check(phases.size()==9 and phases.values().all(func(value):return value>=-0.000001) and elapsed<=phases.total+0.000001,
        label+": last-call exclusive CPU phases fit their independently timed total")
    if noop:
        check(phases.estimate==0 and phases.queue==0 and phases.snapshot==0,
            label+": no-op reports no work in skipped demand phases")

func publish(path: String, gpu: int = 8, fixture: bool = false) -> void:
    # Typed caller publication acknowledgement; worker PNG correctness is tested
    # separately by media_role_race_checks using actual original source images.
    var loaded = {"path":path,"cpu_bytes":8,"gpu_bytes":gpu}
    if fixture: loaded.merge({"energy":.2,"emission_centroid":Vector2(2,3)})
    for data in [fast,reference]:
        data.pending = data.pending.filter(func(request):return request.path!=path)
        data.queued.erase(path)
        data.stats = {}
        Media.published(data,loaded)

func run() -> void:
    var plan = family()
    reset(plan)
    demand("Initial demand",{"a":"/test/a.png","b":"/test/b.png"})
    demand("Fresh equal caller maps",{"a":"/test/a.png","b":"/test/b.png"},[{},{},{},{}],true)
    demand("Priority reversal",{"b":"/test/b.png","a":"/test/a.png"})
    check(fast.pending[0].path=="b" and fast.pending[1].path=="a","Priority change reaches actual queued requests")
    demand("Stable reversed priority",{"b":"/test/b.png","a":"/test/a.png"},[{},{},{},{}],true)
    var caller_paths = {"b":"/test/b.png","a":"/test/a.png"}
    demand("Caller map before mutation",caller_paths,[{},{},{},{}],true)
    caller_paths.a = "/alternate/a.png"
    demand("Absolute source path mutation",caller_paths)
    check(fast.pending[1].absolute=="/alternate/a.png","Changed original path is used by queued source request")
    var roles = [{"a":true},{},{},{}]
    demand("Environment role promotion",caller_paths,roles)
    demand("Stable environment role",caller_paths,roles,true)
    roles[1].a = true
    demand("Caller-owned fixture map mutation",caller_paths,roles)
    demand("Stable fixture role",caller_paths,roles,true)
    check(fast.pending[1].fixture,"New exact fixture demand captures preprocessing in queued request")
    roles[2].b = true
    demand("GPU-only role change",caller_paths,roles)
    roles[3].b = true
    demand("Explicit CPU role change",caller_paths,roles)

    reset(plan)
    demand("Decode progress baseline",{"a":"/test/a.png"})
    publish("a")
    demand("Complete publication keeps no-op",{"a":"/test/a.png"},[{},{},{},{}],true)
    check(Media.ready(fast,{"a":true}),"Unchanged demand sees newly published readiness")
    check(Media.boot_ready(fast)==Media.boot_ready(reference),"Boot completes independently of demand")
    demand("Boot transition gets full processing",{"a":"/test/a.png"})
    demand("Completed boot stays stable",{"a":"/test/a.png"},[{},{},{},{}],true)
    publish("a",0)
    demand("Incomplete pinned publication retries",{"a":"/test/a.png"})
    check(fast.pending[0].path=="a" and not Media.ready(fast,{"a":true}),"Missing GPU publication queues exact source again")

    reset(plan)
    demand("Externally satisfied pending baseline",{"a":"/test/a.png"})
    for data in [fast,reference]: Media.published(data,{"path":"a","cpu_bytes":8,"gpu_bytes":8})
    demand("Already decoded publication cancels queued duplicate",{"a":"/test/a.png"})
    check(fast.pending.all(func(request):return request.path!="a") and Media.ready(fast,{"a":true}),
        "Caller publication while pending removes redundant original request")

    reset(plan,16)
    demand("Capped optional family",{"a":"/test/a.png"})
    publish("a")
    Media.boot_ready(fast); Media.boot_ready(reference)
    demand("Complete capped boot",{"a":"/test/a.png"})
    demand("Capped stable demand",{"a":"/test/a.png"},[{},{},{},{}],true)
    demand("New mandatory source with skipped preloads",{"b":"/test/b.png"})
    check(fast.preload_skipped==2 and fast.preload_selected.keys()==["b"] and fast.pending[0].path=="b",
        "Changed mandatory demand reselects finite budget before optional work")
    for data in [fast,reference]: data.budget_bytes = 48
    demand("Raised budget selects deferred family",{"b":"/test/b.png"})
    check(fast.preload_selected.size()==3 and fast.preload_skipped==0,"Larger budget includes all finite known sources")
    for data in [fast,reference]: data.budget_bytes = 0
    demand("Zero optional budget",{"b":"/test/b.png"})
    check(fast.preload_selected.keys()==["b"],"Mandatory source remains pinned over zero optional budget")

    reset(plan)
    demand("Accepted family baseline",{"a":"/test/a.png"})
    var equal_plan = plan.duplicate(true)
    for data in [fast,reference]: Media.adopt_encounter(data,equal_plan,1)
    demand("Equal immutable estimate owners",{"a":"/test/a.png"},[{},{},{},{}],true)
    var redistributed = equal_plan.duplicate(true)
    redistributed.estimates.a.bytes = 20; redistributed.estimates.b.bytes = 12
    redistributed.estimate_summary = Encounter.estimate_summary(redistributed)
    for data in [fast,reference]: Media.adopt_encounter(data,redistributed,1)
    demand("Estimate redistribution with same total/revision",{"a":"/test/a.png"})
    check(fast.required_estimated_bytes==20,"Exact estimates, not only family sum, invalidate guard")
    var promoted = redistributed.duplicate(true)
    promoted.revision += 1; promoted.environment.c = true; promoted.fixtures.c = true
    for data in [fast,reference]: Media.adopt_encounter(data,promoted,1)
    demand("Family-only optional role promotion",{"a":"/test/a.png"})
    check(fast.pending.filter(func(row):return row.path=="c")[0].fixture,"Changed optional family role updates queued preprocessing")
    for data in [fast,reference]: Media.adopt_encounter(data,promoted,2)
    demand("New initialization epoch",{"a":"/test/a.png"})
    check(fast.boot_paths.keys()==["a"] and not fast.boot_complete,"New epoch retains its own exact startup gate")

    var unknown = family()
    unknown.estimates.a = {"error":"Typed missing header"}
    unknown.estimate_summary = Encounter.estimate_summary(unknown)
    reset(unknown)
    demand("Unknown source estimate",{"a":"/test/a.png"})
    demand("Unknown estimate stays exhaustive",{"a":"/test/a.png"})
    publish("a")
    demand("Resident fallback estimate changes",{"a":"/test/a.png"})
    check(fast.required_estimated_bytes==16 and fast.unknown_required==0,"Publication updates required fallback estimate")

    reset(plan)
    var gpu_roles = [{},{},{"a":true},{}]
    demand("Companion publication baseline",{"a":"/test/a.png"},gpu_roles)
    publish("a")
    check(Media.release_cold_images(fast)==Media.release_cold_images(reference),"GPU-only CPU images release identically")
    demand("CPU release keeps role-satisfied no-op",{"a":"/test/a.png"},gpu_roles,true)
    check(Media.ready(fast,{"a":true}),"GPU-only readiness survives CPU release")
    demand("CPU role upgrade reloads source",{"a":"/test/a.png"},[{},{},{},{"a":true}])
    check(not Media.ready(fast,{"a":true}) and fast.pending[0].path=="a","Required original CPU pixels are recovered")
    Media.close(fast); Media.close(reference)
    var report = {"checks":checks,"failures":failures,
        "scope":"Passive typed queue/residency acknowledgements versus the original exhaustive demand body; exact ordered paths/roles, budgets, accepted estimates, epoch, boot and CPU recovery. Actual PNG in-flight promotion is covered by media_role_race_checks."}
    FileAccess.open("res://generated/media_demand_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
