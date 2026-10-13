extends SceneTree
# Real HTTP choices, with explicitly controlled displayed/native boundaries.
# This proves publication and request ownership, not rendered animation pixels.
const Player = preload("res://play.gd")
const Peer = preload("res://tests/sdk_transport_peer.gd")
const Session = preload("res://presentation/session.gd")
const OTHER = "00000000-0000-4000-8000-000000000002"
var checks = 0
var failures: Array = []
var peer: RefCounted
var player: Node3D
var last_wire: Dictionary = {}

class CompletionPeer extends "res://tests/sdk_transport_peer.gd":
    var held: Dictionary = {}
    var choices_received = 0
    func status(final: int = -1) -> Dictionary:
        var value = super.status(final)
        value.acknowledged_cursor = cursor(0)
        return value
    func _serve(connection: Dictionary, path: String, body: Variant) -> void:
        if not path.ends_with("/choices"):
            super._serve(connection,path,body)
            return
        choices_received += 1
        held = {"connection":connection,"body":body}
    func answer() -> Dictionary:
        var value = scope()
        var body: Dictionary = held.body
        value.merge({"state_revision":body.state_revision,"force_attack":body.force_attack,
            "correlation_id":body.correlation_id,"choices":{"entity_uuid":body.actor_uuid,
            "discovery_generation":choices_received}})
        _response(held.connection,value)
        held = {}
        return value

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("ACTION_COMPLETION_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func pump_until(predicate: Callable, label: String) -> bool:
    var deadline = Time.get_ticks_msec()+5000
    while not predicate.call() and Time.get_ticks_msec()<deadline and player.session.issue.is_empty():
        peer.tick()
        player.session.poll()
        await process_frame
    var ok: bool = predicate.call()
    check(ok,label+str(player.session.issue))
    return ok

func prepare_display() -> void:
    player.session.status = peer.status()
    player.session.status_due = Time.get_ticks_msec()+1000000
    player.session.status_issue = {}
    player.session.latest_sequence = 0
    player.session.following = true
    player.timeline.current = {"id":"recorded-body-in-progress"}
    player.timeline.queue = []
    player.timeline.sequence = -1
    player.timeline.paused = false
    player.timeline.state = {"current_actor_uuid":OTHER}
    player.available_actions = {"entity_uuid":OTHER,"discovery_generation":-1}
    player.choices_boundary = {}
    player.pending_choices = {}
    player.action_revision = "old"
    player.command_busy = false
    player.action_request = -1
    player.await_command_cursor = 0
    player.force_attack = false
    player.choices_force_attack = false
    player.media_initial_ready = true

func request_while_playing() -> bool:
    player._discover()
    return await pump_until(func():return not peer.held.is_empty(),"Native choices arrives while display is behind: ")

func answer_choices() -> bool:
    last_wire = peer.answer()
    var request_id: int = player.action_request
    if not await pump_until(func():return player.session.responses.has(request_id),"Native choices response is admitted: "): return false
    var result: Dictionary = player.session.responses[request_id]
    check(result.ok,"Choices request succeeds: "+str(result.get("error",{})))
    player._poll_actions()
    return result.ok

func run() -> void:
    peer = CompletionPeer.new()
    if not check_start(): return
    var directory = "user://checks/action-completion-"+Session.uuid()
    player = Player.new()
    check(player.session.start({"url":"http://127.0.0.1:%d" % peer.port,"token":"loopback-fixture","journal":directory}).ok,"Start real HTTP session")
    if not await pump_until(func():return player.session.following and player.session.latest_sequence==0,"Native initialization/attachment/follower ready: "):
        await finish(directory); return
    # Do not have test status polling overwrite intentionally controlled races.
    if not await pump_until(func():return player.session.status_request<0,"Initial status response drained: "):
        await finish(directory); return
    prepare_display()
    var original = player.available_actions
    var no_ack: Dictionary = player.session.status.duplicate(true)
    no_ack.acknowledged_cursor = null
    player.session.status = no_ack
    player._discover()
    check(player.action_request<0,"No speculative request before native ACK")
    player.session.status = peer.status()
    player.session.latest_sequence = -1
    player._discover()
    check(player.action_request<0,"Native ACK alone cannot request before the consumed prefix")
    player.session.latest_sequence = 0
    if not await request_while_playing(): await finish(directory); return
    var request_count: int = peer.choices_received
    for i in 8: player._discover()
    check(peer.choices_received==request_count and is_same(player.available_actions,original),"One in-flight request leaves displayed choices untouched")
    if not await answer_choices(): await finish(directory); return
    player._discover()
    check(not player.pending_choices.is_empty() and is_same(player.available_actions,original) and not player.command_ready(),"Arrived future choices remain private during body playback")
    var native_value: Dictionary = player.pending_choices.value
    var snapshot = native_value.duplicate(true)
    player.timeline.current = {}
    player._discover()
    check(is_same(player.available_actions,original),"Idle alone cannot publish before the displayed cursor")
    player.timeline.sequence = 0
    player._discover()
    check(is_same(player.available_actions,original),"Matching cursor still waits for its displayed input actor")
    player.timeline.state.current_actor_uuid = Peer.UUID
    player.timeline.paused = true
    player._discover()
    check(is_same(player.available_actions,original),"Paused playback cannot publish private choices")
    player.timeline.paused = false
    player._discover()
    check(player.command_ready() and is_same(player.available_actions,native_value.choices),"Exactly caught-up display publishes original choices and permits input")
    check(native_value==snapshot and not last_wire.has("kind"),"Publication preserves normalized values and raw omitted defaults")
    player._discover()
    check(peer.choices_received==request_count and player.action_request<0,"Accepted boundary does not request duplicate discovery")

    for stale in ["revision","actor","attachment","game","force_attack","catch_up"]:
        prepare_display()
        if not await request_while_playing(): break
        match stale:
            "revision": player.session.status.boundary.state_revision="new"
            "actor": player.session.status.boundary.input_actor_uuid=OTHER
            "attachment": player.session.status.attachment_epoch=OTHER
            "game": player.session.status.game_epoch=OTHER
            "force_attack": player.force_attack=true
            "catch_up": player.session.status.catch_up_cursor=peer.cursor(1)
        if not await answer_choices(): break
        check(player.pending_choices.is_empty() and player.available_actions.discovery_generation==-1,"Stale "+stale+" response is never published or retained")

    prepare_display()
    if await request_while_playing() and await answer_choices():
        player.session.status.attachment_epoch=OTHER
        player.command_busy=true
        player.pending_request={"kind":"receipt","number":9}
        player._discover()
        check(player.pending_choices.is_empty() and player.pending_request.kind=="receipt" and player.action_request<0,"Attachment change discards private result without stealing receipt ownership")
    prepare_display()
    for kind in ["preview","command","receipt"]:
        player.action_request=999
        player.pending_request={"kind":kind}
        player._discover()
        check(player.action_request==999 and player.pending_request.kind==kind,"Prefetch preserves active "+kind+" request")
    player.action_request=-1
    player.command_busy=true
    player.pending_request={"kind":"receipt","number":9}
    player._discover()
    check(player.action_request<0 and player.pending_request.kind=="receipt","Receipt backoff retains sole request ownership")
    await finish(directory)

func check_start() -> bool:
    var ok: bool = peer.start("idle")
    check(ok,"Start loopback peer")
    if not ok: quit(1)
    return ok

func finish(directory: String) -> void:
    player.session.close()
    peer.close()
    player.context_menu.free()
    player.free()
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    var report = {"checks":checks,"failures":failures,"scope":"Real native HTTP choices and controlled display/ACK/scope boundaries; no rendered-pixel or timing claim."}
    FileAccess.open("res://generated/action_completion_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTION_COMPLETION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
