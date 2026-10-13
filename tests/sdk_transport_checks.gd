extends SceneTree
const Transport = preload("res://sdk/transport.gd")
const SSE = preload("res://sdk/sse.gd")
const Peer = preload("res://tests/sdk_transport_peer.gd")
const Protocol = preload("res://sdk/protocol.gd")
var checks = 0
var failures: Array = []
var peer: RefCounted
var transport: RefCounted
var consumer: RefCounted
var notices: Array = []
var responses: Dictionary = {}
var connected: Variant = null
var terminal: Variant = null
var started = Time.get_ticks_msec()

class Consumer extends RefCounted:
    var reject = false
    var block = false
    var gate = Semaphore.new()
    var entered = false
    var mutex = Mutex.new()
    var seen: Array = []
    var thread_ids: Array = []
    func consume(packet: Dictionary, raw: PackedByteArray) -> Dictionary:
        thread_ids.append(OS.get_thread_caller_id())
        if Protocol.parse_json(raw).value != packet:
            return Transport.failure("protocol","Raw record does not match admission")
        if block and packet.cursor.sequence == 1:
            mutex.lock(); entered = true; mutex.unlock()
            gate.wait()
        if reject and packet.cursor.sequence == 1: return Transport.failure("protocol","Consumer refused record")
        seen.append(packet.cursor.sequence)
        return Transport.success()
    func is_entered() -> bool:
        mutex.lock(); var value = entered; mutex.unlock(); return value

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition: failures.append(label); print("FAIL: "+label)

func _init() -> void: _run.call_deferred()

func _process(_delta: float) -> bool:
    if peer != null: peer.tick()
    if transport != null:
        for notice in transport.drain():
            notices.append(notice)
            if notice.kind == "connected": connected = notice.result
            if notice.kind in ["failure","completed"]: terminal = notice
            if notice.kind == "response": responses[notice.request_id] = notice.result
    return false

func _until(which: String, id: int = -1) -> bool:
    var deadline = Time.get_ticks_msec()+5000
    while Time.get_ticks_msec() < deadline:
        if which == "connected" and (connected != null or terminal != null): return true
        if which == "terminal" and terminal != null: return true
        if which == "response" and responses.has(id): return true
        if which == "stream" and peer.resumes.size() > 0: return true
        await process_frame
    check(false,"Timed out waiting for "+which+" in "+peer.mode)
    return false

func _request(operation: String, arguments: Dictionary = {}) -> Dictionary:
    var id: int = transport.request(operation,arguments)
    if not await _until("response",id): return Transport.failure("transport","Test timed out")
    var value: Dictionary = responses[id]; responses.erase(id)
    if "--diagnostic" in OS.get_cmdline_user_args(): print("TRANSPORT_TRACE ",peer.mode," ",operation," ",JSON.stringify(value))
    return value

func _start(mode: String, attach: bool = true) -> void:
    notices = []; responses = {}; connected = null; terminal = null
    peer = Peer.new(); check(peer.start(mode),"Loopback server starts")
    consumer = Consumer.new(); consumer.reject = mode == "consumer_failure"
    consumer.block = mode == "cancel_consumer"
    transport = Transport.new()
    check(transport.start("http://127.0.0.1:"+str(peer.port),"test",consumer.consume,{"request_timeout":2.0,"stream_idle_timeout":2.0,"reconnect_timeout":2.0}).ok,"Worker starts")
    await _until("connected")
    if attach and connected != null:
        var result = await _request("attach",{"acquisition_id":Peer.UUID,"expected_attachment_epoch":Peer.UUID})
        check(result.ok,"Attachment succeeds "+mode)

func _stop() -> Array:
    transport.close()
    var seen: Array = consumer.seen.duplicate()
    for thread_id in consumer.thread_ids: check(thread_id != OS.get_thread_caller_id(),"Consumer executes off main thread")
    check(not transport.is_running(),"Worker joined")
    peer.close(); peer = null; transport = null; consumer = null
    return seen

func _parser_checks() -> void:
    var parser = SSE.new()
    var records: Array = []
    for byte in (": comment\r\nevent: operation\r\nid: 1\r\ndata: {\"name\":\r\ndata: \"é😀\"}\r\n\r\ndata: unfinished").to_utf8_buffer():
        var result = parser.feed(PackedByteArray([byte]))
        check(result.ok,"Byte-split UTF-8/CRLF accepted")
        if result.ok: records.append_array(result.value)
    check(records.size()==1 and records[0].event=="operation" and records[0].id=="1" and records[0].raw.get_string_from_utf8()=="{\"name\":\n\"é😀\"}","SSE exact multiline record")
    check(parser.finish().value.is_empty(),"Unterminated EOF discarded")
    parser = SSE.new()
    check(parser.feed("event: operation\rid: 1\rdata: {}\r\r".to_utf8_buffer()).value.size()==1,"CR-only blank delimiter")
    parser = SSE.new()
    check(not parser.feed(PackedByteArray([100,97,116,97,58,255,10,10])).ok,"Invalid UTF-8 rejected")
    parser = SSE.new(null,16)
    check(not parser.feed("a".repeat(1041).to_utf8_buffer()).ok,"Unfinished record capped")
    parser = SSE.new()
    check(parser.feed((char(0xfeff)+"data: {}\n\n").to_utf8_buffer()).value.size()==1,"Initial UTF-8 BOM accepted")
    var protocol = Protocol.new()
    var identity_raw = JSON.stringify(protocol.identity).to_utf8_buffer()
    var nul_raw = identity_raw.duplicate();nul_raw.append(0)
    for raw in [identity_raw,identity_raw.slice(0,identity_raw.size()-1),nul_raw]:
        parser=SSE.new(protocol)
        var framed="data: ".to_utf8_buffer();framed.append_array(raw);framed.append_array("\n\n".to_utf8_buffer())
        var record=parser.feed(framed)
        check(record.ok and record.value.size()==1,"SSE retains exact complete payload before JSON admission")
        if not record.ok or record.value.size()!=1:continue
        var public_result=protocol.decode("ProtocolIdentity",raw)
        var streamed=protocol._decode_framed_event("ProtocolIdentity",record.value[0].raw)
        check(streamed.ok==public_result.ok and (not streamed.ok or Protocol._equal(streamed.value,public_result.value)),"Stream admission preserves strict values and rejects malformed JSON/NUL")
    check(not Transport.parse_origin("https://user:pass@host").ok,"Credential URL rejected")
    check(not Transport.parse_origin("https://host/?x=1").ok,"Query URL rejected")
    check(Transport.parse_origin("https://[::1]:443/base/").value == {"host":"::1","port":443,"tls":true,"prefix":"/base"},"IPv6 and deployment prefix")
    check(Transport.retry_after_ms("2")==2000,"Retry-After seconds")
    check(Transport.retry_after_ms("999999999999999999999999999999")==5000,"Retry-After capped before integer overflow")
    check(Transport.retry_after_ms("Sun, 06 Nov 1994 08:49:37 GMT",784111774)==3000,"Retry-After HTTP date")
    check(Transport.retry_after_ms("Sun, 06 Nov 1994 08:49:37 GMT",784111780)==0,"Past Retry-After clamped")
    check(Transport.retry_after_ms("Sun, 35 Feb 1994 08:49:37 GMT")==0,"Malformed Retry-After ignored")

func _run() -> void:
    _parser_checks()
    await _start("immediate_truncated",false)
    check(terminal != null and terminal.kind=="failure" and connected==null,"Closed truncated HTTP body never becomes an admitted response")
    _stop()
    await _start("immediate_close",false)
    check(connected != null and connected.ok,"Complete HTTP body is admitted when peer closes immediately")
    _stop()
    await _start("normal")
    check((await _request("health")).ok,"Health endpoint")
    check((await _request("status")).ok,"Status endpoint")
    check((await _request("content",{"revision":"r"})).ok,"Content endpoint")
    var offered = await _request("choices",{"actor_uuid":Peer.UUID,"state_revision":"r","force_attack":false,"correlation_id":Peer.UUID})
    check(offered.ok,"Choices endpoint succeeds")
    if offered.ok:
        check(not offered.value.has("kind") and not offered.has("normalized"),"Choices stay sparse without a duplicate normalized tree")
        check(offered.value.choices.entity_uuid==Peer.UUID,"Worker publishes the admitted actor without installing defaults")
    check((await _request("preview",{"actor_uuid":Peer.UUID,"state_revision":"r","discovery_generation":1,"correlation_id":Peer.UUID,"selection":{"action_index":0,"target_indices":[1,2]}})).ok,"Preview preserves selection and defaults")
    check(not (await _request("receipt",{"number":0})).ok,"Invalid receipt rejected")
    check((await _request("follow")).ok,"Follower scheduled")
    await _until("terminal")
    check(terminal != null and terminal.kind=="completed","Final prefix completes")
    check(peer.acks==[0,1,2],"Duplicate operation not ACKed twice")
    var waited = await _request("wait_for_cursor",{"cursor":peer.cursor(1)})
    check(waited.ok,"Consumed waiter resolves")
    check(not (await _request("wait_for_cursor",{"cursor":peer.cursor(3)})).ok,"Wait beyond terminal rejects")
    check((await _request("acknowledge",{"cursor":peer.cursor(2)})).ok,"Public acknowledge endpoint")
    var native_cursor = peer.scope(); native_cursor.sequence = 2
    check((await _request("wait_for_cursor",{"cursor":native_cursor})).ok,"Native StringName dictionary keys accepted")
    var wrong_cursor = peer.cursor(2); wrong_cursor.game_id = "other"
    var prior_requests: int = peer.requests.size()
    check(not (await _request("acknowledge",{"cursor":wrong_cursor})).ok,"Reject cross-game ACK locally")
    check(peer.requests.size()==prior_requests,"Invalid ACK never sent")
    for request in peer.requests:
        check(request.headers.get("authorization")=="Bearer test","Bearer header")
        if request.path != "/api/v1/bootstrap": check(request.headers.get("x-game-epoch")==Peer.UUID,"Game epoch header")
        if request.path.ends_with("/ack"): check(not ".0" in request.raw,"ACK counters serialized as integer")
    check(_stop()==[0,1,2],"Exactly-once consumer prefix")

    for mode in ["gap","bad_id","bad_scope","bad_utf8","bad_utf8_prefix","bad_nested_scope","consumer_failure","bad_init","replaced","failed_final"]:
        await _start(mode)
        await _request("follow"); await _until("terminal")
        check(terminal != null and terminal.kind=="failure","Follower rejects "+mode)
        check(peer.resumes.size() <= 1,"Fatal error not retried "+mode)
        check(peer.acks == ([] if mode=="bad_init" else ([0,1] if mode in ["replaced","failed_final","bad_utf8_prefix"] else [0])),"ACK prefix preserved "+mode)
        var expected = [] if mode=="bad_init" else ([0,1] if mode in ["replaced","failed_final","bad_utf8_prefix"] else [0])
        check(_stop()==expected,"Consumer prefix preserved "+mode)

    for mode in ["lost_ack","partial_eof"]:
        await _start(mode); await _request("follow"); await _until("terminal")
        check(terminal != null and terminal.kind=="completed","Retry completes "+mode)
        check(peer.acks == ([0,1,1] if mode=="lost_ack" else [0,0,1]),"Resume re-ACKs durable cursor "+mode)
        check(peer.resumes == ([0,1] if mode=="lost_ack" else [0,0]),"Resume starts at consumed cursor "+mode)
        check(_stop()==[0,1],"No duplicate consumption after "+mode)

    await _start("idle"); await _request("follow"); await _until("stream")
    check((await _request("reconnect")).ok,"Explicit reconnect accepted")
    var deadline = Time.get_ticks_msec()+3000
    while peer.resumes.size()<2 and Time.get_ticks_msec()<deadline: await process_frame
    check(peer.resumes==[0,0] and peer.acks==[0,0],"Explicit reconnect retains cursor and attachment")
    check(not (await _request("wait_for_cursor",{"cursor":peer.cursor(1),"timeout":0.01})).ok,"Cursor waiter timeout")
    var waiting: int = transport.wait_for_cursor(peer.cursor(1))
    transport.cancel(); await _until("response",waiting)
    check(responses.has(waiting) and responses[waiting].error.kind=="cancelled","Cancel releases cursor waiter")
    check(_stop()==[0],"Cancel does not consume extra records")

    await _start("cancel_consumer"); await _request("follow")
    deadline = Time.get_ticks_msec()+3000
    while not consumer.is_entered() and Time.get_ticks_msec()<deadline: await process_frame
    check(consumer.is_entered(),"Worker entered gated consumer")
    check(peer.acks==[0],"Blocked consumer is not ACKed")
    transport.cancel(); consumer.gate.post()
    await _until("terminal")
    check(terminal != null and terminal.kind=="failure" and terminal.result.error.kind=="cancelled","Cancel checked after consumer returns")
    check(peer.acks==[0],"Cancelled consumer result is not ACKed")
    var consumed: Array = []
    for notice in notices:
        if notice.kind == "consumed": consumed.append(notice.value.cursor.sequence)
    check(consumed==[0],"Cancelled callback does not advance transport cursor")
    _stop()

    for mode in ["redirect","bad_bootstrap"]:
        await _start(mode,false)
        check(terminal != null and terminal.result.error.kind=="protocol","Bootstrap rejects "+mode)
        check(peer.requests.size()==1,"No redirect or identity retry")
        _stop()

    await _start("command_loss")
    var command = {"command_number":1,"actor_uuid":Peer.UUID,"state_revision":"r","intent":{"kind":"end_turn"}}
    var lost = await _request("submit_command",command)
    check(not lost.ok and lost.error.kind=="transport","Command reply loss surfaces")
    check((await _request("receipt",{"number":1})).ok,"Recover command by receipt")
    check(peer.command_posts==1,"Command is never automatically retried")
    _stop()

    for mode in ["receipt_default","receipt_default_foreign"]:
        await _start(mode)
        var response = await _request("receipt",{"number":1})
        if mode == "receipt_default":
            check(response.ok,"Committed receipt without optional kind accepted: "+str(response))
            if response.ok: check(not response.value.receipt.has("kind"),"Receipt default check preserves original packet")
        else:
            check(not response.ok and response.error.message=="Game/epoch/audience mismatch","Omitted receipt kind cannot bypass nested cursor scope")
        _stop()

    await _start("error_defaults")
    var api = await _request("health")
    check(not api.ok and api.error.kind=="api" and api.error.message=="busy" and api.error.retryable,"HTTP error optional defaults admitted")
    await _request("follow"); await _until("terminal")
    check(terminal != null and terminal.kind=="failure" and terminal.result.error.kind=="api" and terminal.result.error.message=="unauthenticated" and not terminal.result.error.retryable,"SSE error optional defaults admitted")
    check(peer.resumes.size()==1 and peer.acks==[0],"Defaulted SSE error is fatal after initialization ACK")
    _stop()

    for mode in ["bad_preview","bad_choices","wrong_content"]:
        await _start(mode)
        var response: Dictionary
        if mode == "bad_preview":
            response = await _request("preview",{"actor_uuid":Peer.UUID,"state_revision":"r","discovery_generation":1,"correlation_id":Peer.UUID,"selection":{"action_index":0,"target_indices":[1,2]}})
        elif mode == "bad_choices": response = await _request("choices",{"actor_uuid":Peer.UUID,"state_revision":"r","force_attack":false,"correlation_id":Peer.UUID})
        else: response = await _request("content",{"revision":"r"})
        check(not response.ok and response.error.kind=="protocol","Correlation rejects "+mode)
        if not response.ok:
            check(response.error.message == {"bad_preview":"Preview selection mismatch","bad_choices":"Choices correlation mismatch","wrong_content":"Content revision mismatch"}[mode],"Correlation check is reached "+mode)
        _stop()
    print(JSON.stringify({"checks":checks,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started}))
    quit(0 if failures.is_empty() else 1)
