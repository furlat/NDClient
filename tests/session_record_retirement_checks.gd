extends SceneTree
# Real transport envelopes from the finite HTTP peer exercise caller-visible
# ownership and shutdown. No native resources enter the passive cleanup queue.
const Session = preload("res://presentation/session.gd")
const Peer = preload("res://tests/sdk_transport_peer.gd")
const Player = preload("res://play.gd")
var session: RefCounted
var peer: RefCounted
var checks := 0
var failures: Array = []
func check(value: bool,label: String) -> void:
    checks+=1
    if not value: failures.append(label);print("RECORD_RETIREMENT_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
    if peer!=null: peer.tick()
    return false
func until(predicate: Callable,label: String) -> void:
    var deadline=Time.get_ticks_msec()+20000
    while not predicate.call() and Time.get_ticks_msec()<deadline:
        session.poll()
        await process_frame
    check(predicate.call(),label)
func run() -> void:
    var absent=Session.new()
    var untouched={"nested":{"values":[1,2,3]}}
    absent.retire_record(untouched)
    check(absent.diagnostics().retirement_pending_records==0 and absent.prepare_thread==null,"Cleanup without an active preparer neither retains records nor starts a worker")
    absent.close()
    peer=Peer.new();check(peer.start("bounded"),"Native finite transport peer starts")
    session=Session.new()
    var directory="user://checks/record-retirement-"+Session.uuid()
    check(session.start({"journal":directory,"url":"http://127.0.0.1:"+str(peer.port),"token":"test"}).ok,"Session starts through its public transport boundary")
    await until(func():return session.terminal and session.diagnostics().prepared_sequence>=1,"Durable source and bounded preparation become ready")
    var id=session.request("choices",{"actor_uuid":Peer.UUID,"state_revision":"r","force_attack":false,"correlation_id":Peer.UUID})
    await until(func():return session.responses.has(id),"Actual admitted choices response arrives")
    var response: Dictionary=session.responses[id]
    session.responses.erase(id)
    check(response.ok and not response.has("normalized"),"Choices expose one admitted sparse record")
    var original=response.duplicate(true)
    session.retire_record(response)
    check(session.diagnostics().retired_records==0 and session.diagnostics().retirement_pending_records==1,"Retirement stays staged until the next scene poll")
    await until(func():return session.diagnostics().retired_records==1,"Existing preparer releases its staged record reference")
    check(response==original and response.value==original.value,"Worker cleanup leaves caller-held admitted tables intact")
    check(session.diagnostics().retired_groups==0 and session.diagnostics().retirement_pending_records==0,"Record cleanup does not change presentation-group totals")

    var player=Player.new()
    player.session=session
    var old: Dictionary=response.value.choices.duplicate(true)
    player.available_actions=old
    var boundary={"state_revision":session.status.boundary.state_revision,
        "actor_uuid":session.status.boundary.input_actor_uuid,"sequence":int(session.status.catch_up_cursor.sequence)}
    for field in ["game_id","game_epoch","audience_id","attachment_epoch"]: boundary[field]=session.status[field]
    player.action_request=1001
    player.pending_request={"kind":"choices","force_attack":false,"revision":"r","boundary":boundary}
    session.responses[1001]=response
    player._poll_actions()
    check(is_same(player.pending_choices.value,response.value) and is_same(player.available_actions,old) and player.action_request==-1,"Private prefetch borrows admitted tables while displayed choices remain owned")
    check(session.diagnostics().retirement_pending_records==1,"Choices consumption stages its envelope without retiring displayed choices early")
    player.action_request=1002
    var obsolete=boundary.duplicate();obsolete.state_revision="obsolete"
    player.pending_request={"kind":"choices","force_attack":false,"revision":"obsolete","boundary":obsolete}
    session.responses[1002]=response
    player._poll_actions()
    check(player.available_actions==original.value.choices and player.action_revision.is_empty(),"Stale choices are rejected before replacing the displayed generation")
    check(session.diagnostics().retirement_pending_records==2,"Stale response references also enter deferred cleanup")
    var error=Session.Transport.failure("transport","finite retryable fixture",true)
    player.action_request=1003;player.command_busy=true
    player.pending_request={"kind":"command","number":9}
    session.responses[1003]=error
    player._poll_actions()
    check(player.command_busy and player.pending_request=={"kind":"receipt","number":9},"Failed command retains its original receipt lookup and input hold")
    check(session.diagnostics().retirement_pending_records==3,"Error responses enter the same passive cleanup")
    player.hover_request=1004;player.hover_due=Time.get_ticks_msec()+100000
    player.hover_context={"key":["old"]};player.hover_key=["new"]
    session.responses[1004]={"ok":true,"value":{"preview":{"can_confirm":false}}}
    player._update_hover()
    check(player.hover_request==-1 and player.hover_preview.is_empty(),"Stale hover replies never become visible")
    check(session.diagnostics().retirement_pending_records==4,"Hover envelopes are retained for worker cleanup")
    player.context_menu.free();player.free()
    session.close()
    var final=session.diagnostics()
    check(final.retired_records==5 and final.retirement_pending_records==0,"Close drains the final scene's records before joining the existing worker")
    check(final.retired_groups==0 and response==original and old==original.value.choices,"Close preserves exact group counts and all still-owned source data")
    session.retire_record(untouched)
    check(session.diagnostics().retirement_pending_records==0,"Cancelled sessions do not retain new cleanup records")
    check(session.issue.is_empty(),"Transport and preparation report no failure")
    peer.close();peer=null
    for name in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(name))
    DirAccess.remove_absolute(directory)
    FileAccess.open("res://generated/session_record_retirement_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"diagnostics":final},"  "))
    print("RECORD_RETIREMENT_CHECKS ",checks," failures=",failures)
    quit(0 if failures.is_empty() else 1)
