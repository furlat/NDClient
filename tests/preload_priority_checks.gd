extends SceneTree
# Actual authoring/header selection plus passive upload acknowledgements. No GPU
# allocation or live frame-time claim; all current sources stay independently gated.
const Media = preload("res://presentation/media_warmup.gd")
const Encounter = preload("res://presentation/encounter_media.gd")
const Characters = preload("res://presentation/characters.gd")
const Catalog = preload("res://source_catalog.gd")
const Journal = preload("res://sdk/journal.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
const PROFILE="reference"
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
    for path in paths:size+=int(family.estimates[path].bytes)
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
    var owner:Dictionary=Media.physical(data)
    var pending: Array = owner.pending.duplicate()
    owner.pending.clear();owner.queued.clear();owner.stats.clear()
    for request in pending:
        var size: Dictionary = family.estimates[request.path]
        var loaded = {"path":request.path,"cpu_bytes":size.gpu_bytes,"gpu_bytes":size.gpu_bytes}
        if request.fixture: loaded.merge({"energy":.1,"emission_centroid":Vector2(32,40)})
        Media.published(data,loaded)
    Media.release_cold_images(data,-1) # Offline whole-batch acknowledgement for queue ordering.
    Media.boot_ready(data)

func selected_source(actor:Dictionary,clips:Array,state:Dictionary,cache:Dictionary)->Dictionary:
    var source:Dictionary=Characters.sheet_paths(actor,clips,cache,Characters.item_looks(actor,state))
    if not source.ok:return source
    var selected:Dictionary=source.duplicate()
    selected.value=Geometry.for_profile(source.value,source.normal_sets,PROFILE,cache,"priority-check")
    selected.cpu_required={};selected.gpu_only={}
    for path in selected.value:
        if source.cpu_required.has(path):selected.cpu_required[path]=true
        elif source.gpu_only.has(path):selected.gpu_only[path]=true
    return selected
func settled_selection(data:Dictionary,label:String)->void:
    var end:int=Time.get_ticks_msec()+30000
    while Media.diagnostics(data).selection_pending and Time.get_ticks_msec()<end:
        Media.prepare_optional(data)
        await process_frame
    check(not Media.diagnostics(data).selection_pending,label+": bounded optional metadata/selection reaches its actual publication boundary")

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): recording = arg.trim_prefix("--recording=")
    if recording.is_empty(): check(false,"Usage: --recording=<actual current-schema journal>"); finish(); return
    var journal=Journal.new();var opened:Dictionary=journal.open(recording,true,false)
    check(opened.ok,"Original journal selects its recorded protocol")
    if not opened.ok:finish();return
    var parser = journal.protocol
    var decoded = parser.decode("InitializationResponse",FileAccess.get_file_as_bytes(recording.path_join("0000000000000000.json")))
    check(decoded.ok,"Actual recorded initialization passes public strict admission")
    if not decoded.ok: finish(); return
    var packet = parser.normalize("InitializationResponse",decoded.value)
    var reduced = Reducer.reduce_initialization(packet.initialization,packet.content_additions)
    check(reduced.ok,"Actual initialization reduces through public SDK")
    if not reduced.ok: finish(); return
    var state: Dictionary = reduced.value
    var frozen := var_to_bytes(state)
    var cache = {}; var exact = {}; var optional = {}
    Media._plan_sources({"key":[0],"state":state,"groups":[]},exact,cache)
    exact.optional_request.profile=PROFILE
    Media._plan_optional(exact.optional_request,optional,cache)
    var family: Dictionary = optional.value.encounter
    var rigs: Dictionary = Characters.rigs(cache)
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
            var source = selected_source(actor,[clip],state,cache)
            check(source.ok and source.value.keys().all(func(path):return family.priority.has(path)),actor.name+": authored "+clip+" includes every colour and geometry companion in priority")
        var walking = selected_source(actor,[movement.walkClip],state,cache)
        actor_movement[actor.uuid] = walking
        actor_evidence.append({"name":actor.name,"walking_sources":walking.value.size()})
        var variants: Array = [actor]
        for weapon_set in ["melee","ranged"]:
            var variant: Dictionary = actor.duplicate()
            variant.visual_loadout = actor.visual_loadout.duplicate()
            variant.visual_loadout.active_weapon_set = weapon_set
            variants.append(variant)
        for variant in variants:
            var variant_rest:Dictionary=Characters.rest_sample(variant,rig,cache)
            var source = selected_source(variant,rig.clips.keys() if is_same(variant,actor) else [variant_rest.value.clip],state,cache)
            check(source.ok,"Active full authored family or inactive weapon-set resting closure resolves")
            if source.ok:
                complete.merge(source.value); expected_cpu.merge(source.cpu_required); expected_gpu.merge(source.gpu_only)
    for path in expected_cpu: expected_gpu.erase(path)
    check(family.paths==absolute(complete) and family.cpu_required==expected_cpu and family.gpu_only==expected_gpu,
        "Independent active/inactive selected-profile union preserves every optional source and CPU/GPU role")
    var original_estimates = Encounter.estimates(complete,expected_cpu,expected_gpu,{})
    check(family.estimates==original_estimates,"Actual PNG header costs match the independently assembled selected-profile family")
    check(var_to_bytes(state)==frozen,"Priority planning leaves all canonical actor/outfit values unchanged")
    var priority_bytes = bytes_for(family.priority,family)
    check(priority_bytes<Media.BUDGET_BYTES,"Actual selected-profile priority closures fit the unchanged16GiB default budget")
    var required = Geometry.for_profile(exact.value.required,exact.value.get("normal_sets",{}),PROFILE,cache,"priority-required").duplicate(); required.merge(exact.value.environment_required)
    required = absolute(required)
    var data = Media.create(); Media.adopt_required(data,1); Media.adopt_encounter(data,family,1)
    Media.demand(data,required,exact.value.environment_required,exact.value.fixtures,exact.value.gpu_only,exact.value.cpu_required)
    await settled_selection(data,"Initial cold family")
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
    check(Media.preload_progress(data).selected_estimated_bytes<=Media.BUDGET_BYTES and data.pending.is_empty(),"Warm move→idle neither exceeds16GiB nor requests duplicate decodes")
    Media.close(data)

    # A costly mandatory action can displace optional movement; readiness still
    # requires all its sources, even under a budget fitting only that action.
    var actor: Dictionary = state.actors.values()[0]
    var rig: Dictionary = rigs[Characters.rig_id(actor,cache)]
    var costly = {}
    for clip in rig.clips:
        var source = selected_source(actor,[clip],state,cache)
        if source.ok and source.value.keys().any(func(path):return not family.priority.has(path)):
            costly = source; break
    check(not costly.is_empty(),"Real outfit has a complete nonpriority action source closure")
    var scarce = Media.create(); scarce.budget_bytes = bytes_for(costly.value,family)
    Media.adopt_encounter(scarce,family,2)
    var action_required = absolute(costly.value)
    Media.demand(scarce,action_required,{}, {},costly.gpu_only,costly.cpu_required)
    await settled_selection(scarce,"Expensive mandatory action")
    check(costly.value.keys().all(func(path):return scarce.preload_selected.has(path)) and Media.preload_progress(scarce).selected_estimated_bytes<=scarce.budget_bytes,
        "Mandatory complete expensive action preempts optional priority within exact budget")
    check(family.priority.keys().any(func(path):return not scarce.preload_selected.has(path)),"Constrained fixture really skips some optional priorities")
    ordered_queue(scarce,action_required,"Expensive mandatory action")
    check(not Media.ready(scarce,action_required),"Mandatory action remains blocked before source publication")
    Media.close(scarce)

    var reversed_state: Dictionary = state.duplicate(); reversed_state.actors = {}
    var ids: Array = state.actors.keys(); ids.reverse()
    for id in ids: reversed_state.actors[id] = state.actors[id]
    var reordered = Encounter.plan(reversed_state,exact.value.environment_required,exact.value.fixtures,cache,[],PROFILE)
    var order_changed:bool=reordered.paths.keys()!=family.paths.keys()
    check(reordered.paths==family.paths and (reordered.revision>family.revision if order_changed else reordered.revision==family.revision),
        "Reversing actual actor order changes revision exactly when its authored source order changes")
    check(is_same(reordered,Encounter.plan(reversed_state,exact.value.environment_required,exact.value.fixtures,cache,[],PROFILE)),"Unchanged ordered priority reuses immutable closure")
    # Existing pending optional requests must not defeat the new order.
    var ordering = Media.create(); Media.adopt_encounter(ordering,family,3)
    Media.demand(ordering,required)
    # The current initialization can disclose a single outfit, so reversing
    # actor rows need not alter source order. Exercise queue replacement with
    # an explicit reordered metadata offer of those same exact admitted paths.
    reordered=family.duplicate();reordered.paths={};reordered.priority={}
    var reversed_priority:Array=family.priority.keys();reversed_priority.reverse()
    for path in reversed_priority:reordered.priority[path]=family.priority[path];reordered.paths[path]=family.paths[path]
    for path in family.paths:reordered.paths[path]=family.paths[path]
    reordered.ordered_paths=reordered.paths.keys();reordered.revision=family.revision+1
    check(reordered.paths==family.paths and reordered.paths.keys()!=family.paths.keys(),"Explicit reordered metadata retains every exact original source and changes actual optional priority")
    Media.adopt_encounter(ordering,reordered,3); Media.demand(ordering,required)
    await settled_selection(ordering,"Reordered family with existing optional backlog")
    ordered_queue(ordering,required,"Reordered family with existing optional backlog")
    Media.close(ordering)
    var dying_state: Dictionary = state.duplicate(); dying_state.actors = state.actors.duplicate()
    var dying: Dictionary = actor.duplicate(); dying.life_state = "dead"
    dying_state.actors[actor.uuid] = dying
    var dead_family = Encounter.plan(dying_state,exact.value.environment_required,exact.value.fixtures,cache,[],PROFILE)
    var dead_rest = Characters.rest_sample(dying,rig,cache)
    var death_source = selected_source(dying,[dead_rest.value.clip],dying_state,cache)
    var dead_expected:Dictionary=exact.value.environment_required.duplicate()
    for member in dying_state.actors.values():
        var member_rig:Dictionary=rigs[Characters.rig_id(member,cache)]
        dead_expected.merge(selected_source(member,member_rig.clips.keys(),dying_state,cache).value)
        for weapon_set in ["melee","ranged"]:
            var variant:Dictionary=member.duplicate();variant.visual_loadout=member.visual_loadout.duplicate()
            variant.visual_loadout.active_weapon_set=weapon_set
            var resting:Dictionary=Characters.rest_sample(variant,member_rig,cache)
            dead_expected.merge(selected_source(variant,[resting.value.clip],dying_state,cache).value)
    check(dead_family.paths==absolute(dead_expected) and death_source.value.keys().all(func(path):return dead_family.priority.has(path)),
        "Life-only change preserves every active clip and refreshes actual inactive-set/resting sources and priority")
    evidence={"actors":actor_evidence,"priority_paths":family.priority.size(),"priority_bytes":priority_bytes,
        "full_paths":family.paths.size(),"full_bytes":Encounter.estimate_summary(family).bytes,"budget":Media.BUDGET_BYTES}
    finish()
func finish() -> void:
    var report={"checks":checks,"failures":failures,"recording":recording,"evidence":evidence,
        "scope":"Actual selected Reference-profile authored sources/headers; passive decode/upload acknowledgements verify complete active/inactive-set family membership, roles, movement readiness, retention, asynchronous priority publication and queue order without bitmap allocation. Unchanged16GiB default plus a measured complete-action budget exercises optional displacement. Live latency measured separately."}
    FileAccess.open("res://generated/preload_priority_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PRELOAD_PRIORITY_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
