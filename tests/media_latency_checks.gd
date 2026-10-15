extends SceneTree
# Actual authored source selection and the completed-worker/publication boundary.
# Headless checks prove ownership/readiness/order; no native frame-time claim.
const Media = preload("res://presentation/media_warmup.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const World = preload("res://presentation/world.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Catalog = preload("res://source_catalog.gd")
const Player = preload("res://play.gd")
const Protocol = preload("res://sdk/protocol.gd")
var checks = 0
var failures: Array = []
var evidence = {}
var state_path = ""

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("MEDIA_LATENCY_FAIL ",label)
func _initialize() -> void: run.call_deferred()

func group(id: String, commits: Array = []) -> Dictionary:
    return {"id":id,"commits":commits,"actor_tracks":[],"staged_actors":{},"staged_tiles":{}}

func collect(state: Dictionary, paths: Dictionary, cache: Dictionary) -> void:
    for row in World.rows(state,cache).visual_rows:
        paths.merge(EnvironmentMedia.row_paths(row,cache))
        for member in row.get("wall_members",[]): paths.merge(EnvironmentMedia.row_paths(member,cache))

func exhaustive(state: Dictionary, groups: Array, cache: Dictionary) -> Dictionary:
    var copy = state.duplicate()
    for field in ["tiles","objects","actors"]: copy[field] = state[field].duplicate()
    var required = {}; var upcoming = {}; var fixtures = {}
    collect(copy,required,cache)
    for i in groups.size():
        var paths: Dictionary = required if i==0 else upcoming
        collect(copy,paths,cache)
        for key in groups[i].get("staged_tiles",{}):
            if not copy.tiles.has(key): collect({"tiles":{key:groups[i].staged_tiles[key]},"objects":{},"senses":copy.senses},paths,cache)
        for commit in groups[i].commits:
            Compiler.apply_delta(copy,commit.delta)
            collect(copy,paths,cache)
    for paths in [required,upcoming]:
        for path in paths:
            if cache.get("__live_fixture_frames",{}).has(path): fixtures[path] = true
    return {"required":required,"upcoming":upcoming,"fixtures":fixtures}

func compare_sources(state: Dictionary, groups: Array, cache: Dictionary, label: String) -> Dictionary:
    var before = state.duplicate(true)
    var expected = exhaustive(state,groups,{})
    var actual = EnvironmentMedia.plan(state,groups,cache)
    for field in ["required","upcoming","fixtures"]:
        check(actual[field]==expected[field],label+" exact original source set: "+field)
    check(state==before,label+" leaves canonical state intact")
    return actual

func source_cases(state: Dictionary) -> Dictionary:
    var cache = {}
    var initial = compare_sources(state,[],cache,"Original disclosed world")
    var changed = {}
    var count = 0
    for key in state.tiles:
        var tile: Dictionary = state.tiles[key].duplicate(true)
        tile.resolved_light = 0 if tile.get("resolved_light",0)!=0 else 1
        changed[key] = tile
        count += 1
        if count==32: break
    var rows = int(initial.diagnostics.changed_row_builds)
    var light = group("light-only",[{"delta":{"tiles":changed}}])
    var actual = compare_sources(state,[light],cache,"Light-only after-values")
    check(actual.diagnostics.changed_row_builds==rows,"Light-only metadata reuses exact terrain source closures")
    var key: String = state.tiles.keys()[0]
    var moved: Dictionary = state.tiles[key].duplicate(true)
    moved.position = [1000,-1000]; moved.elevation_steps = -4
    var material = moved.surface.base_material
    var world = Catalog.read_file("world.json",cache)
    for candidate in world.terrain:
        if candidate!=material: material=candidate; break
    var different = moved.duplicate(true); different.surface.base_material = material
    var future = group("move-and-material",[{"delta":{"tiles":{key:moved}}},{"delta":{"tiles":{key:different}}}])
    var staged = different.duplicate(true); staged.position = [1001,-1000]
    future.staged_tiles["1001,-1000"] = staged
    compare_sources(state,[light,future],cache,"Contact/elevation/material and staged support")
    var hidden = state.duplicate(); hidden.senses = state.senses.duplicate(true)
    hidden.senses.objects = {}
    compare_sources(hidden,[],cache,"Fixture loses visual observation")
    compare_sources(state,[],cache,"Fixture reappears and source index resets to earlier state")
    return initial

func poll_plan(data: Dictionary) -> Dictionary:
    var deadline = Time.get_ticks_msec()+30000
    while Time.get_ticks_msec()<deadline:
        var result = Media.poll_plan(data)
        if not result.is_empty(): return result
        await process_frame
    check(false,"Metadata worker completed before deadline")
    return {}

func dispose(player: Node3D) -> void:
    Media.close(player.media_warmup)
    player.context_menu.free()
    player.free()

func staged_metadata(state: Dictionary, expected_environment: Dictionary) -> void:
    var data = Media.create()
    var snapshot = state.duplicate(true)
    var key = [1,[],0]
    var expected = Media.plan(state,[],{})
    Media.request_plan(data,key,snapshot,[])
    snapshot.actors.clear(); snapshot.tiles.clear(); snapshot.objects.clear()
    var required = await poll_plan(data)
    if required.is_empty(): Media.close(data); return
    check(required.get("stage")=="required" and not required.value.has("encounter"),"Required source packet publishes independently of optional family estimates")
    check(required.value.required==expected.required and required.value.environment_required==expected_environment.required,
        "First required packet preserves original source selection and snapshot membership")
    check(required.source_files.has("catalog-index.json") and required.source_files.has("environment/index.json"),"Required source JSON is available before scene binding")
    var required_paths:Dictionary=required.value.required.duplicate()
    for paths in [required.value.upcoming,required.value.environment_required,required.value.environment_upcoming,required.value.optical_candidates]:required_paths.merge(paths)
    check(required_paths.keys().all(func(path):return required.value.source_sizes.get(path,0)>0),
        "Required worker supplies PNG sizes for requested sources and optical masks before optional estimates")
    var player = Player.new()
    player.timeline.accept({"kind":"initialization","sequence":0,"state":state})
    key = [player.timeline.initialization_revision,[],player.timeline.revision]
    required.key = key
    player.media_requested_key = key
    player.media_plan_epoch = player.timeline.initialization_revision
    player.world_revision = 0
    player._adopt_media_plan(required)
    player._prepare_media()
    var wanted: Dictionary = player.media_warmup.wanted.duplicate()
    check(not wanted.is_empty() and player.media_warmup.encounter.is_empty(),"Required paths are demanded without an optional family owner")
    var candidates_only:Array=required.value.optical_candidates.keys().filter(func(path):return not wanted.has(path))
    check(not candidates_only.is_empty() and candidates_only.all(func(path):return not player.media_warmup.queued.has(path)),"Ordinary animation optical metadata prepares native tails without decoding or demanding unused masks")
    check(player.media_warmup.boot_started and not Media.boot_ready(player.media_warmup),"Initial exact demand gates startup before publication")
    for path in wanted:
        var loaded = {"path":path,"cpu_bytes":16,"gpu_bytes":16}
        if player.media_warmup.fixtures.has(path): loaded.merge({"energy":.4,"emission_centroid":Vector2(2,3)})
        Media.published(player.media_warmup,loaded)
    check(player.media_metadata_ready and Media.ready(player.media_warmup,player.media_plan.required) and player._environment_sources_ready() and Media.boot_ready(player.media_warmup),"All required publications become ready before optional metadata adoption")
    var missing: String = wanted.keys()[0]
    player.media_warmup.ready_paths.erase(missing)
    check(not Media.ready(player.media_warmup,player.media_plan.required),"Required readiness still blocks missing resident bytes")
    Media._refresh_path(player.media_warmup,missing)
    var original = player.media_empty_plan
    check(data.plan_task<0 and not data.optional_pending.is_empty(),"Required completion leaves optional dispatch pending until exact scene demand")
    Media.adopt_required(data,1)
    Media.demand(data,wanted,player.media_warmup.environment,player.media_warmup.fixtures,player.media_warmup.gpu_only,player.media_warmup.cpu_required)
    var optional = await poll_plan(data)
    if not optional.is_empty():
        check(optional.stage=="optional" and optional.value.has("encounter"),"Optional family preparation completes on the same owned metadata queue")
        var obsolete = optional.duplicate(); obsolete.key = [key[0],["obsolete"],0]
        player._adopt_media_plan(obsolete)
        check(player.media_warmup.encounter.is_empty() and is_same(player.media_empty_plan,original),"Obsolete optional result cannot replace required ownership")
        obsolete = optional.duplicate(); obsolete.key = [key[0]+1,[],key[2]]
        player._adopt_media_plan(obsolete)
        check(player.media_warmup.encounter.is_empty(),"Foreign initialization optional result is rejected")
        optional.key = key
        player._adopt_media_plan(optional)
        check(not player.media_warmup.encounter.is_empty() and is_same(player.media_empty_plan,original) and Media.boot_ready(player.media_warmup),"Matching optional family preserves completed startup and exact required packet")
        player._prepare_media()
        check(Media.ready(player.media_warmup,wanted),"Optional adoption preserves every required residency role")
    evidence.metadata_phases = data.metadata_phases
    Media.close(data); dispose(player)
    # Queue replacement invalidates only optional work, never a completed exact
    # request. Close joins the one owner and drops all undispatched work.
    var queued = Media.create()
    Media.request_plan(queued,[1,["old"],0],state,[])
    Media.request_plan(queued,[2,["new"],0],state,[])
    var first = await poll_plan(queued)
    var second = await poll_plan(queued)
    check(first.get("stage")=="required" and second.get("stage")=="required" and second.key[0]==2,"New required request precedes obsolete optional family work")
    Media.close(queued)
    check(queued.plan_pending.is_empty() and queued.optional_pending.is_empty() and Media.poll_plan(queued).is_empty(),"Close discards queued metadata without late publication")

func publication(environment: Dictionary) -> void:
    var player = Player.new()
    var paths: Array = environment.required.keys().filter(func(path):return not environment.fixtures.has(path))
    paths.resize(mini(4,paths.size()))
    check(paths.size()==4,"Actual source fixture provides four nonfixture original PNGs")
    if paths.size()!=4: dispose(player); return
    var wanted = {}; var originals = {}
    for i in paths.size():
        var path: String = paths[i]
        if i>0: wanted[path] = Catalog.media_path(path)
        originals[path] = Image.load_from_file(Catalog.media_path(path))
    Media.demand(player.media_warmup,wanted,wanted)
    player.media_warmup.pending.clear(); player.media_warmup.queued.clear(); player.media_warmup.stats = {}
    player.media_warmup.preload_selected[paths[0]] = Catalog.media_path(paths[0])
    for path in paths:
        var result = {}
        var task = WorkerThreadPool.add_task(Media._decode.bind({"path":path,"absolute":Catalog.media_path(path)},result))
        player.media_warmup.decode_jobs.append({"task":task,"path":path,"result":result})
        player.media_warmup.queued[path] = true
    while player.media_warmup.decode_jobs.any(func(job):return not WorkerThreadPool.is_task_completed(job.task)):
        await process_frame
    player._warm_media()
    var first: Dictionary = player.media_warmup.publication.duplicate()
    check(first.required>0 and first.optional==0 and not player.textures.has(paths[0]),"Completed required sources publish before an older optional result")
    check(first.count>1 or first.elapsed_ms>=first.budget_ms,"Cheap completed required uploads share a frame until the measured budget is reached")
    check(first.count<=Media.PUBLICATIONS_PER_FRAME,"Publication remains bounded by its safety ceiling")
    var tries = 0
    while not Media.ready(player.media_warmup,wanted) and tries<10:
        player._warm_media(); tries += 1
    check(Media.ready(player.media_warmup,wanted),"All required images make progress to complete readiness")
    for path in wanted:
        check(player.source_images.has(path) and player.source_images[path].get_data()==originals[path].get_data(),"Published original CPU image bytes remain exact: "+path)
    player._warm_media()
    check(player.textures.has(paths[0]),"Optional warming resumes after the required backlog")
    evidence.publication = first
    dispose(player)

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--state="): state_path = arg.trim_prefix("--state=")
    if state_path.is_empty():
        check(false,"Usage: --state=<recorded canonical state.json>"); finish(); return
    var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes(state_path))
    check(parsed.ok,"Explicit recorded canonical state loads")
    if not parsed.ok: finish(); return
    var environment = source_cases(parsed.value)
    await staged_metadata(parsed.value,environment)
    await publication(environment)
    finish()

func finish() -> void:
    var report = {"checks":checks,"failures":failures,"state":state_path,"evidence":evidence,
        "scope":"Original source closure parity, required-before-optional metadata readiness, immutable input snapshots, stale epochs/requests and real PNG publication order/bytes. Headless texture adapter only; native upload/frame timing requires live acceptance."}
    FileAccess.open("res://generated/media_latency_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_LATENCY_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
