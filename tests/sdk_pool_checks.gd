extends "res://tests/sdk_transport_checks.gd"
# Real native HTTPClient sockets. Keep-alive responses deliberately omit an
# advertised close, then the peer expires an idle socket before the next POST.
class KeepAlivePeer extends "res://tests/sdk_transport_peer.gd":
    var served_connections: Dictionary = {}
    var idle_closes = 0
    func _response(connection: Dictionary, value: Dictionary, code: int = 200, extras: String = "") -> void:
        var body=JSON.stringify(value).to_utf8_buffer()
        var bytes=("HTTP/1.1 "+str(code)+" Test\r\nContent-Type: application/json\r\nContent-Length: "+str(body.size())+"\r\nConnection: keep-alive\r\n"+extras+"\r\n").to_utf8_buffer()
        bytes.append_array(body); connection.peer.put_data(bytes)
        connection.raw=PackedByteArray(); connection.done=false; connection.close_at=0
    func _serve(connection: Dictionary, path: String, body: Variant) -> void:
        served_connections[connection.peer.get_instance_id()]=true
        super._serve(connection,path,body)
    func expire_idle() -> void:
        for connection in peers:
            if connection.raw.is_empty():
                connection.peer.disconnect_from_host(); idle_closes+=1

func start_pool(mode: String) -> void:
    notices=[]; responses={}; connected=null; terminal=null
    peer=KeepAlivePeer.new(); check(peer.start(mode),"Native keep-alive peer starts")
    consumer=Consumer.new(); transport=Transport.new()
    check(transport.set_profiling(true).ok,"Enable payload-free socket diagnostics")
    check(transport.start("http://127.0.0.1:"+str(peer.port),"test",consumer.consume,
        {"request_timeout":2.0,"stream_idle_timeout":2.0,"reconnect_timeout":2.0}).ok,"Native transport worker starts")
    await _until("connected")
    check(connected!=null and connected.ok,"Native bootstrap completes")
    check((await _request("attach",{"acquisition_id":Peer.UUID,"expected_attachment_epoch":Peer.UUID})).ok,"Native attachment completes")
    check(peer.served_connections.size()==1,"Bootstrap and attachment reuse one healthy keep-alive connection")

func command_trace(profile: Dictionary) -> Array:
    return profile.records.filter(func(record):return record.get("operation")=="submit_command")

func _run() -> void:
    var command={"command_number":37,"actor_uuid":Peer.UUID,"state_revision":"r","intent":{"kind":"end_turn"}}
    var evidence: Array=[]
    await start_pool("keep_alive")
    peer.expire_idle()
    # The worker never polls idle clients; the close is observed by the first
    # poll of the next job, before request_raw is invoked on that stale socket.
    await create_timer(0.05).timeout
    check(peer.idle_closes==1,"Peer actually closed the idle socket without Connection: close")
    var delivered=await _request("submit_command",command)
    check(delivered.ok and delivered.value.receipt.command_number==37,"Fresh connection delivers the same numbered POST")
    check(peer.command_posts==1 and peer.served_connections.size()==2,"Expired idle socket is replaced and command reaches server exactly once")
    var profile: Dictionary=transport.drain_profile()
    var records=command_trace(profile)
    var created=records.filter(func(record):return record.stage=="http_created")
    var replaced=records.filter(func(record):return record.stage=="connection_replaced")
    var sends=records.filter(func(record):return record.stage=="request_sent")
    var ended=records.filter(func(record):return record.stage=="http_end")
    check(profile.dropped==0 and created.size()==1 and created[0].reused_connected,"One original command job started from a connected pooled socket")
    check(replaced.size()==1 and sends.size()==1 and sends[0].ok and replaced[0].time_us<sends[0].started_us,"One replacement precedes the only request_raw invocation")
    check(ended.size()==1 and ended[0].ok and ended[0].connection_replaced and ended[0].request_attempted and ended[0].sent,"Completion retains exact pre-send replacement evidence")
    evidence.append({"case":"idle_expiry","command_posts":peer.command_posts,"connections":peer.served_connections.size(),"events":records})
    _stop()

    await start_pool("command_loss")
    var lost=await _request("submit_command",command)
    check(not lost.ok and lost.error.kind=="transport","Server receives POST then loses reply")
    # Allow the worker to keep running: it must not replay this possibly
    # committed operation. Only the ordinary explicit receipt lookup follows.
    await create_timer(0.05).timeout
    check(peer.command_posts==1,"Possibly sent numbered POST is never retried")
    var receipt=await _request("receipt",{"number":37})
    check(receipt.ok and receipt.value.receipt.command_number==37,"Existing explicit receipt recovery stays available")
    profile=transport.drain_profile(); records=command_trace(profile)
    sends=records.filter(func(record):return record.stage=="request_sent")
    replaced=records.filter(func(record):return record.stage=="connection_replaced")
    ended=records.filter(func(record):return record.stage=="http_end")
    check(profile.dropped==0 and sends.size()==1 and sends[0].ok and replaced.is_empty(),"Reply loss does not replace or resend after request_raw")
    check(ended.size()==1 and not ended[0].ok and ended[0].request_attempted and ended[0].sent and not ended[0].connection_replaced,"Ambiguous-send diagnostic is distinct from stale idle recovery")
    check(peer.command_posts==1,"Receipt recovery does not create a second command")
    evidence.append({"case":"reply_loss","command_posts":peer.command_posts,"connections":peer.served_connections.size(),"events":records})
    _stop()
    # Diagnostic schema deliberately contains no address, request body or auth.
    var allowed=["stage","time_us","http_id","request_id","operation","purpose","schema","reused_connected",
        "reason","native_error","native_state","started_us","request_bytes","ok","declared_bytes","status","bytes",
        "phase","sent","request_attempted","connection_replaced","transport_reason","failure_kind"]
    for row in evidence:
        check(row.events.all(func(record):return record.keys().all(func(key):return key in allowed)),row.case+" diagnostic fields contain only labels, counts, phases and timing")
    var report={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Native local TCP: hidden keep-alive expiry before request_raw replaces once and POST arrives once; received POST with dropped reply never resends, explicit receipt recovery retained. No backend or GPU."}
    FileAccess.open("res://generated/sdk_pool_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SDK_POOL_CHECKS ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
