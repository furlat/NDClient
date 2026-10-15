extends SceneTree
# Passive queue/selection fixtures compare the shortcut with the original full
# demand body frozen at 927a55b, without PNG/GPU work.
const Media = preload("res://presentation/media_warmup.gd")
const Reference = preload("res://tests/media_demand_reference.gd")
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
    result.estimate_bytes = Encounter.estimate_bytes(result.estimates)
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
    Reference.demand(reference,paths,roles[0],roles[1],roles[2],roles[3])
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
    demand("Already decoded publication cancels queued duplicate",{"a":"/test/a.png"},[{},{},{},{}],true)
    check(fast.pending.all(func(request):return request.path!="a") and Media.ready(fast,{"a":true}),
        "Caller publication while pending removes redundant original request")

    reset(plan)
    demand("Optional external publication baseline",{"a":"/test/a.png"})
    for data in [fast,reference]:
        Media.diagnostics(data)
        Media.published(data,{"path":"b","cpu_bytes":8,"gpu_bytes":8})
    check(fast.pending.map(func(request):return request.path)==["a","c"] and not fast.queued.has("b"),
        "Satisfied optional publication removes only its request and preserves mandatory/tail order")
    check(Media.diagnostics(fast).pending==2 and fast.selected_ready.has("b"),
        "Optional publication updates pending accounting and exact selected readiness immediately")
    demand("Optional publication retains unchanged exact demand",{"a":"/test/a.png"},[{},{},{},{}],true)
    demand("Mandatory promotion after optional publication",{"c":"/test/c.png","a":"/test/a.png"})
    check(fast.pending.map(func(request):return request.path)==["c","a"],
        "Real required order changes still promote mandatory work after optional publication")

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

    reset(plan,80)
    demand("Warm family before a newly admitted source",{"a":"/test/a.png"})
    publish("a");publish("b");publish("c")
    for data in [fast,reference]: Media.boot_ready(data)
    # The required worker already knows this source's PNG size. Optional family
    # discovery has not included it yet; retain the same capped warm selection.
    for data in [fast,reference]: Media.adopt_source_sizes(data,{"d":16},1)
    demand("Required header arrives before optional family",{"d":"/test/d.png"})
    check(fast.unknown_required==0 and fast.preload_selected.size()==3 and fast.pending.map(func(row):return row.path)==["d"],
        "New known-size required source keeps warm optional textures and queues only its own bytes")
    check(fast.required_estimated_bytes==32 and not Media.ready(fast,{"d":true}),
        "Header includes CPU plus GPU budget but grants no texture readiness")
    demand("Same header with GPU-only role",{"d":"/test/d.png"},[{},{},{"d":true},{}])
    check(fast.required_estimated_bytes==16,"Header budget uses the current exact CPU role")
    for data in [fast,reference]:data.budget_bytes=48
    demand("Header does not bypass finite cap",{"d":"/test/d.png"})
    check(fast.preload_selected.size()==1 and fast.required_estimated_bytes+fast.preload_estimated_bytes==48,
        "New required byte reservation still evicts optional selection when the real budget requires it")
    for data in [fast,reference]:Media.adopt_required(data,2)
    check(fast.source_sizes.is_empty(),"Required size metadata cannot leak across initialization epochs")

    reset(plan)
    demand("Accepted family baseline",{"a":"/test/a.png"})
    var equal_plan = plan.duplicate(true)
    for data in [fast,reference]: Media.adopt_encounter(data,equal_plan,1)
    demand("Equal immutable estimate owners",{"a":"/test/a.png"},[{},{},{},{}],true)
    demand("Repeated demand after equal family adoption",{"a":"/test/a.png"},[{},{},{},{}],true)
    var redistributed = equal_plan.duplicate(true)
    redistributed.estimates.a.bytes = 20; redistributed.estimates.b.bytes = 12
    redistributed.estimate_bytes = Encounter.estimate_bytes(redistributed.estimates)
    redistributed.estimate_summary = Encounter.estimate_summary(redistributed)
    for data in [fast,reference]: Media.adopt_encounter(data,redistributed,1)
    demand("Estimate redistribution with same total/revision",{"a":"/test/a.png"})
    check(fast.required_estimated_bytes==20,"Exact estimates, not only family sum, invalidate guard")
    var promoted = redistributed.duplicate(true)
    promoted.revision += 1; promoted.environment.c = true; promoted.fixtures.c = true
    for data in [fast,reference]: Media.adopt_encounter(data,promoted,1)
    demand("Family-only optional role promotion",{"a":"/test/a.png"})
    check(fast.pending.filter(func(row):return row.path=="c")[0].fixture,"Changed optional family role updates queued preprocessing")
    publish("c")
    demand("Family fixture still requires emission preprocessing",{"a":"/test/a.png"})
    check(not Media.ready(fast,{"c":true}),"Nonmandatory family fixture upgrade holds source readiness")
    var demoted = redistributed.duplicate(true)
    demoted.revision = promoted.revision+1
    for data in [fast,reference]: Media.adopt_encounter(data,demoted,1)
    demand("Family-only optional role removal",{"a":"/test/a.png"})
    check(Media.ready(fast,{"c":true}) and not fast.resident.c.environment,
        "Departing family fixture/environment roles restore readiness and source category")
    for data in [fast,reference]: Media.adopt_encounter(data,promoted,2)
    demand("New initialization epoch",{"a":"/test/a.png"})
    check(fast.boot_paths.keys()==["a"] and not fast.boot_complete,"New epoch retains its own exact startup gate")

    var unknown = family()
    unknown.estimates.a = {"error":"Typed missing header"}
    unknown.estimate_bytes = Encounter.estimate_bytes(unknown.estimates)
    unknown.estimate_summary = Encounter.estimate_summary(unknown)
    reset(unknown)
    demand("Unknown source estimate",{"a":"/test/a.png"})
    demand("Unknown estimate stays exhaustive",{"a":"/test/a.png"})
    publish("a")
    demand("Resident fallback estimate changes",{"a":"/test/a.png"})
    check(fast.required_estimated_bytes==16 and fast.unknown_required==0,"Publication updates required fallback estimate")

    reset(plan)
    demand("Nonmandatory exact role baseline",{"a":"/test/a.png"},[{"b":true},{"b":true},{},{}])
    publish("b")
    demand("Nonmandatory exact fixture requires metrics",{"a":"/test/a.png"},[{"b":true},{"b":true},{},{}])
    check(not Media.ready(fast,{"b":true}),"Exact role beyond wanted affects its selected source")
    demand("Departing exact roles beyond wanted",{"a":"/test/a.png"})
    check(not Media.ready(fast,{"b":true}) and fast.resident.b.environment,
        "Manual roles outside prior/current mandatory and selection-change domain retain original untouched residency")
    demand("Former mandatory role baseline",{"a":"/test/a.png","b":"/test/b.png"},[{"b":true},{"b":true},{},{}])
    demand("Departing prior mandatory roles",{"a":"/test/a.png"})
    check(Media.ready(fast,{"b":true}) and not fast.resident.b.environment,
        "A departing prior mandatory source still receives its role/category refresh")

    reset(plan)
    var gpu_roles = [{},{},{"a":true},{}]
    demand("Companion publication baseline",{"a":"/test/a.png"},gpu_roles)
    publish("a")
    check(Media.release_cold_images(fast)==Media.release_cold_images(reference),"GPU-only CPU images release identically")
    demand("CPU release keeps role-satisfied no-op",{"a":"/test/a.png"},gpu_roles,true)
    check(Media.ready(fast,{"a":true}),"GPU-only readiness survives CPU release")
    demand("CPU role upgrade reloads source",{"a":"/test/a.png"},[{},{},{},{"a":true}])
    check(not Media.ready(fast,{"a":true}) and fast.pending[0].path=="a","Required original CPU pixels are recovered")

    reset(plan)
    var mixed_paths={"a":"/test/a.png","b":"/test/b.png"}
    var mixed_roles=[{},{},{"b":true},{}]
    demand("Warm mandatory queue baseline",mixed_paths,mixed_roles)
    publish("a");publish("b")
    for data in [fast,reference]:Media.release_cold_images(data)
    demand("Warm mandatory order changes preserve optional backlog",{"b":"/test/b.png","a":"/test/a.png"},mixed_roles)
    check(fast.pending.map(func(row):return row.path)==["c"] and Media.ready(fast,mixed_paths),
        "Already-ready mandatory sheets do not requeue; original optional order remains")
    demand("Warm mandatory CPU upgrade bypasses ready shortcut",mixed_paths,[{},{},{"b":true},{"b":true}])
    check(fast.pending.map(func(row):return row.path)==["b","c"] and not Media.ready(fast,{"b":true}),
        "CPU upgrade queues its missing image before optional work despite warm GPU residency")
    publish("b")
    demand("Warm mandatory fixture upgrade bypasses ready shortcut",mixed_paths,[{},{"b":true},{"b":true},{"b":true}])
    check(fast.pending[0].path=="b" and fast.pending[0].fixture and not Media.ready(fast,{"b":true}),
        "Fixture upgrade queues actual emission preprocessing rather than trusting old colour readiness")
    publish("b",8,true)
    demand("Completed mandatory fixture leaves optional order intact",{"b":"/test/b.png","a":"/test/a.png"},[{},{"b":true},{"b":true},{"b":true}])
    check(fast.pending.map(func(row):return row.path)==["c"] and Media.ready(fast,mixed_paths),
        "Actual fixture publication acknowledges mandatory readiness without another decode")
    var covered_family=family()
    covered_family.cpu_required={"a":true}
    covered_family.gpu_only={"b":true}
    covered_family.environment={"c":true};covered_family.fixtures={"c":true}
    reset(covered_family)
    var all_paths:Dictionary=covered_family.paths.duplicate()
    demand("Family-owned readiness baseline",all_paths)
    publish("a");publish("b");publish("c",8,true)
    for data in [fast,reference]:Media.release_cold_images(data);Media.boot_ready(data)
    demand("Family-owned completed boot",all_paths)
    demand("Redundant exact family roles",all_paths,[{"c":true},{"c":true},{"a":true,"b":true,"c":true},{"a":true,"c":true}])
    check(fast.demand_counts.resident_refreshed==0 and Media.ready(fast,all_paths),
        "Family-covered exact role changes retain ready sources without rescanning residents")
    demand("Remove redundant exact family roles",all_paths)
    check(fast.demand_counts.resident_refreshed==0 and fast.cpu_release.is_empty(),
        "Family-covered role removals preserve readiness and CPU ownership")
    demand("Uncovered fixture still needs preprocessing",all_paths,[{},{"a":true},{},{}])
    check(not Media.ready(fast,{"a":true}) and fast.pending[0].fixture,
        "Family CPU ownership cannot hide a new fixture preprocessing requirement")
    publish("a",8,true)
    demand("Uncovered GPU-only source gains CPU role",all_paths,[{},{},{},{"b":true}])
    check(not Media.ready(fast,{"b":true}) and fast.pending[0].path=="b",
        "Family GPU-only role cannot hide an exact CPU requirement")
    publish("b")
    demand("Uncovered CPU role removal releases original pixels",all_paths)
    check(Media.release_cold_images(fast)==Media.release_cold_images(reference) and fast.resident.b.cpu_bytes==0,
        "Effective CPU role removal retains the original release result")
    var removed_cover=covered_family.duplicate(true)
    removed_cover.revision+=1;removed_cover.cpu_required={};removed_cover.fixtures={}
    for data in [fast,reference]:Media.adopt_encounter(data,removed_cover,1)
    demand("Family coverage removal still refreshes selected owners",all_paths,[{},{},{"a":true},{}])
    check(Media.release_cold_images(fast,-1)==Media.release_cold_images(reference,-1) and fast.resident.a.cpu_bytes==0,
        "Family role changes cannot reuse earlier covered-role readiness")

    reset(family(),16)
    demand("Deferred role initial selected source",{"a":"/test/a.png"})
    publish("a")
    for data in [fast,reference]:Media.boot_ready(data)
    publish("b")
    demand("Unselected resident retains deferred exact role",{"a":"/test/a.png"},[{"b":true},{},{},{}])
    for data in [fast,reference]:data.budget_bytes=32
    demand("Later optional selection applies deferred exact role",{"a":"/test/a.png"},[{"b":true},{},{},{}])
    check(fast.resident.b.environment and reference.resident.b.environment,
        "Membership refresh cannot reuse a category from before an out-of-demand role change")

    reset(plan)
    demand("Queued category ledger baseline",{"a":"/test/a.png"})
    var retained_stats:Dictionary=fast.stats
    demand("Queued exact environment category promotion",{"a":"/test/a.png"},[{"b":true},{},{},{}])
    check(is_same(fast.stats,retained_stats) and fast.stats[true].pending==1 and fast.stats[false].pending==2,
        "One actual pending category change preserves the resident accounting owner")
    demand("Queued exact environment category removal",{"a":"/test/a.png"})
    check(is_same(fast.stats,retained_stats) and fast.stats[true].pending==0 and fast.stats[false].pending==3,
        "Removing a pending environment role reverses only its category delta")
    var category_family=plan.duplicate(true)
    category_family.revision+=1
    category_family.environment={"c":true}
    for data in [fast,reference]:Media.adopt_encounter(data,category_family,1)
    demand("Changed accepted family environment category",{"a":"/test/a.png"})
    check(is_same(fast.stats,retained_stats) and fast.stats[true].pending==1 and fast.stats[false].pending==2,
        "Pending category ledger follows accepted family role ownership")

    var indexed_family={"revision":1,"paths":{},"estimates":{},"environment":{},"fixtures":{},"cpu_required":{},"gpu_only":{},"errors":[]}
    var amounts=[0,5,7,32,1,16,4,9]
    for i in amounts.size():
        var id:String="indexed-"+str(i)
        indexed_family.paths[id]="/test/"+id+".png"
        indexed_family.estimates[id]={"bytes":amounts[i]}
    indexed_family.estimate_bytes=Encounter.estimate_bytes(indexed_family.estimates)
    indexed_family.estimate_summary=Encounter.estimate_summary(indexed_family)
    indexed_family.selection_index=Encounter.selection_index(indexed_family)
    for limit in [0,1,7,17,31,48,64,96]:
        for required_ids in [[],[0],[3],[0,2],[1,4,7],[3,5,6],[0,1,2,3,4,5,6,7]]:
            reset(indexed_family,limit)
            var required:Dictionary={}
            for i in required_ids:required["indexed-"+str(i)]=indexed_family.paths["indexed-"+str(i)]
            demand("Indexed greedy cap %d required %s"%[limit,str(required_ids)],required)
            for data in [fast,reference]:Media.boot_ready(data)
            var next_required:Dictionary={"indexed-7":indexed_family.paths["indexed-7"]}
            for data in [fast,reference]:Media.adopt_source_sizes(data,{"outside-index":5},1)
            next_required["outside-index"]="/test/outside-index.png"
            demand("Indexed changed exact demand cap %d required %s"%[limit,str(required_ids)],next_required)

    var missing = "res://tests/no-such-demand-fixture.png"
    var failed_family = {"revision":1,"paths":{missing:missing},"estimates":{missing:{"bytes":8}},
        "estimate_bytes":{missing:8},"estimate_summary":{"bytes":8,"unknown":0},"errors":[]}
    reset(failed_family)
    demand("Failed source baseline",{missing:missing})
    for data in [fast,reference]:
        var deadline = Time.get_ticks_msec()+10000
        while not data.failed.has(missing) and Time.get_ticks_msec()<deadline:
            Media.poll(data)
            await process_frame
    demand("Actual failed decode retains error on no-op",{missing:missing},[{},{},{},{}],true)
    check(not Media.ready(fast,{missing:true}) and fast.selected_failed.has(missing) and fast.pending.is_empty(),
        "Worker failure remains explicit without duplicate retry or false readiness")
    var failed_message:String=fast.failed[missing]
    var failed_promotion=failed_family.duplicate(true)
    failed_promotion.revision=2;failed_promotion.fixtures={missing:true}
    for data in [fast,reference]:Media.adopt_encounter(data,failed_promotion,1)
    demand("Failed nonresident source receives new family roles",{missing:missing})
    check(fast.selected_failed.get(missing)==failed_message and not fast.ready_paths.has(missing) and fast.pending.is_empty(),
        "Single deferred refresh preserves failed-source diagnostics without admitting pixels or retrying")
    for data in [fast,reference]:Media.boot_ready(data);data.budget_bytes=0
    demand("Failed source leaves optional selection",{})
    check(fast.selected_failed.is_empty() and fast.failed.get(missing)==failed_message,
        "Removing selection removes its error badge but retains the actual source failure")
    for data in [fast,reference]:data.budget_bytes=8
    demand("Failed nonresident source is selected again",{missing:missing})
    check(fast.selected_failed.get(missing)==failed_message and not Media.ready(fast,{missing:true}) and fast.pending.is_empty(),
        "Re-admission restores failure ownership without stale readiness or duplicate queue work")
    Media.close(fast); Media.close(reference)
    var report = {"checks":checks,"failures":failures,
        "scope":"Passive typed queue/residency acknowledgements versus the independent frozen 927a55b demand body; exact ordered paths/roles, budgets, accepted estimates, epoch, boot and CPU recovery. Actual PNG in-flight promotion is covered by media_role_race_checks."}
    FileAccess.open("res://generated/media_demand_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
