extends SceneTree
# Real Crypt discovery -> preview -> command -> projected source -> actual pixels.
const Player = preload("res://play.tscn")
const Interaction = preload("res://presentation/interaction.gd")
const Journal = preload("res://sdk/journal.gd")
var scene: Node
var checks := 0
var failures: Array = []
var evidence: Dictionary = {}
var started := Time.get_ticks_msec()

func _initialize() -> void: run.call_deferred()
func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition: failures.append(message); print("LIGHTING_LIVE_FAIL ",message)
func until(predicate: Callable, label: String) -> bool:
    var deadline := Time.get_ticks_msec()+60000
    while not predicate.call() and scene.session.issue.is_empty() and scene.presentation_errors.is_empty() and Time.get_ticks_msec()<deadline:
        await scene.presentation_updated
    var ok: bool = predicate.call() and scene.session.issue.is_empty() and scene.presentation_errors.is_empty()
    check(ok,label+" "+str(scene.session.issue)+" "+str(scene.presentation_errors))
    return ok
func capture() -> Image:
    for i in range(3): await scene.presentation_updated
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func brightness_delta(first: Image,second: Image) -> float:
    var total := 0.0
    var count := 0
    for y in range(240,650,2):
        for x in range(420,1000,2):
            var a := first.get_pixel(x,y); var b := second.get_pixel(x,y)
            total += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b); count += 3
    return total/count

func run() -> void:
    scene = Player.instantiate(); root.add_child(scene)
    if not await until(func():return scene.command_ready(),"Real scene receives admitted choices"): await finish(); return
    var count: int = scene.source_lighting.sources.size()
    evidence.initial_sources = scene.source_lighting.sources.duplicate(true)
    evidence.initial_issues = scene.source_lighting.issues.duplicate(true)
    check(scene.source_lighting.issues.is_empty(),"Current schema supplies every visible item source radius")
    check(count == 4,"Crypt has two disclosed fixed and two controlled carried sources")
    check(scene.source_lighting.sources.filter(func(source):return source.actor_uuid.is_empty()).size() == 2,"Visual object contacts supply both native wall torches")
    check(scene.get_children().filter(func(child):return child is DirectionalLight3D).is_empty(),"Empty directional authoring adds no unconditional key light")
    for entry in scene.static_entries+scene.actor_entries:
        check(entry.material.get_shader_parameter("authored_base_light") == 0.0,"Live sprite has no base emission: "+entry.id)
    var first := await capture()
    var owner: String = scene.available_actions.entity_uuid
    var torch_id := ""
    for lit in [false,true]:
        var candidates := Interaction.actions(scene.available_actions).filter(func(action):return action.behavior_id == ("action.item.torch.ignite" if lit else "action.item.torch.extinguish") and action.can_afford)
        check(not candidates.is_empty(),"Native discovery offers carried torch activation "+str(lit))
        if candidates.is_empty(): await finish(); return
        var action: Dictionary = candidates[0]
        torch_id = action.source_item_uuid
        var sequence: int = scene.timeline.sequence
        var command: int = scene.session.status.next_command_number
        scene.select_action(action)
        if not await until(func():return scene.command_ready() and scene.timeline.sequence>sequence and scene.session.status.next_command_number>command,"Native torch operation is displayed"): await finish(); return
        var items: Array = scene.timeline.state.actors[owner].controlled_items
        var item: Dictionary = items.filter(func(value):return value.item_uuid == torch_id)[0]
        check(item.is_lit == lit,"Displayed authoritative item activation matches native command")
        check(scene.source_lighting.sources.any(func(source):return source.item_uuid == torch_id) == lit,"GPU source membership follows displayed activation")
        check(scene.source_lighting.sources.size() == count-(0 if lit else 1),"Only the affected source changes")
        var picture := await capture()
        if not lit:
            evidence.extinguish_pixel_delta = brightness_delta(first,picture)
            check(evidence.extinguish_pixel_delta > 0.0001,"Real rendered world pixels respond to extinguishing carried source")
            picture.save_png(scene.game_config.test_result.get_base_dir().path_join("lighting-extinguished.png"))
        else: picture.save_png(scene.game_config.test_result.get_base_dir().path_join("lighting-restored.png"))
    evidence.final_sources = scene.source_lighting.sources.duplicate(true)
    first.save_png(scene.game_config.test_result.get_base_dir().path_join("lighting-initial.png"))
    await finish()

func finish() -> void:
    scene.set_process(false); scene.session.close()
    if not scene.timeline.state.is_empty():
        check(scene.timeline.state == scene.session.journal.state,"Displayed source operations match canonical reducer state")
        var replay := Journal.new(); var result := replay.open(scene.game_config.journal)
        check(result.ok and replay.state == scene.timeline.state,"Source activation recording cold-replays exactly")
    var report := {"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started,"evidence":evidence,"renderer":RenderingServer.get_video_adapter_name()}
    var file := FileAccess.open(scene.game_config.test_result,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ",true,true)); file.close()
    print("LIGHTING_LIVE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"elapsed_ms":report.elapsed_ms}))
    scene.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
