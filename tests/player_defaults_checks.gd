extends SceneTree
# Valid protocol defaults must also reach the presentation consumer and input
# lifecycle. Raw SDK/journal records remain exactly as received.
const Session = preload("res://presentation/session.gd")
const Peer = preload("res://tests/sdk_transport_peer.gd")
const Player = preload("res://play.gd")
const Timeline = preload("res://presentation/timeline.gd")
var failures: Array = []
var checks = 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); print("PLAYER_DEFAULTS_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func prepared_until_ready(session: RefCounted, sequence: int) -> void:
    var deadline = Time.get_ticks_msec()+15000
    while session.diagnostics().prepared_sequence<sequence and session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        session.poll(); await process_frame
func prepared_until(session: RefCounted, sequence: int) -> Array:
    var deadline = Time.get_ticks_msec()+15000
    while session.diagnostics().prepared_sequence<sequence and session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        session.poll(); await process_frame
    session.poll()
    return session.take_prepared()
func run() -> void:
    var peer = Peer.new()
    var session = Session.new()
    var directory = "user://checks/defaults-"+Session.uuid()
    check(session.journal.open(directory).ok,"Open temporary raw journal")
    var initial = peer.initial()
    initial.erase("kind")
    var raw = JSON.stringify(initial).to_utf8_buffer()
    check(session.protocol.decode("InitializationResponse",raw).ok,"Omitted initialization kind is a valid wire default")
    var admitted = session._consume(initial,raw)
    check(admitted.ok,"Session admits initialization with omitted kind")
    var prepared = await prepared_until(session,0)
    check(prepared.size()==1 and prepared[0].kind=="initialization" and prepared[0].state==session.journal.state,"Initial display receives the admitted canonical state")
    check(FileAccess.get_file_as_bytes(directory.path_join("0000000000000000.json"))==raw and not initial.has("kind"),"Preparation preserves original default-omitted bytes")
    var player = Player.new()
    player.session = Session.new() # The receipt fixture deliberately has no scene-tree startup.
    var receipt = peer.scope()
    receipt.merge({"command_number":1,"cursor":peer.cursor(1)})
    var response = {"receipt":receipt}
    check(player.session.protocol.validate("ReceiptResponse",response).ok,"Omitted receipt discriminators are valid wire defaults")
    player.action_request = 42
    player.command_busy = true
    player.pending_request = {"kind":"receipt","number":1}
    player.session.responses[42] = {"ok":true,"value":response,
        "normalized":player.session.protocol.normalize("ReceiptResponse",response)}
    player._poll_actions()
    check(not player.command_busy and player.await_command_cursor==1,"Committed receipt releases request hold and awaits its actual display cursor")
    check(not response.has("kind") and not receipt.has("kind"),"Defaulted presentation copy never mutates SDK response")
    player.context_menu.free(); player.free(); session.close()
    DirAccess.remove_absolute(directory.path_join("0000000000000000.json"))
    DirAccess.remove_absolute(directory)
    # A retained journal has later canonical state before the fresh follower
    # replays initialization. Never expose that future state in frame zero.
    var retained = "user://checks/retained-"+Session.uuid()
    DirAccess.make_dir_recursive_absolute(retained)
    for pair in [["initialization","0000000000000000"],["operation","0000000000000001"]]:
        var file = FileAccess.open(retained.path_join(pair[1]+".json"),FileAccess.WRITE)
        file.store_buffer(FileAccess.get_file_as_bytes("res://tests/fixtures/player/"+pair[0]+".json")); file.close()
    var restored = Session.new()
    check(restored.journal.open(retained,true).ok,"Restore a real two-packet retained journal")
    restored.protocol = restored.journal.protocol
    var final_state = restored.journal.state.duplicate(true)
    var first_raw = FileAccess.get_file_as_bytes(retained.path_join("0000000000000000.json"))
    var first = restored.protocol.decode("InitializationResponse",first_raw).value
    check(restored._consume(first,first_raw).ok,"Fresh follower reconciles duplicate initialization")
    var messages = await prepared_until(restored,0)
    check(messages.size()==1 and messages[0].state.reducer_cursor < final_state.reducer_cursor,"Initial display uses initial prefix, never restored future facts")
    var timeline = Timeline.new(); timeline.accept(messages[0])
    var second_raw = FileAccess.get_file_as_bytes(retained.path_join("0000000000000001.json"))
    var second = restored.protocol.decode("PlayerOperation",second_raw).value
    check(restored._consume(second,second_raw).ok,"Duplicate operation prepares from its exact earlier display prefix")
    for message in await prepared_until(restored,1): timeline.accept(message)
    timeline.advance(100000)
    check(timeline.state==final_state and timeline.sequence==1,"Retained follower reaches canonical state without leaking or skipping history")
    restored.close()
    var replay = Session.new(); check(replay.open_recording(retained).ok,"Open recorded prefix for single-pass preparation")
    var deadline = Time.get_ticks_msec()+15000
    while not replay.terminal and Time.get_ticks_msec()<deadline:
        replay.poll(); await process_frame
    await prepared_until_ready(replay,1)
    replay.close()
    var offline = Timeline.new()
    for message in replay.take_prepared(): offline.accept(message)
    offline.advance(100000)
    check(replay.issue.is_empty() and offline.state==final_state and offline.sequence==1,"Offline single-pass preparation equals restored canonical journal")
    DirAccess.rename_absolute(retained.path_join("0000000000000001.json"),retained.path_join("0000000000000002.json"))
    var renamed = Session.new(); renamed.open_recording(retained)
    deadline = Time.get_ticks_msec()+15000
    while not renamed.terminal and Time.get_ticks_msec()<deadline:
        renamed.poll(); await process_frame
    renamed.close()
    check(renamed.issue.get("message","") in ["Journal filename/cursor mismatch","Journal filename sequence gap"] and not FileAccess.file_exists(retained.path_join("0000000000000001.json")),"Renamed record is rejected without manufacturing a missing original packet")
    for filename in DirAccess.get_files_at(retained): DirAccess.remove_absolute(retained.path_join(filename))
    DirAccess.remove_absolute(retained)
    print("PLAYER_DEFAULTS_CHECKS checks=",checks," failures=",failures)
    quit(0 if failures.is_empty() else 1)
