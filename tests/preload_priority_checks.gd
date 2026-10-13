extends SceneTree
# Actual authoring/header selection plus passive upload acknowledgements. No GPU
# allocation or live frame-time claim; all current sources stay independently gated.
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
const Characters = preload("res://presentation/characters.gd")
const Catalog = preload("res://source_catalog.gd")
const Protocol = preload("res://sdk/protocol.gd")
const Reducer = preload("res://sdk/reducer.gd")
var checks = 0
var failures: Array = []
var evidence = {}
var recording = ""
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("PRELOAD_PRIORITY_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func absolute(paths: Dictionary) -> Dictionary:
    var result = {}
    for path in paths: result[path] = Catalog.media_path(path)
    return result
func bytes_for(paths: Dictionary, family: Dictionary) -> int:
    var size = 0
    for path in paths: size += int(family.estimate_bytes[path])
    return size
func ordered_queue(data: Dictionary, required: Dictionary, label: String) -> void:
    var expected: Array = []
    for path in required:
        if data.queued.has(path): expected.append(path)
    for path in data.encounter.priority:
        if data.preload_selected.has(path) and not required.has(path) and data.queued.has(path): expected.append(path)
    var actual: Array = data.pending.map(func(row):return row.path)
    check(actual.slice(0,expected.size())==expected,label+": required then all selected authored priorities precede other optional work")
    var unique = {}
    for path in actual: unique[path] = true
    check(unique.size()==actual.size(),label+": queue contains each source once")
func acknowledge(data: Dictionary, family: Dictionary) -> void:
    var pending: Array = data.pending
    data.pending = []; data.queued.clear(); data.stats = {}
    for request in pending:
        var size: Dictionary = family.estimates[request.path]
        var loaded = {"path":request.path,"cpu_bytes":size.cpu_bytes,"gpu_bytes":size.gpu_bytes}
        if request.fixture: loaded.merge({"energy":.1,"emission_centroid":Vector2(32,40)})
        Media.published(data,loaded)
    Media.release_cold_images(data)
    Media.boot_ready(data)

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): recording = arg.trim_prefix("--recording=")
    if recording.is_empty(): check(false,"Usage: --recording=<actual current-schema journal>"); finish(); return
    var parser = Protocol.new()
    var decoded = parser.decode("InitializationResponse",FileAccess.get_file_as_bytes(recording.path_join("0000000000000000.json")))
    check(decoded.ok,"Actual current-server initialization passes public strict admission")
    if not decoded.ok: finish(); return
    var packet = parser.normalize("InitializationResponse",decoded.value)
    var reduced = Reducer.reduce_initialization(packet.initialization,packet.content_additions)
    check(reduced.ok,"Actual initialization reduces through public SDK")
    if not reduced.ok: finish(); return
    var state: Dictionary = reduced.value
    var frozen := var_to_bytes(state)
    var cache = {}; var exact = {}; var optional = {}
    Media._plan_sources({"key":[0],"state":state,"groups":[]},exact,cache)
    Media._plan_optional(exact.optional_request,optional,cache)
    var family: Dictionary = optional.value.encounter
    var rigs: Dictionary = Characters._read("catalog/rigs.json",cache)
    var movement: Dictionary = Characters._read("catalog/movement_context.json",cache)
    var complete: Dictionary = exact.value.environment_required.duplicate()
    var expected_cpu: Dictionary = complete.duplicate()
    var expected_gpu = {}; var actor_movement = {}; var actor_evidence = []
    for actor in state.actors.values():
        var rig: Dictionary = rigs[Characters.rig_id(actor,cache)]
        var rest = Characters.rest_sample(actor,rig,cache)
        var clips: Array = [rest.value.clip,movement.walkClip,movement.jumpClip]
        for clip in clips:
            if not rig.clips.has(clip): continue
            var source = Characters.sheet_paths(actor,[clip],cache)
            check(source.ok and source.value.keys().all(func(path):return family.priority.has(path)),actor.name+": authored "+clip+" includes every colour and geometry companion in priority")
        var walking = Characters.sheet_paths(actor,[movement.walkClip],cache)
        actor_movement[actor.uuid] = walking
        actor_evidence.append({"name":actor.name,"walking_sources":walking.value.size()})
        var variants: Array = [actor]
        for weapon_set in ["melee","ranged"]:
            var variant: Dictionary = actor.duplicate()
            variant.visual_loadout = actor.visual_loadout.duplicate()
            variant.visual_loadout.active_weapon_set = weapon_set
            variants.append(variant)
        for variant in variants:
            var source = Characters.sheet_paths(variant,rig.clips.keys(),cache)
            check(source.ok,"Complete existing authored family resolves")
            if source.ok:
                complete.merge(source.value); expected_cpu.merge(source.cpu_required); expected_gpu.merge(source.gpu_only)
    for path in expected_cpu: expected_gpu.erase(path)
    check(family.paths==absolute(complete) and family.cpu_required==expected_cpu and family.gpu_only==expected_gpu,
        "Priority changes no full source membership or CPU/GPU role")
    var original_estimates = Encounter.estimates(complete,expected_cpu,expected_gpu,{})
    check(family.estimates==original_estimates,"Actual PNG header costs match independently assembled exhaustive family")
    check(var_to_bytes(state)==frozen,"Priority planning leaves all canonical actor/outfit values unchanged")
    var priority_bytes = bytes_for(family.priority,family)
    check(priority_bytes<Media.BUDGET_BYTES and family.estimate_summary.bytes>Media.BUDGET_BYTES,"Fixture genuinely fits priority closures but exceeds budget with exhaustive families")
    var required = exact.value.required.duplicate(); required.merge(exact.value.environment_required)
    required = absolute(required)
    var data = Media.create(); Media.adopt_required(data,1); Media.adopt_encounter(data,family,1)
    Media.demand(data,required,exact.value.environment_required,exact.value.fixtures,exact.value.gpu_only,exact.value.cpu_required)
    check(family.priority.keys().all(func(path):return data.preload_selected.has(path)),"Every admitted outfit priority survives initial16GiB selection")
    ordered_queue(data,required,"Initial cold family")
    check(not Media.ready(data,required) and not Media.boot_ready(data),"Priority selection never substitutes for required byte publication")
    acknowledge(data,family)
    check(Media.ready(data,required) and Media.boot_ready(data),"Exact upload acknowledgements satisfy existing startup gate")
    for actor in state.actors.values():
        var source: Dictionary = actor_movement[actor.uuid]
        var moving: Dictionary = required.duplicate(); moving.merge(absolute(source.value))
        var cpu: Dictionary = exact.value.cpu_required.duplicate(); cpu.merge(source.cpu_required)
        var gpu: Dictionary = exact.value.gpu_only.duplicate(); gpu.merge(source.gpu_only)
        Media.demand(data,moving,exact.value.environment_required,exact.value.fixtures,gpu,cpu)
        Media.demand(data,required,exact.value.environment_required,exact.value.fixtures,exact.value.gpu_only,exact.value.cpu_required)
        Media.prune(data)
        check(source.value.keys().all(func(path):return data.preload_selected.has(path) and data.resident.has(path)) and Media.ready(data,source.value),
            actor.name+": move→idle keeps complete authored movement resident and ready")
    check(data.preload_estimated_bytes<=Media.BUDGET_BYTES and data.pending.is_empty(),"Warm move→idle neither exceeds16GiB nor requests duplicate decodes")
    Media.close(data)

    # A costly mandatory action can displace optional movement; readiness still
    # requires all its sources, even under a budget fitting only that action.
    var actor: Dictionary = state.actors.values()[0]
    var rig: Dictionary = rigs[Characters.rig_id(actor,cache)]
    var costly = {}
    for clip in rig.clips:
        var source = Characters.sheet_paths(actor,[clip],cache)
        if source.ok and source.value.keys().any(func(path):return not family.priority.has(path)):
            costly = source; break
    check(not costly.is_empty(),"Real outfit has a complete nonpriority action source closure")
    var scarce = Media.create(); scarce.budget_bytes = bytes_for(costly.value,family)
    Media.adopt_encounter(scarce,family,2)
    var action_required = absolute(costly.value)
    Media.demand(scarce,action_required,{}, {},costly.gpu_only,costly.cpu_required)
    check(costly.value.keys().all(func(path):return scarce.preload_selected.has(path)) and scarce.preload_estimated_bytes<=scarce.budget_bytes,
        "Mandatory complete expensive action preempts optional priority within exact budget")
    check(family.priority.keys().any(func(path):return not scarce.preload_selected.has(path)),"Constrained fixture really skips some optional priorities")
    ordered_queue(scarce,action_required,"Expensive mandatory action")
    check(not Media.ready(scarce,action_required),"Mandatory action remains blocked before source publication")
    Media.close(scarce)

    var reversed_state: Dictionary = state.duplicate(); reversed_state.actors = {}
    var ids: Array = state.actors.keys(); ids.reverse()
    for id in ids: reversed_state.actors[id] = state.actors[id]
    var reordered = Encounter.plan(reversed_state,exact.value.environment_required,exact.value.fixtures,cache)
    check(reordered.paths==family.paths and reordered.paths.keys()!=family.paths.keys() and reordered.revision>family.revision,
        "Same source set with reordered outfit priority invalidates retained closure order")
    check(is_same(reordered,Encounter.plan(reversed_state,exact.value.environment_required,exact.value.fixtures,cache)),"Unchanged ordered priority reuses immutable closure")
    # Existing pending optional requests must not defeat the new order.
    var ordering = Media.create(); Media.adopt_encounter(ordering,family,3)
    Media.demand(ordering,required)
    reordered = reordered.duplicate(); reordered.estimates=family.estimates
    reordered.estimate_bytes=family.estimate_bytes; reordered.estimate_summary=family.estimate_summary
    Media.adopt_encounter(ordering,reordered,3); Media.demand(ordering,required)
    ordered_queue(ordering,required,"Reordered family with existing optional backlog")
    Media.close(ordering)
    var dying_state: Dictionary = state.duplicate(); dying_state.actors = state.actors.duplicate()
    var dying: Dictionary = actor.duplicate(); dying.life_state = "dead"
    dying_state.actors[actor.uuid] = dying
    var dead_family = Encounter.plan(dying_state,exact.value.environment_required,exact.value.fixtures,cache)
    var dead_rest = Characters.rest_sample(dying,rig,cache)
    var death_source = Characters.sheet_paths(dying,[dead_rest.value.clip],cache)
    check(dead_family.paths==family.paths and death_source.value.keys().all(func(path):return dead_family.priority.has(path)),
        "Life-only change refreshes authored resting priority without changing exhaustive source closure")
    evidence={"actors":actor_evidence,"priority_paths":family.priority.size(),"priority_bytes":priority_bytes,
        "full_paths":family.paths.size(),"full_bytes":family.estimate_summary.bytes,"budget":Media.BUDGET_BYTES}
    finish()
func finish() -> void:
    var report={"checks":checks,"failures":failures,"recording":recording,"evidence":evidence,
        "scope":"Actual authored sources/headers; passive upload acknowledgements verify selection, readiness, retention and queue order without GPU allocations. Full closure/roles and strict16GiB budget preserved. Live latency measured separately."}
    FileAccess.open("res://generated/preload_priority_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PRELOAD_PRIORITY_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
