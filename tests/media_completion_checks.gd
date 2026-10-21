extends SceneTree
# Timeline/input-readiness boundary with declared resident source packets, plus
# real authored source selection from an explicitly supplied recorded state.
# No GPU upload, visual, or native-frame timing claim.
const Player = preload("res://play.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Characters = preload("res://presentation/characters.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Compiler = preload("res://presentation/compiler.gd")
const Peer = preload("res://tests/sdk_transport_peer.gd")
const Journal = preload("res://sdk/journal.gd")
class CompletionPlayer extends "res://play.gd":
    func _ready()->void:
        set_process(false);set_process_unhandled_input(false)
        camera=Camera3D.new();add_child(camera);add_child(context_menu)
        rig_config=Characters._read("catalog/rig.json",catalog_cache)
var checks := 0
var failures: Array = []
var evidence: Dictionary = {}
var character_path := ""
var environment_path := ""
var disclosed_tile: Dictionary = {}
var disclosed_cell := ""
var admitted_sources: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("MEDIA_COMPLETION_FAIL ",label)

func group(id: String, commits: Array = [], duration := 20.0) -> Dictionary:
    return {"id":id,"duration_ms":duration,"commits":commits,"actor_tracks":[],
        "staged_actors":{},"staged_at_ms":{},"staged_tiles":{},"staged_tile_at_ms":{},
        "operation_sequence":1,"operation_end":true}

func fixture(row: Dictionary) -> Node3D:
    var player = CompletionPlayer.new()
    player.session = Player.Session.new()
    player.catalog_cache = Characters.Catalog.source_snapshot(admitted_sources)
    player.media_warmup.plan_cache = Characters.Catalog.source_snapshot(admitted_sources)
    root.add_child(player) # Real native preparation needs its viewport and camera, even with no effect rows.
    player.timeline.accept({"kind":"initialization","sequence":0,"state":{
        "actors":{},"tiles":{},"objects":{},"spatial_commit_cursors":{},"combat_log_appends":[],
        "senses":null,"audience":{"controlled":[]},"round_number":1,"current_actor_uuid":Peer.UUID}})
    player.timeline.media_ready = player._media_ready
    player.world_revision = 0
    player.world_prepare_epoch=player.timeline.initialization_revision
    player.media_warmup.boot_complete = true
    player.media_plan_epoch = player.timeline.initialization_revision
    player.media_group_plans[row.id] = {"character":{character_path:true},"environment":{environment_path:true},
        "fixtures":{environment_path:true},"errors":[],"gpu_only":{},"cpu_required":{character_path:true}}
    var lease:Dictionary=Media.source_record({character_path:true,environment_path:true},{environment_path:true},{environment_path:true},{},{character_path:true})
    player.media_group_plans[row.id].source_records={player.character_light_profile:[lease]}
    Media.published(player.media_warmup,{"path":character_path,"cpu_bytes":16,"gpu_bytes":16})
    Media.published(player.media_warmup,{"path":environment_path,"cpu_bytes":16,"gpu_bytes":16,
        "energy":0.5,"emission_centroid":Vector2.ZERO})
    player.timeline.accept({"kind":"operation","groups":[row]})
    var peer = Peer.new()
    player.session.status = peer.status()
    player.session.status.acknowledged_cursor = peer.cursor(1)
    player.session.status.catch_up_cursor = peer.cursor(1)
    player.session.latest_sequence = 1
    player.session.following = true
    player.available_actions = {"entity_uuid":Peer.UUID,"discovery_generation":1}
    player.action_revision = player.session.status.boundary.state_revision
    player.choices_boundary = player.session.ready_choice_boundary()
    return player

func dispose(player: Node3D) -> void:
    player.free()

func authored_union(original: Dictionary, path: String) -> void:
    var frozen:PackedByteArray=var_to_bytes(original)
    var state: Dictionary = original.duplicate(true)
    var actor: Dictionary = state.actors[state.observer_uuid]
    var ranged: Dictionary = actor.duplicate(true)
    ranged.visual_loadout.active_weapon_set = "ranged"
    var dead: Dictionary = ranged.duplicate(true)
    dead.life_state = "dead"
    var row = group("terminal-outfit-and-life",[
        {"at_ms":10,"delta":{"actors":{actor.uuid:ranged}}},
        {"at_ms":20,"delta":{"actors":{actor.uuid:dead}}}])
    var cache = {}
    var plan = Media.plan(state,[row],cache)
    var world_plan = EnvironmentMedia.plan(state,[row],cache)
    for commit in row.commits: Compiler.apply_delta(state,commit.delta)
    var terminal = Media.plan(state,[],cache)
    var terminal_world = EnvironmentMedia.plan(state,[],cache)
    var ranged_rest = Media.plan(_with_actor(original,ranged),[],cache)
    check(plan.errors.is_empty() and terminal.errors.is_empty(),"Recorded outfit and actual authored terminal life clip resolve")
    check(terminal.required.keys().all(func(source):return plan.required.has(source)),"Group union contains terminal resting/death sources")
    check(ranged_rest.required.keys().all(func(source):return plan.required.has(source)),"Group union contains committed ranged outfit rest sources")
    check(terminal.required.keys().any(func(source):return source.contains("Die") or source.contains("Death")),"Terminal union really requests authored death media")
    check(terminal_world.required.keys().all(func(source):return world_plan.required.has(source)),"Group environment union contains terminal world sources")
    check(var_to_bytes(original)==frozen,"Planning/terminal folding preserves the supplied canonical snapshot")
    character_path = plan.required.keys()[0]
    environment_path = world_plan.required.keys()[0]
    disclosed_cell = original.tiles.keys()[0]
    disclosed_tile = original.tiles[disclosed_cell]
    # Match Play._ready's admitted source handoff before any metadata worker.
    admitted_sources = Characters.Catalog.source_snapshot(cache)
    evidence = {"state":path,"group_character_sources":plan.required.size(),"terminal_character_sources":terminal.required.size(),
        "terminal_environment_sources":terminal_world.required.size()}

func _with_actor(state: Dictionary, actor: Dictionary) -> Dictionary:
    var value: Dictionary = state.duplicate(true)
    value.actors[actor.uuid] = actor
    return value

func run() -> void:
    var path := "";var recording:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--state="): path = argument.trim_prefix("--state=")
        if argument.begins_with("--recording="):recording=argument.trim_prefix("--recording=")
    var original:Dictionary={}
    if not recording.is_empty():
        var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(recording,true,false)
        check(opened.ok,"Actual source recording opens without schema substitution")
        if not opened.ok:quit(1);return
        var initialized:Dictionary=journal.replay(0)
        check(initialized.ok,"Original initialization folds through the current SDK")
        if not initialized.ok:quit(1);return
        original=journal.state;path=recording
    elif not path.is_empty() and FileAccess.file_exists(path):original=JSON.parse_string(FileAccess.get_file_as_string(path))
    else:
        print("Usage: --recording=<actual current-schema journal> or --state=<recorded canonical state.json>")
        quit(2);return
    authored_union(original,path)
    var commits: Array = [{"at_ms":10,"delta":{"set":{"round_number":2}}},
        {"at_ms":20,"delta":{"set":{"round_number":3}}}]
    var player = fixture(group("multiple-final-commits",commits))
    player.timeline.advance(10)
    check(player.timeline.commit_index==1 and player.timeline.state.round_number==2 and not player.command_ready(),"Prepared group applies its first commit while input stays closed: "+JSON.stringify(player.media_gate))
    player.timeline.advance(10)
    check(player.timeline.state.round_number==3 and player.command_ready(),"Final commit reaches acknowledged input boundary")
    var jobs: int = player.media_warmup.metadata_jobs
    for frame in 5:
        player.timeline.advance(1)
        check(player.command_ready() and not player.timeline.waiting_for_media,"Input stays ready on idle sample %d" % frame)
    check(player.media_warmup.metadata_jobs==jobs and player.media_warmup.plan_thread==null,"Completion needs no redundant idle metadata worker")
    check(player.media_environment_required.has(environment_path) and player.media_plan.required.has(character_path),"Reused terminal demand retains character and environment sources")
    check(player.media_warmup.fixtures.has(environment_path) and player.media_warmup.resident[environment_path].fixture_ready,"Terminal demand retains fixture preprocessing roles")
    check(player.media_terminal_plan.is_empty(),"Consumed proof does not retain the completed group")
    dispose(player)

    player = fixture(group("resumed-mid-group",commits))
    player.timeline.media_ready = Callable()
    player.timeline.advance(10)
    player.timeline.media_ready = player._media_ready
    player.timeline.advance(10)
    player.timeline.advance(0)
    check(player.command_ready() and player.media_warmup.plan_thread==null,"First readiness capture midway subtracts already applied commits")
    dispose(player)

    player = fixture(group("zero-commit",[],0))
    player.timeline.advance(0); player.timeline.advance(0)
    check(player.command_ready() and player.media_warmup.plan_thread==null,"Zero-duration zero-commit completion keeps prepared readiness")
    dispose(player)

    player = fixture(group("terminal-world-admission",[
        commits[0],{"at_ms":20,"delta":{"tiles":{disclosed_cell:disclosed_tile}}}]))
    var world_gate = {"ready":false}
    player.timeline.world_ready = func(_candidate): return world_gate.ready
    player.timeline.advance(10); player.timeline.advance(10)
    check(player.timeline.waiting_for_world and player.timeline.state.tiles.is_empty() and not player.command_ready(),
        "Prepared terminal media does not bypass held world admission")
    world_gate.ready = true
    player.timeline.advance(0); player.timeline.advance(0)
    check(player.command_ready() and player.media_warmup.plan_thread==null and player.timeline.state.tiles[disclosed_cell]==disclosed_tile,
        "World-prepared final commit preserves readiness without early tile publication")
    dispose(player)

    for mismatch in ["epoch","state-owner","revision","completion-count","completion-id"]:
        player = fixture(group("stale-"+mismatch))
        player.timeline.advance(20)
        match mismatch:
            "epoch": player.timeline.accept({"kind":"initialization","sequence":1,"state":player.timeline.state.duplicate(true)})
            "state-owner": player.timeline.state = player.timeline.state.duplicate(true)
            "revision": player.timeline.revision += 1
            "completion-count": player.timeline.completed_group_count += 1
            "completion-id":
                check(not player.timeline.completed_groups.is_empty(),"Completion identity control starts from an actually completed group")
                if player.timeline.completed_groups.is_empty():dispose(player);continue
                player.timeline.completed_groups[-1].id = "another-group"
        player.timeline.advance(0)
        check(not player.command_ready() and player.timeline.waiting_for_media,"Unproved "+mismatch+" boundary cannot reuse terminal readiness")
        check(player.media_warmup.plan_thread!=null,"Unproved "+mismatch+" boundary uses normal metadata preparation")
        dispose(player)

    for missing in ["character","environment","fixture-metrics","failure"]:
        player = fixture(group("missing-"+missing))
        player.timeline.advance(20)
        var source: String = character_path if missing in ["character","failure"] else environment_path
        if missing=="failure": player.media_warmup.failed[source] = "Required source unavailable"
        elif missing=="fixture-metrics":
            Media.published(player.media_warmup,{"path":source,"cpu_bytes":16,"gpu_bytes":16})
        else:
            player.media_warmup.resident.erase(source); player.media_warmup.ready_paths.erase(source)
        if missing in ["environment","fixture-metrics"]:
            check(not player._environment_sources_ready(),"The exact source owner refuses missing "+missing)
            # Live environment residency belongs to its prepared world cut.
            # An unprepared replacement cannot borrow that previous admission.
            player.world_prepare_epoch=-1
        player.timeline.advance(0)
        check(not player.command_ready() and player.timeline.waiting_for_media,"Valid terminal proof still blocks missing "+missing)
        check(player.media_metadata_ready and player.media_warmup.plan_thread==null,"Missing "+missing+" does not discard valid metadata")
        dispose(player)

    player = fixture(group("completed-before-new-group"))
    player.timeline.advance(20)
    player.timeline.accept({"kind":"operation","groups":[group("new-unprepared-group")]})
    player.timeline.advance(0)
    check(player.timeline.waiting_for_media and not player.command_ready() and player.timeline.completed_group_count==1,"A genuinely new group still waits for its own preparation")
    dispose(player)
    var report = {"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Real authored source unions and Timeline/input gates with declared residency; no GPU, visual, or frame-time claim."}
    FileAccess.open("res://generated/media_completion_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("MEDIA_COMPLETION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
