extends SceneTree
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Characters = preload("res://presentation/characters.gd")
const Catalog = preload("res://source_catalog.gd")
const Protocol = preload("res://sdk/protocol.gd")
var checks = 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("ENCOUNTER_MEDIA_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func accounting(data: Dictionary, label: String) -> void:
    for category in [false,true]:
        var cpu = 0; var gpu = 0; var sheets = 0; var pinned = 0; var pending = 0
        for path in data.resident:
            var row: Dictionary = data.resident[path]
            if row.environment!=category: continue
            sheets += 1; cpu += int(row.cpu_bytes); gpu += int(row.gpu_bytes)
            if data.wanted.has(path) or data.preload_selected.has(path): pinned += int(row.bytes)
        var requests: Array = data.pending.duplicate()
        requests.append_array(data.decode_jobs)
        for request in requests:
            var environment: bool = data.environment.has(request.path) or data.encounter.get("environment",{}).has(request.path)
            if environment==category: pending += 1
        var actual = Media.diagnostics(data,category)
        check(actual.cpu_bytes==cpu and actual.gpu_estimated_bytes==gpu and actual.estimated_bytes==cpu+gpu and actual.pinned_bytes==pinned and actual.pending==pending and actual.resident_sheets==sheets,
            label+" incremental category accounting equals independent residency/queue sum "+str(category))

func load_one(data: Dictionary) -> Dictionary:
    var deadline = Time.get_ticks_msec()+20000
    while Time.get_ticks_msec()<deadline:
        var loaded = Media.poll(data)
        if not loaded.is_empty(): return loaded
        await process_frame
    return {}

func subset(full: Dictionary, paths: Array) -> Dictionary:
    var result = {"revision":paths.size(),"paths":{},"environment":{},"fixtures":{},"gpu_only":{},"cpu_required":{},"estimates":{},"errors":[]}
    for path in paths:
        result.paths[path] = full.paths[path]
        result.estimates[path] = full.estimates[path]
        for role in ["environment","fixtures","gpu_only","cpu_required"]:
            if full[role].has(path): result[role][path] = true
    result.estimate_summary = Encounter.estimate_summary(result)
    return result

func compare_selection(full: Dictionary, colour: String, companion: String, later: String) -> void:
    # The fallback retains the original exhaustive budget selection. Compare
    # the summary fast path against it, including a frozen unfinished boot.
    var fast = Media.create()
    var exhaustive = Media.create()
    var both = subset(full,[colour,companion])
    var next = subset(full,[later])
    var unknown = subset(full,[companion,later])
    unknown.estimates = unknown.estimates.duplicate()
    unknown.estimates[companion] = {"error":"Unknown header fixture"}
    unknown.estimate_summary = Encounter.estimate_summary(unknown)
    var scenarios = [
        {"plan":both,"required":{colour:full.paths[colour]},"budget":Media.BUDGET_BYTES,"label":"Full family fits"},
        {"plan":next,"required":{later:full.paths[later]},"budget":Media.BUDGET_BYTES,"label":"Frozen boot outside new family"},
        {"plan":both,"required":{later:full.paths[later]},"budget":int(full.estimates[later].bytes),"label":"Required extra exceeds optional budget"},
        {"plan":unknown,"required":{companion:full.paths[companion]},"budget":Media.BUDGET_BYTES,"label":"Unknown required estimate"},
    ]
    for i in range(scenarios.size()):
        var scenario: Dictionary = scenarios[i]
        var exact: Dictionary = scenario.plan.duplicate()
        exact.revision = i+100
        var fallback: Dictionary = exact.duplicate()
        fallback.erase("estimate_summary")
        fast.budget_bytes = scenario.budget; exhaustive.budget_bytes = scenario.budget
        Media.adopt_encounter(fast,exact,1); Media.adopt_encounter(exhaustive,fallback,1)
        Media.demand(fast,scenario.required); Media.demand(exhaustive,scenario.required)
        check(fast.preload_selected==exhaustive.preload_selected and fast.preload_skipped==exhaustive.preload_skipped
            and fast.preload_estimated_bytes==exhaustive.preload_estimated_bytes and fast.boot_paths==exhaustive.boot_paths,
            scenario.label+": summary selection agrees with original exhaustive budget policy")
        check(fast.pending.slice(0,scenario.required.size()).map(func(row):return row.path)==scenario.required.keys(),
            scenario.label+": mandatory request retains first priority")
    Media.close(fast); Media.close(exhaustive)

func run() -> void:
    var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json"))
    check(parsed.ok,"Actual disclosed Crypt initialization parses")
    if not parsed.ok: quit(1); return
    var state: Dictionary = parsed.value
    var before = state.duplicate(true)
    var cache = {}
    var current = Media.plan(state,[],cache)
    var environment = EnvironmentMedia.plan(state,[],cache)
    var encounter = Encounter.plan(state,environment.disclosed,environment.fixtures,cache)
    encounter.estimates = Encounter.estimates(encounter.paths,encounter.cpu_required,encounter.gpu_only,cache)
    encounter.estimate_summary = Encounter.estimate_summary(encounter)
    var expected = environment.required.duplicate()
    var index: Dictionary = Characters._read("catalog-index.json",cache)
    var rigs: Dictionary = Characters._read(index.rigs,cache)
    for actor in state.actors.values():
        var rig: String = Characters.rig_id(actor,cache)
        for weapon_set in ["melee","ranged"]:
            var variant: Dictionary = actor.duplicate()
            variant.visual_loadout = actor.visual_loadout.duplicate()
            variant.visual_loadout.active_weapon_set = weapon_set
            var exact = Characters.sheet_paths(variant,rigs[rig].clips.keys(),cache)
            check(exact.ok,"Existing disclosed weapon set resolves every authored rig clip")
            if exact.ok: expected.merge(exact.value)
    check(encounter.errors.is_empty() and encounter.paths.size()==expected.size() and expected.keys().all(func(path):return encounter.paths.has(path)),
        "Encounter source closure equals existing authored clips and both already-disclosed equipment sets, deduplicated by original path")
    check(state==before,"Warmup metadata leaves canonical actors and source appearance data untouched")
    check(encounter.estimates.values().all(func(row):return row.has("bytes") and row.bytes>0),"All known sources have inspectable PNG dimensions without allocating pixel images")
    var conservative = 0
    for estimate in encounter.estimates.values(): conservative += int(estimate.bytes)
    check(conservative>Media.BUDGET_BYTES,
        "All three normal treatments across every party clip exceed16GiB and must remain optional beyond current demand")
    var initial = Media.create()
    Media.adopt_encounter(initial,encounter,1)
    var mandatory = {}
    for paths in [current.required,environment.required]:
        for path in paths: mandatory[path] = Catalog.media_path(path)
    Media.demand(initial,mandatory,environment.required,environment.fixtures,current.gpu_only,current.cpu_required)
    check(initial.preload_skipped>0 and initial.pending.size()+initial.preload_skipped==encounter.paths.size()
        and initial.preload_estimated_bytes<=initial.budget_bytes,"Initial exact triplets plus budgeted optional all-clips warmup queue each selected source once")
    check(initial.pending.slice(0,mandatory.size()).map(func(request):return request.path)==mandatory.keys(),"Current and upcoming mandatory paths retain queue priority")
    accounting(initial,"Initial selection")
    check(not Media.boot_ready(initial) and not Media.ready(initial,mandatory),"Neither unuploaded optional startup sources nor mandatory sources report readiness")
    var full_progress = Media.preload_progress(initial)
    check(full_progress.selected==initial.preload_selected.size() and full_progress.ready==0,"Loading progress counts the budgeted encounter union without duplicating mandatory sources")
    Media.close(initial)

    # Already-received packets authorize prefetch, but never displayed state.
    # The additional real outfit is only introduced by this prepared group.
    var single: Dictionary = state.duplicate()
    single.actors = {state.actors.keys()[0]:state.actors.values()[0]}
    var single_plan = Encounter.plan(single,{}, {},cache)
    var absent: Dictionary = state.actors.values()[1]
    var absent_sources = Characters.sheet_paths(absent,["Idle"],cache).value
    var absent_only: Array = absent_sources.keys().filter(func(path):return not single_plan.paths.has(path))
    check(not absent_only.is_empty(),"Actual second outfit has distinct sources outside first actor closure")
    var future = {"actor_tracks":[{"actor_uuid":absent.uuid,"rig":Characters.rig_id(absent,cache),"clip":"Idle"}],
        "staged_actors":{absent.uuid:absent},"commits":[]}
    var exact_future = Media.plan(single,[future],cache)
    var received_plan = Encounter.plan(single,{}, {},cache,[future])
    check(absent_only.all(func(path):return exact_future.required.has(path) and received_plan.paths.has(path)),
        "Received upcoming actor prepares its full authored family before displayed arrival")
    check(single.actors.size()==1 and not single.actors.has(absent.uuid),"Prefetch neither publishes the received actor nor invents unreceived actor state")

    # Real PNG publication and source alpha, in a deliberately small budget.
    var colour: String = current.cpu_required.keys()[0]
    var companion: String = current.gpu_only.keys()[0]
    var later: String = current.gpu_only.keys()[1]
    var tiny = subset(encounter,[colour,companion])
    var data = Media.create()
    data.budget_bytes = tiny.estimates[colour].bytes+tiny.estimates[companion].bytes
    Media.adopt_encounter(data,tiny,7)
    Media.demand(data,{colour:Catalog.media_path(colour)}, {}, {}, {},{colour:true})
    check(data.pending.size()==2 and data.pending[0].path==colour,"Budgeted optional geometry follows required original colour")
    var original = await load_one(data)
    check(original.has("image") and original.path==colour,"Worker decodes actual required colour first")
    if not original.has("image"): Media.close(data); quit(1); return
    var original_pixels: PackedByteArray = original.image.get_data()
    var textures = {colour:ImageTexture.create_from_image(original.image)}
    Media.published(data,original)
    accounting(data,"First colour publication")
    check(Media.ready(data,{colour:true}) and Media.boot_ready(data) and not Media.ready(data,{companion:true}),"Required colour starts play while optional companion remains background work")
    var geometry = await load_one(data)
    check(geometry.has("image") and geometry.path==companion,"Worker decodes exact optional companion")
    if not geometry.has("image"): Media.close(data); quit(1); return
    check(Media.boot_ready(data) and not Media.ready(data,{companion:true}),"Decoded but unpublished optional image does not block startup or count as render-ready")
    textures[companion] = ImageTexture.create_from_image(geometry.image)
    Media.published(data,geometry)
    check(Media.release_cold_images(data)==[companion] and Media.boot_ready(data),"Original uploaded texture completes warmup; companion CPU copy releases while original colour remains")
    accounting(data,"GPU companion CPU release")
    var decoded_before: int = data.decoded
    var selections_before: int = data.selection_jobs
    Media.demand(data,{companion:Catalog.media_path(companion)}, {}, {},{companion:true},{})
    Media.demand(data,{colour:Catalog.media_path(colour)}, {}, {}, {},{colour:true})
    check(data.pending.is_empty() and Media.prune(data).is_empty() and data.decoded==decoded_before,
        "Repeated actions within the encounter budget neither evict nor redecode already-uploaded original sources")
    check(data.selection_jobs==selections_before,"Changing exact actions inside the selected family does not reselect the full encounter cache")
    accounting(data,"Action revisit")
    check(original.image.get_data()==original_pixels and data.resident[colour].cpu_bytes==original_pixels.size(),"Retained source colour and original alpha remain byte-identical for picking")
    var outside_family = Media.create()
    Media.adopt_encounter(outside_family,subset(encounter,[companion]),1)
    Media.demand(outside_family,{colour:Catalog.media_path(colour)}, {}, {}, {},{colour:true})
    check(not Media.boot_ready(outside_family) and Media.preload_progress(outside_family).startup_required==1
        and Media.preload_progress(outside_family).startup_ready==0,"Exact required source outside optional family still blocks startup until published")
    Media.published(outside_family,original)
    check(Media.boot_ready(outside_family) and not Media.ready(outside_family,{companion:true}),"Non-family mandatory publication starts play without optional family upload")
    Media.close(outside_family)
    var expanded = subset(encounter,[colour,companion,later])
    data.budget_bytes += expanded.estimates[later].bytes
    Media.adopt_encounter(data,expanded,7)
    Media.demand(data,{colour:Catalog.media_path(colour)}, {}, {}, {},{colour:true})
    check(Media.boot_ready(data) and data.pending.size()==1 and data.pending[0].path==later,
        "Newly known outfit media warms in background without resetting completed initial readiness")
    check(not Media.ready(data,{later:true}),"A later exact action still waits for its own unpublished source")
    data.budget_bytes = int(expanded.estimates[colour].bytes)
    Media.demand(data,{colour:Catalog.media_path(colour)}, {}, {}, {},{colour:true})
    check(data.preload_selected.keys()==[colour] and data.preload_skipped==2 and data.pending.is_empty(),"Lower configurable budget drops optional work before any mandatory source")
    check(Media.prune(data)==[companion] and data.resident.has(colour),"Pressure retires only unpinned optional texture and preserves required colour")
    accounting(data,"Eviction")
    Media.adopt_encounter(data,tiny,8)
    Media.demand(data,{colour:Catalog.media_path(colour)}, {}, {}, {},{colour:true})
    check(Media.boot_ready(data),"A new epoch with no optional budget has a finite empty warmup")
    Media.close(data)
    # Reuse the two genuinely decoded/uploaded sources above to exercise the
    # accepted-plan interleaving without a second allocation of the same art.
    var held = Media.create()
    held.budget_bytes = tiny.estimates[colour].bytes+tiny.estimates[companion].bytes
    Media.adopt_encounter(held,tiny,9)
    Media.demand(held,{colour:Catalog.media_path(colour)}, {}, {}, {},{colour:true})
    var boot: Dictionary = held.boot_paths.duplicate()
    Media.published(held,original)
    check(Media.boot_ready(held),"Initial mandatory source completes startup without its optional companion")
    held.budget_bytes += expanded.estimates[later].bytes
    Media.adopt_encounter(held,expanded,9)
    Media.demand(held,{colour:Catalog.media_path(colour)}, {}, {}, {},{colour:true})
    check(held.boot_paths==boot and held.preload_selected.has(later),"Received family expansion is background work and never enlarges an in-progress boot selection")
    Media.published(held,geometry)
    check(Media.boot_ready(held) and not Media.ready(held,{later:true}),"Finishing original boot sources does not wait for newly received background media")
    Media.demand(held,{colour:Catalog.media_path(colour)},{colour:true},{colour:true},{},{colour:true})
    check(not Media.ready(held,{colour:true}),"A newly required fixture reduction invalidates prior colour-only readiness")
    accounting(held,"Fixture role arrival")
    Media.demand(held,{})
    check(Media.ready(held,{colour:true}),"Dropping the fixture requirement restores original texture readiness without a decode")
    accounting(held,"Fixture role departure")
    var unavailable: Dictionary = original.duplicate()
    unavailable.gpu_bytes = 0
    Media.published(held,unavailable)
    check(not Media.ready(held,{colour:true}) and Media.preload_progress(held).ready==1,"GPU residency loss invalidates readiness and selected-progress membership")
    Media.published(held,original)
    check(Media.ready(held,{colour:true}) and Media.preload_progress(held).ready==2,"Republishing restores readiness and progress exactly once")
    accounting(held,"Source replacement")
    Media.close(held)

    # Family-only role changes must invalidate the same source even when the
    # exact command demand and selected source membership do not change.
    var roles = Media.create()
    Media.adopt_encounter(roles,tiny,1)
    Media.demand(roles,{})
    Media.published(roles,original); Media.published(roles,geometry)
    Media.demand(roles,{})
    check(Media.boot_ready(roles) and roles.pending.is_empty(),"Uploaded family starts ready with no duplicate queued source")
    var promoted = tiny.duplicate()
    promoted.revision = 100
    promoted.fixtures = {colour:true}
    Media.adopt_encounter(roles,promoted,1); Media.demand(roles,{})
    check(not Media.ready(roles,{colour:true}) and roles.pending.size()==1 and roles.pending[0].path==colour,
        "Family-only fixture promotion holds readiness and queues missing preprocessing once")
    accounting(roles,"Family role promotion")
    Media.adopt_encounter(roles,tiny,1); Media.demand(roles,{})
    check(Media.ready(roles,{colour:true}) and roles.pending.is_empty(),"Family-only fixture removal restores readiness without decoding")
    accounting(roles,"Family role removal")
    var refreshed: int = roles.selection_refreshed
    Media.adopt_encounter(roles,expanded,1); Media.demand(roles,{})
    check(roles.selection_refreshed==refreshed+1 and roles.pending.size()==1 and roles.pending[0].path==later,
        "Fitting family growth refreshes and queues only its one new source")
    var removed = subset(encounter,[colour])
    Media.adopt_encounter(roles,removed,1); Media.demand(roles,{})
    check(not roles.preload_selected.has(companion) and roles.resident.has(companion) and Media.preload_progress(roles).ready==1,
        "Family departure removes progress membership while keeping an unpressured uploaded source")
    accounting(roles,"Family source removal")
    Media.adopt_encounter(roles,tiny,1); Media.demand(roles,{})
    check(Media.ready(roles,{companion:true}) and roles.pending.is_empty() and Media.preload_progress(roles).ready==2,
        "Removed then readded family source reuses its upload without redecode or duplicate progress")
    accounting(roles,"Family source readdition")
    Media.close(roles)
    compare_selection(encounter,colour,companion,later)
    var failure = Media.create()
    var missing_path = "res://tests/no-such-optional-source.png"
    Media.adopt_encounter(failure,{"revision":1,"paths":{missing_path:missing_path},"estimates":{missing_path:{"bytes":4}},"errors":[]},1)
    Media.demand(failure,{})
    check(Media.boot_ready(failure) and not Media.ready(failure,{missing_path:true}),"Missing optional source does not prevent startup and remains unavailable")
    var failed = await load_one(failure)
    check(failed.has("error") and Media.boot_ready(failure) and Media.preload_progress(failure).failed.has(missing_path) and not Media.ready(failure,{missing_path:true}),
        "Optional preparation failure completes startup wait, remains reported, and never becomes render-ready")
    accounting(failure,"Worker failure")
    Media.close(failure)
    var report = {"checks":checks,"failures":failures,"known_unique_sources":encounter.paths.size(),
        "conservative_combined_bytes":conservative,"configured_combined_budget_bytes":Media.BUDGET_BYTES,
        "original_colour_cpu_bytes":original_pixels.size(),"scope":"Actual disclosed Crypt authoring closure; finite-budget/source-publication fixtures. RGBA8 estimates are not measured hardware residency."}
    FileAccess.open("res://generated/encounter_media_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
