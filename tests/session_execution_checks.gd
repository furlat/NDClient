extends SceneTree
# Native HTTP loopback tests durable delivery independently of bounded display
# preparation. The peer is a wire fixture, not a replacement gameplay simulation.
const Session = preload("res://presentation/session.gd")
const Timeline = preload("res://presentation/timeline.gd")
const Peer = preload("res://tests/sdk_transport_peer.gd")
var checks = 0
var failures: Array = []
var peer: RefCounted
var session: RefCounted
var evidence = {}
func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("SESSION_EXECUTION_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
    if peer!=null: peer.tick()
    if session!=null: session.poll()
    return false
func until(predicate: Callable,label: String) -> bool:
    var deadline = Time.get_ticks_msec()+20000
    while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
    var reached:bool=predicate.call()
    check(reached,label)
    return reached
func null_senses_cut(source:Dictionary) -> void:
    # Named compiler-output control over the real loopback's reduced state.
    # Absence of sensory disclosure remains null; no game fact, optical member
    # or replacement senses={} is invented to make the timeline accept it.
    var actual=Timeline.new()
    actual.accept({"kind":"initialization","state":source.duplicate(true),"sequence":0})
    var before:PackedByteArray=var_to_bytes(actual.state)
    var resources:int=actual.resource_revision
    actual.accept({"kind":"operation","groups":[{"id":"unit:null-senses","operation_sequence":1,
        "operation_end":true,"duration_ms":0.0,"events":[],"actor_tracks":[],"components":[],
        "commits":[{"at_ms":0.0,"delta":{"set":{"senses":null}}}]}]})
    actual.advance(0)
    check(actual.sequence==1 and actual.state.senses==null and var_to_bytes(actual.state)==before,"Unit: a null sensory cut preserves the actual no-disclosure canonical value")
    check(actual.spatial_effect_owners.is_empty() and actual.resource_revision==resources,"Unit: null membership invents no spatial owner or resource revision")
func run() -> void:
    var gallery=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="): gallery=argument.trim_prefix("--recording=")
    if gallery.is_empty():
        check(false,"Supply --recording= with an unchanged committed schema16 Gallery journal")
        finish();return
    var independent=Session.Journal.new()
    var opened:Dictionary=independent.open(gallery,true,false)
    check(opened.ok,"Actual Gallery opens under the current protocol: "+str(opened.get("error",{})))
    if not opened.ok:finish();return
    peer = Peer.new(); check(peer.start("bounded"),"Native loopback peer starts")
    var directory = "user://checks/bounded-"+Session.uuid()
    session = Session.new()
    check(session.start({"journal":directory,"url":"http://127.0.0.1:"+str(peer.port),"token":"test"}).ok,"Live session starts")
    await until(func():return session.terminal or not session.issue.is_empty(),"Durable follower reaches final source cursor while display is paused")
    check(session.issue.is_empty() and session.latest_sequence==8 and session.journal.cursor.sequence==8,"All eight source operations are durable independently of display")
    check(peer.acks==range(9),"Every admitted source cursor is ACKed despite full display lookahead")
    await until(func():return session.diagnostics().prepared_sequence>=1,"Bounded initial display window prepares")
    var paused = session.diagnostics()
    check(paused.prepared_sequence==1 and paused.prepared_messages<=2 and paused.admitted_handoff<=3,"Paused display retains only its two-operation preparation window")
    var timeline = Timeline.new(); timeline.paused = true
    timeline.retire_group = session.retire_group
    for message in session.take_prepared(): timeline.accept(message)
    check(timeline.sequence==0,"Preparing later operations never changes displayed initialization")
    check(timeline.state.senses==null and timeline.spatial_effect_owners.is_empty(),"Legal current loopback initialization preserves undisclosed senses=null with no spatial owners")
    var deadline = Time.get_ticks_msec()+20000
    timeline.paused = false
    while timeline.sequence<8 and session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        session.set_displayed_sequence(timeline.sequence)
        for message in session.take_prepared(): timeline.accept(message)
        timeline.advance(1000)
        await process_frame
    check(timeline.sequence==8 and timeline.state==session.journal.state,"Resumed display consumes every durable operation and matches canonical reduction")
    null_senses_cut(timeline.state)
    check(timeline.completed_group_count==8,"No operation-end presentation group is omitted or duplicated")
    await until(func():return session.diagnostics().retired_groups==8,"Completed loopback groups return to the existing preparation worker")
    check(session.diagnostics().retirement_peak_groups<=2 and session.diagnostics().retirement_pending_groups==0,"One-group operations retain at most the bounded prepared window during retirement")
    evidence.live = session.diagnostics()
    check(evidence.live.disk_reloads>0 and evidence.live.handoff_hits>0,"Both admitted handoff and durable overflow paths are exercised")
    check(evidence.live.recorded_handoff_hits>0,"Live bounded handoff compiles already captured records")
    session.close(); session = null; peer.close(); peer=null
    timeline.retire_group = Callable()
    # Full replay remains bounded until displayed feedback, even with all files
    # already present. Cancellation wakes a preparer waiting on that boundary.
    session = Session.new(); check(session.open_recording(directory).ok,"Open retained complete source recording")
    await until(func():return session.recording_ready,"Recording initialization becomes ready")
    await until(func():return session.diagnostics().held_for_display,"Replay reaches bounded lookahead wait")
    check(not session.terminal and session.latest_sequence==8,"Indexed source end is distinct from completely prepared replay")
    var before = Time.get_ticks_msec(); session.close()
    evidence.close_ms = Time.get_ticks_msec()-before
    check(evidence.close_ms<1000,"Close wakes a buffer-full replay without processing the remaining journal")
    check(session.diagnostics().prepared_sequence==1,"Cancellation does not compile the unseen remaining six operations")
    session=null
    # Keep retained diagnostic totals exact without retaining every historic row.
    var groups: Array = []
    for i in range(2100): groups.append({"id":str(i),"operation_sequence":i,"operation_end":true,"duration_ms":0.0,"commits":[],"events":[]})
    timeline.accept({"kind":"operation","groups":groups,"skipped":range(2100)})
    timeline.advance(1)
    check(timeline.completed_groups.size()==2000 and timeline.completed_group_count==2108,"Completed diagnostic ring is bounded with an exact lifetime total")
    check(timeline.skipped.size()==2000 and timeline.skipped_count==2100,"Skipped diagnostic ring is bounded without changing displayed delivery")
    # Strict offline record admission still checks identity and cursor scope.
    for field in ["schema_digest","audience_id"]:
        var original = FileAccess.get_file_as_bytes(directory.path_join("0000000000000001.json"))
        var parser = Session.Protocol.new()
        var packet: Dictionary = parser.decode("PlayerOperation",original).value
        if field=="schema_digest": packet.protocol[field]="f".repeat(64)
        else: packet.cursor[field]="00000000-0000-4000-8000-000000000099"
        FileAccess.open(directory.path_join("0000000000000001.json"),FileAccess.WRITE).store_string(JSON.stringify(packet))
        session=Session.new(); session.open_recording(directory)
        await until(func():return not session.issue.is_empty(),"Offline replay rejects changed "+field)
        check(session.diagnostics().prepared_sequence==0,"Rejected record never enters presentation: "+field)
        session.close(); session=null
        FileAccess.open(directory.path_join("0000000000000001.json"),FileAccess.WRITE).store_buffer(original)
    for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
    DirAccess.remove_absolute(directory)
    # Unchanged committed Gallery originals exercise non-empty native lineages,
    # actual actor motion/reveal and item/condition after-values through the same
    # bounded worker. The malformed records above belong only to the private
    # loopback journal; this original directory is never rewritten by the test.
    var last_recorded_sequence=-1
    var record_name=RegEx.new(); record_name.compile("^[0-9]{16}\\.json$")
    for filename in DirAccess.get_files_at(gallery):
        if record_name.search(filename)!=null: last_recorded_sequence=maxi(last_recorded_sequence,filename.trim_suffix(".json").to_int())
    check(last_recorded_sequence>1,"Actual Gallery contains a complete multi-operation original prefix")
    session=Session.new()
    check(session.open_recording(gallery).ok,"Actual Gallery replay worker starts")
    if not await until(func():return session.recording_ready or not session.issue.is_empty(),"Actual Gallery initialization prepares"):
        finish();return
    check(session.issue.is_empty(),"Actual Gallery initialization has no reader/compiler failure: "+str(session.issue))
    if not session.issue.is_empty():finish();return
    var actual=Timeline.new()
    actual.retire_group=session.retire_group
    deadline=Time.get_ticks_msec()+120000
    while (actual.sequence<session.latest_sequence or not session.terminal) and session.issue.is_empty() and Time.get_ticks_msec()<deadline:
        for message in session.take_prepared(): actual.accept(message)
        actual.advance(1000000)
        session.set_displayed_sequence(actual.sequence)
        await process_frame
    check(session.issue.is_empty() and actual.sequence==last_recorded_sequence and session.terminal,"All authentic Gallery packets reach display, despite bounded lookahead")
    var replayed=independent.replay()
    check(replayed.ok and actual.state==independent.state,"Bounded real Gallery display matches independently replayed durable journal")
    check(session.diagnostics().recorded_handoff_hits==last_recorded_sequence,"Offline replay captures once per operation and hands records to the compiler")
    evidence.gallery={"sequence":actual.sequence,"completed_groups":actual.completed_group_count,"execution":session.diagnostics()}
    session.close()
    check(session.diagnostics().retired_groups==actual.completed_group_count and session.diagnostics().retirement_pending_groups==0,"Close drains every completed real Gallery group including staged last-frame retirement")
    evidence.gallery.retirement_after_close=session.diagnostics()
    session=null
    session=Session.new(); session.open_recording(gallery)
    await until(func():return session.diagnostics().active,"Real recording enters an atomic decode/compile")
    before=Time.get_ticks_msec(); session.close()
    evidence.active_close_ms=Time.get_ticks_msec()-before
    check(session.diagnostics().prepared_sequence<last_recorded_sequence and evidence.active_close_ms<5000,"Cancellation waits at most the active packet, never the rest of the recording")
    session=null
    finish()
func finish() -> void:
    if session!=null:session.close();session=null
    if peer!=null:peer.close();peer=null
    var report={"checks":checks,"failures":failures,"evidence":evidence}
    FileAccess.open("res://generated/session_execution_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SESSION_EXECUTION_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
