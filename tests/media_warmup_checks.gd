extends SceneTree
# Captured canonical outfits plus bounded presentation/queue fixtures. These
# fixtures exercise loading boundaries, not invented gameplay outcomes.
const Media = preload("res://presentation/media_warmup.gd")
const Characters = preload("res://presentation/characters.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Catalog = preload("res://source_catalog.gd")
const Protocol = preload("res://sdk/protocol.gd")
const Player = preload("res://play.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
var checks = 0
var failures: Array = []
var gate = {}

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("MEDIA_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func group(id: String, duration: float, commits: Array = [], tracks: Array = []) -> Dictionary:
    for track in tracks:track.start_ms=track.get("start_ms",0.0)
    return {"id":id,"duration_ms":duration,"commits":commits,"actor_tracks":tracks,"staged_actors":{},
        "staged_at_ms":{},"staged_tiles":{},"staged_tile_at_ms":{},"operation_sequence":1,"operation_end":true}

func ready_group(row: Dictionary) -> bool: return gate.get(row.get("id","initial"),false)

func loaded(data: Dictionary) -> Dictionary:
    var deadline = Time.get_ticks_msec()+20000
    while Time.get_ticks_msec()<deadline:
        var result = Media.poll(data)
        if not result.is_empty(): return result
        await process_frame
    return {}

func run() -> void:
    var rejected=Media.create()
    var oversized={"path":"fixture/oversized","image":Image.create(3,2,false,Image.FORMAT_RGBA8)}
    rejected.wanted[oversized.path]=oversized.path
    rejected.preload_selected[oversized.path]=oversized.path
    Media.validate_upload_dimensions(rejected,oversized,2)
    check(oversized.has("error") and rejected.failed.has(oversized.path),"An oversized upload is rejected before creating an invalid GPU texture")
    check(not Media.ready(rejected,rejected.wanted) and rejected.resident.is_empty() and rejected.selected_failed.has(oversized.path),
        "Rejected GPU upload cannot enter residency or satisfy either required or preload readiness")
    var fitting={"path":"fixture/fitting","image":Image.create(2,2,false,Image.FORMAT_RGBA8)}
    Media.validate_upload_dimensions(rejected,fitting,2)
    check(not fitting.has("error") and fitting.image.get_size()==Vector2i(2,2),"A supported image retains its exact dimensions")
    Media.close(rejected)
    # Completed optional PNG jobs must not monopolize all four decode slots
    # when the next actual required request arrives. No GPU publication is
    # implied by freeing a worker slot.
    var slot_image:Image=Image.create(8,8,false,Image.FORMAT_RGBA8)
    slot_image.fill(Color(.2,.4,.6,1))
    var slot_file:String="user://media-required-decode-slot.png"
    check(slot_image.save_png(slot_file)==OK,"Decode-slot fixture PNG saves")
    var slot_data:Dictionary=Media.create()
    var family:Dictionary={"revision":1,"paths":{},"estimates":{},"errors":[]}
    var slot_required:String="required-after-optional"
    for i in Media.DECODE_WORKERS+1:
        var id:String=slot_required if i==Media.DECODE_WORKERS else "optional-slot-"+str(i)
        family.paths[id]=slot_file;family.estimates[id]={"bytes":512}
    Media.adopt_encounter(slot_data,family,1)
    Media.demand(slot_data,{})
    Media.prepare_optional(slot_data)
    Media.poll(slot_data,true,false)
    while not slot_data.decode_jobs.all(func(job):return WorkerThreadPool.is_task_completed(job.task)):await process_frame
    check(slot_data.decode_jobs.size()==Media.DECODE_WORKERS and Media.poll(slot_data,true).is_empty(),
        "Required-only polling leaves completed optional jobs untouched when no required decode is blocked")
    Media.demand(slot_data,{slot_required:slot_file})
    check(slot_data.pending.size()==1 and slot_data.decode_jobs.size()==Media.DECODE_WORKERS,
        "New required PNG waits behind the actual full worker slots")
    var reclaimed:Dictionary=Media.poll(slot_data,true)
    check(reclaimed.has("image") and family.paths.has(reclaimed.path) and slot_data.pending.is_empty()
        and slot_data.decode_jobs.any(func(job):return job.path==slot_required),
        "Required-only poll reclaims one completed optional image and immediately dispatches the blocked required PNG")
    check(not Media.ready(slot_data,{slot_required:true}) and not Media.ready(slot_data,{reclaimed.get("path","missing"):true}) and slot_data.resident.is_empty(),
        "Slot reclamation cannot publish either image or satisfy readiness early")
    while not slot_data.decode_jobs.filter(func(job):return job.path==slot_required).all(func(job):return WorkerThreadPool.is_task_completed(job.task)):await process_frame
    var required_image:Dictionary=Media.poll(slot_data,true)
    check(required_image.get("path")==slot_required and required_image.has("image"),
        "Required image completes without any later optional turn")
    Media.published(slot_data,required_image)
    check(Media.ready(slot_data,{slot_required:true}) and not Media.ready(slot_data,{reclaimed.get("path","missing"):true}),
        "Only the explicit required publication establishes readiness")
    Media.close(slot_data);DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_file))
    var cache = {}
    var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json"))
    check(parsed.ok,"Captured canonical outfit state parses")
    if not parsed.ok: quit(1); return
    var state: Dictionary = parsed.value
    var before: Dictionary = state.duplicate(true)
    var resting = Media.plan(state,[],cache)
    check(resting.errors.is_empty() and not resting.required.is_empty(),"Exact current resting sheets resolve")
    check(not resting.gpu_only.is_empty() and resting.gpu_only.keys().all(func(path):return resting.required.has(path) and not resting.cpu_required.has(path)),
        "Only exact registered geometry companions opt out of CPU picking residency")
    var exact = {}
    for actor in state.actors.values(): exact.merge(Characters.sheet_paths(actor,["Idle"],cache).value)
    check(resting.required==exact and resting.upcoming.is_empty(),"No eager unrelated clips or outfits")
    var unsensed: Dictionary = state.duplicate(true)
    unsensed.senses = null
    var unsensed_plan = Media.plan(unsensed,[],cache)
    var controlled = {}
    for actor in state.actors.values():
        if actor.uuid in state.audience.controlled: controlled.merge(Characters.sheet_paths(actor,["Idle"],cache).value)
    check(unsensed_plan.errors.is_empty() and unsensed_plan.required==controlled,"Nullable canonical senses retains only controlled actor preparation")
    var fighter: Dictionary = state.actors.values().filter(func(actor):return actor.name=="Shield Fighter")[0]
    var ranged: Dictionary = fighter.duplicate(true)
    ranged.visual_loadout.active_weapon_set = "ranged"
    var rig = Characters.rig_id(fighter,cache)
    var current = group("attack",100,[],[{"actor_uuid":fighter.uuid,"rig":rig,"clip":"Attack1","visual_loadout":ranged.visual_loadout}])
    var next = group("equipment-and-run",100,[{"at_ms":0,"delta":{"actors":{fighter.uuid:ranged}}}],
        [{"actor_uuid":fighter.uuid,"rig":rig,"clip":"Run"}])
    var plan = Media.plan(state,[current,next],cache)
    check(plan.errors.is_empty(),"Current and queued authored outfits resolve")
    var ranged_attack = Characters.sheet_paths(ranged,["Attack1"],cache).value
    check(ranged_attack.keys().all(func(path):return plan.required.has(path)),"Attack track's exact ranged visual_loadout is prepared before entry")
    var ranged_run = Characters.sheet_paths(ranged,["Run"],cache).value
    check(ranged_run.keys().all(func(path):return plan.upcoming.has(path)),"Queued equipment after-value and next Run are prepared")
    check(state==before,"Demand planning never mutates canonical state")
    check(plan.required.keys().all(func(path):return not "Rolling" in path),"Unrequested jump sheets stay out of demand")
    var unavailable = group("unavailable-next-clip",100,[],[{"actor_uuid":fighter.uuid,"rig":rig,"clip":"not-an-authored-clip"}])
    var future_failure = Media.plan(state,[current,unavailable],cache)
    check(future_failure.errors.is_empty() and not future_failure.upcoming_errors.is_empty(),"Future authoring failure is explicit but does not block the prepared current group")
    var visitor = fighter.duplicate(true); visitor.uuid = "fixture-newly-disclosed-actor"
    var arrival = group("arrival",100,[],[{"actor_uuid":visitor.uuid,"rig":rig,"clip":"Rolling"}])
    arrival.staged_actors[visitor.uuid] = visitor
    arrival.staged_at_ms[visitor.uuid] = 50.0
    var arrival_plan = Media.plan(state,[arrival],cache)
    check(Characters.sheet_paths(visitor,["Rolling"],cache).value.keys().all(func(path):return arrival_plan.required.has(path)),"Delayed staged actor's exact action is ready before group staging")
    check(not state.actors.has(visitor.uuid),"Preparing staged actor does not disclose it")
    var sources = EnvironmentMedia.plan(state,[],cache)
    check(not sources.required.is_empty() and sources.upcoming.is_empty(),"Captured disclosed world resolves exact four-view environment sources")
    check(not sources.fixtures.is_empty(),"Captured disclosed lit fixtures retain exact authored frame sources")
    var metadata = Media.create()
    var snapshot: Dictionary = state.duplicate(true)
    Media.request_plan(metadata,[1,[],0],snapshot,[])
    snapshot.actors.clear(); snapshot.tiles.clear(); snapshot.objects.clear(); snapshot.senses = null
    var metadata_result = {}
    var metadata_deadline = Time.get_ticks_msec()+20000
    while metadata_result.is_empty() and Time.get_ticks_msec()<metadata_deadline:
        metadata_result = Media.poll_plan(metadata)
        if metadata_result.is_empty(): await process_frame
    check(not metadata_result.is_empty(),"Worker metadata preparation completes")
    check(not metadata_result.has("error") and metadata_result.get("complete",false),"Successful authored worker completion is consumable without a false media error")
    if not metadata_result.is_empty():
        check(metadata_result.value.required==resting.required and metadata_result.value.environment_required==sources.required,
            "Worker source plan is isolated from later scene dictionary membership changes")
    if not metadata_result.is_empty():
        var published_files: Dictionary = metadata_result.source_files
        var body_sources:Dictionary=published_files.get(Characters.BodySources.KEY,{})
        check(published_files.has("catalog-index.json") and published_files.has("res://build/presentation/environment/index.res")
            and body_sources.get("index")!=null and not body_sources.get("loaded",{}).is_empty(),
            "Completed worker publishes original documents and admitted native body geometry before scene binding")
        check(published_files.keys().all(func(path):return ((path is String and path.ends_with(".json") and not path.begins_with("__"))
            or path in [Characters.BodySources.KEY,"__native_spell_admission","__environment_source_records","native_references_validated","native_authoring_errors"]))
            and body_sources.is_read_only() and body_sources.loaded.is_read_only()
            and not published_files.has("__environment_demand_index") and not published_files.has("__required_headers"),
            "Published source revision shares immutable native admissions while excluding mutable planner indexes and selector caches")
        var scene_cache={}
        scene_cache.merge(published_files,false)
        var warmed=Media.plan(state,[],scene_cache)
        check(warmed.required==resting.required,"Transferred immutable source files resolve the same original character demand")
        check(body_sources.loaded.keys().all(func(path):return is_same(body_sources.loaded[path],scene_cache[Characters.BodySources.KEY].loaded[path])),
            "The scene borrows exact prepared body source Resources without another physical metadata owner")
    Media.close(metadata)

    var timeline = Timeline.new()
    timeline.media_ready = ready_group
    timeline.accept({"kind":"initialization","state":state.duplicate(true),"sequence":0})
    timeline.advance(1000)
    check(timeline.display_ms==0 and timeline.sequence==0 and timeline.waiting_for_media,"Initial media wait holds displayed clock")
    gate.initial = true
    timeline.advance(10)
    check(timeline.display_ms==10,"Ready initial state advances normally")
    var zero = group("zero",0,[{"at_ms":0,"delta":{"set":{"round_number":99}}}])
    timeline.accept({"kind":"operation","groups":[zero]})
    timeline.advance(500)
    check(timeline.current.is_empty() and timeline.queue.size()==1 and timeline.state.round_number==state.round_number and timeline.display_ms==10,"Pending zero-duration group neither stages nor commits nor leaves queue")
    gate.zero = true
    timeline.advance(0)
    check(timeline.state.round_number==99 and timeline.sequence==1 and timeline.display_ms==10,"Ready zero-duration commit preserves order and clock")
    var first = group("first",100,[{"at_ms":50,"delta":{"set":{"round_number":100}}}])
    var second = group("second",0,[{"at_ms":0,"delta":{"set":{"round_number":101}}}])
    gate.first = true
    timeline.accept({"kind":"operation","groups":[first,second]})
    timeline.advance(10000)
    check(timeline.display_ms==110 and timeline.state.round_number==100 and timeline.queue.size()==1,"Large time step stops exactly before an unprepared successor")
    gate.second = true
    timeline.advance(0)
    check(timeline.display_ms==110 and timeline.state.round_number==101,"Loading wall time does not become catch-up time")
    timeline.paused = true; timeline.advance(500)
    check(timeline.display_ms==110,"Manual pause remains authoritative")

    var data = Media.create()
    var path: String = resting.required.keys()[0]
    Media.demand(data,{path:Catalog.media_path(path)})
    check(data.pending.size()==1 and not Media.ready(data,{path:true}),"Exact source queued once and not prematurely ready")
    Media.demand(data,{path:Catalog.media_path(path)})
    check(data.pending.size()==1,"Repeated demand deduplicates pending decode")
    check(Media.poll(data,true,false).is_empty() and data.pending.is_empty() and data.decode_jobs.size()==1,
        "Exhausted upload allowance still dispatches the exact queued worker without harvesting an image")
    while not WorkerThreadPool.is_task_completed(data.decode_jobs[0].task):await process_frame
    var completed_task:int=data.decode_jobs[0].task
    check(Media.poll(data,true,false).is_empty() and data.decode_jobs.size()==1 and data.decode_jobs[0].task==completed_task
        and data.queued.has(path) and Media.physical(data).decoded==0 and not Media.ready(data,{path:true}),
        "Completed decode stays owned and pending until a later publication allowance; it cannot falsely satisfy readiness")
    var image = await loaded(data)
    check(not image.is_empty() and not image.has("error") and image.image.get_width()>0,"Native worker decodes original authored PNG")
    if image.is_empty() or image.has("error"): Media.close(data); quit(1); return
    Media.published(data,image)
    var original_pixels: PackedByteArray = image.image.get_data()
    check(Media.release_cold_images(data).is_empty() and data.resident[path].cpu_bytes==original_pixels.size(),
        "Displayed original colour retains its exact CPU picking pixels")
    check(Media.ready(data,{path:true}) and not data.queued.has(path),"Publication makes source ready and clears pending membership")
    data.failed["future-fixture"] = "Future sheet is unavailable"
    check(Media.ready(data,{path:true}) and not Media.ready(data,{"future-fixture":true}),"Unrelated lookahead decode failure does not interrupt the ready current source")
    check(Media.prune(data,0).is_empty(),"Required source stays pinned even above soft byte budget")
    Media.demand(data,{})
    check(Media.release_cold_images(data).is_empty() and Media.ready(data,{path:true}),"Cold original picking pixels remain with their retained texture")
    var original_decodes: int = Media.physical(data).decoded
    Media.demand(data,{path:Catalog.media_path(path)})
    check(data.pending.is_empty() and Media.physical(data).decoded==original_decodes,"Revisited resident original does not redecode its retained picking pixels")
    check(image.image.get_data()==original_pixels,"Retained colour includes unchanged original alpha for picking")
    Media.demand(data,{})
    check(Media.prune(data,0)==[path] and data.resident.is_empty(),"Unpinned whole-sheet eviction releases residency")
    Media.demand(data,{path:Catalog.media_path(path)})
    check(data.pending.size()==1,"Fully evicted sheet can be enqueued again")
    Media.demand(data,{})
    check(data.pending.is_empty() and data.queued.is_empty(),"No stale queued marker after canceled demand")
    Media.demand(data,{"missing-fixture":"res://tests/no-such-authored-character-sheet.png"})
    var missing = await loaded(data)
    check(missing.has("error") and data.failed.has("missing-fixture"),"Missing exact asset fails explicitly")
    Media.demand(data,{"missing-fixture":"res://tests/no-such-authored-character-sheet.png"})
    check(data.pending.is_empty() and not Media.ready(data,{"missing-fixture":true}),"Failed source blocks readiness without an infinite per-frame retry")
    Media.close(data)

    # Use actual worker-resolved roles and authored images. Publication is the
    # upload boundary; the native scene check separately verifies GPU sampling.
    var gpu_data: Dictionary = Media.create()
    var companions: Array = resting.gpu_only.keys().slice(0,4)
    var companion_demand = {}
    var companion_images = {}
    var companion_textures = {}
    var removed_cpu_bytes = 0
    for companion in companions: companion_demand[companion] = Catalog.media_path(companion)
    var cached_roles = Media.roles_for(resting,companion_demand)
    Media.demand(gpu_data,companion_demand,{}, {},cached_roles.gpu_only,cached_roles.cpu_required)
    check(companions.size()==4 and not Media.ready(gpu_data,companion_demand),"Unpublished companion packet still gates presentation")
    for i in range(companions.size()):
        var decoded = await loaded(gpu_data)
        check(decoded.has("image") and not decoded.has("error"),"Original companion PNG decodes before its first upload")
        if not decoded.has("image"): Media.close(gpu_data); quit(1); return
        companion_images[decoded.path] = decoded.image
        companion_textures[decoded.path] = ImageTexture.create_from_image(decoded.image)
        removed_cpu_bytes += int(decoded.cpu_bytes)
        Media.published(gpu_data,decoded)
    var bytes_before = Media.diagnostics(gpu_data).estimated_bytes
    var released: Array = []
    while released.size()<4:
        var batch:Array=Media.release_cold_images(gpu_data)
        check(batch.size()<=Media.CPU_RELEASES_PER_FRAME,"Original companion CPU retirement respects the frame allowance")
        for companion in batch: companion_images.erase(companion)
        released.append_array(batch)
        if released.size()<4:await process_frame
    check(released.size()==4 and companion_images.is_empty() and companion_textures.size()==4,
        "Uploaded exact companion packet releases CPU images while all texture handles remain resident")
    check(Media.ready(gpu_data,companion_demand) and Media.prune(gpu_data,0).is_empty(),
        "GPU-only companions remain ready and pinned without CPU copies")
    check(Media.diagnostics(gpu_data).estimated_bytes==bytes_before-removed_cpu_bytes and Media.release_cold_images(gpu_data).is_empty(),
        "CPU byte accounting is removed exactly once, without claiming process RSS savings")
    Media.demand(gpu_data,{})
    Media.request_plan(gpu_data,[2,[],0],{},[])
    var empty_result = {}
    metadata_deadline = Time.get_ticks_msec()+20000
    while empty_result.is_empty() and Time.get_ticks_msec()<metadata_deadline:
        empty_result = Media.poll_plan(gpu_data)
        if empty_result.is_empty(): await process_frame
    check(not empty_result.is_empty() and gpu_data.gpu_only.is_empty() and gpu_data.cpu_required.is_empty(),
        "Only current demand retains role metadata; worker results do not repopulate past paths")
    var decoded_before: int = Media.physical(gpu_data).decoded
    Media.demand(gpu_data,companion_demand,{}, {},cached_roles.gpu_only,cached_roles.cpu_required)
    check(Media.ready(gpu_data,companion_demand) and gpu_data.pending.is_empty() and Media.poll(gpu_data).is_empty() and Media.physical(gpu_data).decoded==decoded_before,
        "Revisited GPU-resident companions never decode merely to restore unused CPU pixels")
    Media.demand(gpu_data,{})
    check(Media.prune(gpu_data,0).size()==2 and not Media.ready(gpu_data,companion_demand),
        "Evicting companion GPU residency removes readiness, bounded to two texture releases per frame")
    check(Media.prune(gpu_data,0).is_empty(),"Repeated maintenance in one frame cannot multiply driver texture releases")
    await process_frame
    check(Media.prune(gpu_data,0).size()==2,"Remaining unpinned companions retire on a later frame")
    Media.demand(gpu_data,companion_demand,{}, {},cached_roles.gpu_only,cached_roles.cpu_required)
    check(gpu_data.pending.size()==4,"Fully evicted companions require preparation again")
    var restored_companion = await loaded(gpu_data)
    check(restored_companion.has("image"),"A cached role plan can reload an evicted companion after newer planning")
    if restored_companion.has("image"):
        companion_textures[restored_companion.path] = ImageTexture.create_from_image(restored_companion.image)
        Media.published(gpu_data,restored_companion)
        check(Media.release_cold_images(gpu_data)==[restored_companion.path] and Media.ready(gpu_data,{restored_companion.path:true}),
            "Cached-plan evicted revisit retains GPU-only semantics without a new metadata worker")
    Media.close(gpu_data)
    var environment_data = Media.create()
    var flame: String = sources.fixtures.keys()[0]
    Media.demand(environment_data,{flame:Catalog.media_path(flame)},{flame:true},{flame:true})
    var prepared_flame = await loaded(environment_data)
    check(prepared_flame.has("energy") and not prepared_flame.has("error"),"Exact fixture frame and luminance prepare together off-thread")
    if prepared_flame.has("energy"):
        var original: Image = prepared_flame.image
        var reduced: Image = original.duplicate()
        reduced.srgb_to_linear(); reduced.premultiply_alpha(); reduced.convert(Image.FORMAT_RGBAF)
        reduced.resize(1,1,Image.INTERPOLATE_TRILINEAR)
        check(is_equal_approx(prepared_flame.energy,reduced.get_pixel(0,0).get_luminance()),"Worker luminance matches previous native reduction without altering source pixels")
        Media.published(environment_data,prepared_flame)
        check(Media.prune(environment_data,0).is_empty(),"Pinned environment cannot be evicted by character soft budget")
        check(Media.diagnostics(environment_data).estimated_bytes==0 and Media.diagnostics(environment_data,true).estimated_bytes>0,
            "Environment residency is reported separately from character estimate")
        Media.demand(environment_data,{})
        check(Media.prune(environment_data).is_empty(),"Known environment source remains resident under the combined encounter budget")
        check(Media.prune(environment_data,0)==[flame],"Unpinned environment source participates in the combined soft budget")
    Media.close(environment_data)
    var report = {"checks":checks,"failures":failures,"captured_state":"20261011T223103.996259Z/state.json",
        "companion_cpu_bytes_released":removed_cpu_bytes,"companion_sources":companions,
        "scope":"Exact authored media and typed presentation boundary fixtures; released bytes are decoded-image accounting, not process RSS or VRAM savings; no invented game outcomes"}
    FileAccess.open("res://generated/media_warmup_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
