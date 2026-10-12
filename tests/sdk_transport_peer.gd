extends RefCounted
## Loopback HTTP peer used to exercise the real native HTTPClient, not mock it.
const UUID = "00000000-0000-4000-8000-000000000001"
const Protocol = preload("res://sdk/protocol.gd")
var server = TCPServer.new()
var peers: Array = []
var mode = "normal"
var requests: Array = []
var acks: Array = []
var resumes: Array = []
var protocol: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/protocol-identity.json"))
var command_posts = 0
var port = 0

func start(test_mode: String) -> bool:
    mode = test_mode
    for candidate in range(28340,28440):
        if server.listen(candidate,"127.0.0.1") == OK:
            port = candidate
            return true
    return false

func scope() -> Dictionary: return {"game_id":"test","game_epoch":UUID,"audience_id":UUID}
func cursor(sequence: int) -> Dictionary:
    var value = scope(); value["sequence"] = sequence; return value
func boundary() -> Dictionary: return {"lifecycle":"waiting_for_human","input_actor_uuid":UUID,"state_revision":"r"}
func status(final: int = -1) -> Dictionary:
    var value = scope()
    var state = boundary()
    if final >= 0: state.lifecycle = "failed" if mode == "failed_final" else "terminal"
    value.merge({"boundary":state,"published_cursor":cursor(maxi(0,final)),"final_cursor":null if final<0 else cursor(final),"attachment_epoch":UUID,"catch_up_cursor":cursor(0),"acknowledged_cursor":null,"next_command_number":1,"pending_command_numbers":[]})
    return value
func initial() -> Dictionary:
    return {"kind":"initialization","protocol":protocol,"cursor":cursor(1 if mode=="bad_init" else 0),"content_revision":"r","content_additions":[],"initialization":{"generation":UUID,"observer_uuid":UUID,"world":{"battlefield_id":"test","battlefield_name":"é","bounds":[-1,-1,1,1],"width":3,"height":3},"nodes":[],"version_rows":[],"end_cursor":0,"observations":[],"world_updates":[]}}
func operation(sequence: int) -> Dictionary:
    return {"kind":"operation","protocol":protocol,"cursor":cursor(sequence),"state_revision":"r","command_number":null,"boundary":boundary(),"audience":{"controlled":[UUID],"observers":[UUID]},"lineages":[],"hud":null,"combat_log_appends":[],"content_additions":[]}
func event(name: String, value: Dictionary, sequence: int = -1) -> String:
    return "event: "+name+"\n"+("id: "+str(sequence)+"\n" if sequence>=0 else "")+"data: "+JSON.stringify(value)+"\n\n"
func ready(final: int, after: int) -> String:
    var state = status(final)
    if mode == "bad_nested_scope": state.final_cursor.game_id = "other"
    return event("ready",{"kind":"ready","protocol":protocol,"after":cursor(after),"head":cursor(maxi(0,final)),"status":state})
func close() -> void:
    for connection in peers: connection.peer.disconnect_from_host()
    peers.clear(); server.stop()

func tick() -> void:
    while server.is_connection_available():
        peers.append({"peer":server.take_connection(),"raw":PackedByteArray(),"done":false,"close_at":0})
    for connection in peers.duplicate():
        var peer: StreamPeerTCP = connection.peer
        peer.poll()
        if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
            peers.erase(connection); continue
        if connection.close_at > 0 and Time.get_ticks_msec() >= connection.close_at:
            peer.disconnect_from_host(); peers.erase(connection); continue
        if connection.done: continue
        var available = peer.get_available_bytes()
        if available <= 0: continue
        var received = peer.get_data(available)
        if received[0] != OK: continue
        var raw: PackedByteArray = connection.raw
        raw.append_array(received[1]); connection.raw = raw
        var text = raw.get_string_from_utf8()
        var split = text.find("\r\n\r\n")
        if split < 0: continue
        var lines = text.substr(0,split).split("\r\n")
        var headers: Dictionary = {}
        for line in lines:
            var colon = line.find(":")
            if colon >= 0: headers[line.substr(0,colon).to_lower()] = line.substr(colon+1).strip_edges()
        var content_length = int(headers.get("content-length","0"))
        var body_raw = raw.slice(split+4)
        if body_raw.size() < content_length: continue
        connection.done = true
        var body: Variant = null if content_length == 0 else Protocol.parse_json(body_raw).value
        var path = lines[0].split(" ")[1]
        requests.append({"path":path,"headers":headers,"body":body,"raw":body_raw.get_string_from_utf8()})
        _serve(connection,path,body)

func _response(connection: Dictionary, value: Dictionary, code: int = 200, extras: String = "") -> void:
    var body = JSON.stringify(value).to_utf8_buffer()
    var bytes = ("HTTP/1.1 "+str(code)+" Test\r\nContent-Type: application/json\r\nContent-Length: "+str(body.size())+"\r\nConnection: close\r\n"+extras+"\r\n").to_utf8_buffer()
    bytes.append_array(body)
    if mode=="immediate_truncated": bytes=bytes.slice(0,bytes.size()-4)
    connection.peer.put_data(bytes)
    connection.close_at = Time.get_ticks_msec()+20
    if mode in ["immediate_close","immediate_truncated"]: connection.peer.disconnect_from_host()

func _stream(connection: Dictionary, bytes: PackedByteArray, end: bool = false) -> void:
    connection.peer.put_data("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n".to_utf8_buffer())
    connection.peer.put_data(("%x\r\n" % bytes.size()).to_utf8_buffer())
    connection.peer.put_data(bytes); connection.peer.put_data("\r\n".to_utf8_buffer())
    if end:
        connection.peer.put_data("0\r\n\r\n".to_utf8_buffer())
        connection.close_at = Time.get_ticks_msec()+20

func _serve(connection: Dictionary, path: String, body: Variant) -> void:
    if path == "/api/v1/bootstrap":
        if mode == "redirect":
            _response(connection,{},302,"Location: http://127.0.0.1:1/stolen\r\n"); return
        if mode == "bad_bootstrap":
            var bad_identity = protocol.duplicate(true); bad_identity.schema_digest = "f".repeat(64)
            _response(connection,{"kind":"bootstrap","protocol":bad_identity,"status":status(),"audience":null,"encounter_name":"test","content_revision":"r"}); return
        _response(connection,{"kind":"bootstrap","protocol":protocol,"status":status(),"audience":null,"encounter_name":"test","content_revision":"r"})
    elif path.ends_with("/attachment"):
        _response(connection,{"kind":"attachment","acquisition_id":body.acquisition_id,"attachment_epoch":UUID,"status":status()})
    elif path.ends_with("/initialization"): _response(connection,initial())
    elif path.ends_with("/ack"):
        acks.append(body.cursor.sequence)
        if mode == "lost_ack" and acks.size() == 2: connection.peer.disconnect_from_host(); return
        if mode == "replaced" and body.cursor.sequence == 1:
            _response(connection,{"kind":"error","code":"attachment_replaced","http_status":409,"retryable":false},409); return
        _response(connection,{"kind":"ack","cursor":body.cursor,"catch_up_cursor":cursor(0)})
    elif "/events?" in path:
        var after = path.get_slice("after=",1).to_int(); resumes.append(after)
        if mode == "error_defaults":
            _stream(connection,event("error",{"http_status":401}).to_utf8_buffer()); return
        var final = -1 if mode in ["idle","gap","bad_id","bad_scope","bad_utf8","bad_utf8_prefix","consumer_failure","cancel_consumer"] else (8 if mode=="bounded" else (2 if mode=="normal" else 1))
        var text = ready(final,after)
        if mode == "bad_utf8":
            var bytes = text.to_utf8_buffer(); bytes.append_array(PackedByteArray([100,97,116,97,58,32,255,10,10])); _stream(connection,bytes); return
        if mode == "bad_utf8_prefix":
            var bytes = (text+event("operation",operation(1),1)).to_utf8_buffer(); bytes.append_array(PackedByteArray([100,97,116,97,58,32,255,10,10])); _stream(connection,bytes); return
        if mode == "gap": text += event("operation",operation(2),2)
        elif mode == "bad_id": text += event("operation",operation(1),2)
        elif mode == "bad_scope":
            var bad = operation(1); bad.cursor.game_id = "other"; text += event("operation",bad,1)
        elif mode == "bounded":
            for sequence in range(after+1,9): text += event("operation",operation(sequence),sequence)
        elif mode != "idle" and after == 0:
            text += event("operation",operation(1),1)
            if mode == "normal": text += event("operation",operation(1),1)+event("operation",operation(2),2)
        if mode == "partial_eof" and resumes.size() == 1: text = text.trim_suffix("\n")
        _stream(connection,text.to_utf8_buffer(),mode=="partial_eof")
    elif path == "/health":
        if mode == "error_defaults": _response(connection,{"http_status":429},429)
        else: _response(connection,{"kind":"health","status":"ok"})
    elif path.ends_with("/status"): _response(connection,{"kind":"status","status":status()})
    elif path.begins_with("/api/v1/content/"): _response(connection,{"kind":"content","revision":"wrong" if mode=="wrong_content" else "r","descriptors":[]})
    elif path.ends_with("/commands"):
        command_posts += 1
        if mode == "command_loss": connection.peer.disconnect_from_host(); return
        var receipt = scope(); receipt.merge({"kind":"committed","command_number":body.command_number,"cursor":cursor(1)})
        _response(connection,{"kind":"receipt","receipt":receipt})
    elif "/commands/" in path:
        var receipt = scope(); receipt.merge({"kind":"committed","command_number":int(path.get_slice("/commands/",1)),"cursor":cursor(1)})
        if mode in ["receipt_default","receipt_default_foreign"]: receipt.erase("kind")
        if mode == "receipt_default_foreign": receipt.cursor.game_id = "other"
        _response(connection,{"kind":"receipt","receipt":receipt})
    elif path.ends_with("/preview"):
        var echoed = body.duplicate(true)
        if mode == "bad_preview": echoed.selection.target_indices.reverse()
        var value = scope(); value.merge({"kind":"preview","state_revision":"r","request":echoed,"preview":{"can_confirm":true}})
        _response(connection,value)
    elif path.ends_with("/choices"):
        var value = scope(); value.merge({"kind":"choices","state_revision":"r","force_attack":false,"correlation_id":body.correlation_id,"choices":{"entity_uuid":"00000000-0000-4000-8000-000000000002" if mode=="bad_choices" else UUID}})
        _response(connection,value)
