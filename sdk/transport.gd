extends RefCounted
# One worker owns HTTP clients, admission, and the passive consumer. The main
# thread only submits requests and drains immutable completion records.
const Protocol = preload("res://sdk/protocol.gd")
const SSE = preload("res://sdk/sse.gd")
const MAX_BYTES = 64 * 1024 * 1024
const MAX_SAFE_INTEGER = 9007199254740991
var _thread = Thread.new()
var _mutex = Mutex.new()
var _incoming: Array = []
var _outgoing: Array = []
var _cancelled = false
var _running = false
var _serial = 0
var _diagnostics: Dictionary = {}
var _timings = {"completed_requests":0,"request_wall_ms":0.0,"maximum_request_wall_ms":0.0,
    "admission_ms":0.0,"consumer_ms":0.0,"response_normalization_ms":0.0}
var _consumer: Callable
var _options: Dictionary
var _origin: Dictionary
var _credential = ""
# Everything below is owned exclusively by the worker after start().
var _protocol: RefCounted
var _bootstrap: Dictionary = {}
var _attachment: Dictionary = {}
var _jobs: Array = []
var _idle_clients: Array = []
var _waiters: Array = []
var _stream: Dictionary = {}
var _parser: RefCounted
var _events: Array = []
var _framing_failure: Dictionary = {}
var _follower: Dictionary = {"started":false,"running":false,"consumed":null,
    "status":null,"completed":false,"failure":{},"phase":"idle",
    "retry_since":-1,"retry_at":0,"attempt":0}

static func success(value: Variant = null) -> Dictionary:
    return {"ok":true,"value":value}

static func failure(kind: String, message: String, retryable: bool = false) -> Dictionary:
    return {"ok":false,"error":{"kind":kind,"message":message,"retryable":retryable}}

static func parse_origin(url: String) -> Dictionary:
    # Preserve an optional deployment path, including IPv6 literals and ports.
    var pattern = RegEx.new()
    pattern.compile("^(https?)://(\\[[^\\]]+\\]|[^/:?#@]+)(?::([0-9]+))?(/[^?#]*)?$")
    var found = pattern.search(url)
    if found == null: return failure("protocol","Expected an HTTP(S) base URL without credentials, query or fragment")
    var secure = found.get_string(1) == "https"
    var port = (443 if secure else 80) if found.get_string(3).is_empty() else found.get_string(3).to_int()
    if port < 1 or port > 65535: return failure("protocol","Invalid HTTP port")
    var host = found.get_string(2)
    if host.begins_with("["): host = host.substr(1,host.length()-2)
    return success({"host":host,"port":port,"tls":secure,"prefix":found.get_string(4).trim_suffix("/")})

func start(base_url: String, credential: String, consumer: Callable = Callable(), options: Dictionary = {}) -> Dictionary:
    if _thread.is_started() or _protocol != null: return failure("protocol","Transport already started")
    var parsed = parse_origin(base_url)
    if not parsed.ok: return parsed
    if credential.is_empty() or "\r" in credential or "\n" in credential:
        return failure("protocol","Invalid bearer credential")
    _origin = parsed.value; _credential = credential; _consumer = consumer
    _options = {"request_timeout":30.0,"stream_idle_timeout":45.0,"reconnect_timeout":60.0,"max_requests":8}
    for key in options:
        if not _options.has(key): return failure("protocol","Unknown transport option: "+str(key))
        if typeof(options[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(options[key])) or float(options[key]) <= 0:
            return failure("protocol","Transport options must be finite and positive")
    if options.has("max_requests") and (int(options.max_requests) != options.max_requests or options.max_requests > 64):
        return failure("protocol","max_requests must be an integer from 1 to 64")
    _options.merge(options,true)
    _mutex.lock(); _running = true; _cancelled = false; _mutex.unlock()
    var error = _thread.start(_run)
    if error != OK:
        _mutex.lock(); _running = false; _mutex.unlock()
        return failure("transport","Could not start SDK worker")
    return success()

func request(operation: String, arguments: Dictionary = {}) -> int:
    _mutex.lock()
    _serial += 1
    var id = _serial
    if not _running or _cancelled:
        _outgoing.append({"kind":"response","request_id":id,"operation":operation,
            "result":failure("cancelled","Transport is not running")})
    elif _incoming.size() >= 64:
        _outgoing.append({"kind":"response","request_id":id,"operation":operation,
            "result":failure("transport","SDK request queue is full",true)})
    else:
        _incoming.append({"id":id,"operation":operation,"arguments":arguments.duplicate(true)})
    _mutex.unlock()
    return id

func follow() -> int: return request("follow")
func reconnect() -> int: return request("reconnect")
func wait_for_cursor(cursor: Dictionary, timeout_seconds: float = 30.0) -> int:
    return request("wait_for_cursor",{"cursor":cursor,"timeout":timeout_seconds})

func drain() -> Array:
    _mutex.lock()
    var result = _outgoing
    _outgoing = []
    _mutex.unlock()
    return result

func diagnostics() -> Dictionary:
    _mutex.lock(); var value = _diagnostics.duplicate(); _mutex.unlock()
    return value

func _publish_diagnostics() -> void:
    var oldest = 0
    var commands = 0
    for job in _jobs:
        oldest = maxi(oldest,Time.get_ticks_msec()-int(job.started))
        if job.command.get("operation") == "submit_command": commands += 1
    var value = _timings.duplicate()
    value.merge({"active_requests":_jobs.size(),"oldest_request_ms":oldest,"commands_waiting":commands,
        "follower_phase":_follower.phase})
    _mutex.lock()
    value.queued_requests = _incoming.size()
    value.pending_notices = _outgoing.size()
    _diagnostics = value
    _mutex.unlock()

func is_running() -> bool:
    _mutex.lock(); var result = _running; _mutex.unlock()
    return result

func cancel() -> void:
    _mutex.lock(); _cancelled = true; _mutex.unlock()

func close() -> void:
    cancel()
    # Never join while holding the mailbox mutex.
    if _thread.is_started(): _thread.wait_to_finish()

func _stopping() -> bool:
    _mutex.lock(); var result = _cancelled; _mutex.unlock()
    return result

func _emit(value: Dictionary) -> void:
    # Payloads can contain thousands of legal targets. Copy on the worker
    # before taking the mailbox lock; draining must never wait for that copy.
    var publication = value.duplicate(true)
    _mutex.lock(); _outgoing.append(publication); _mutex.unlock()

func _reply(command: Dictionary, result: Dictionary) -> void:
    _emit({"kind":"response","request_id":command.id,"operation":command.operation,"result":result})

func _take_requests() -> Array:
    _mutex.lock(); var result = _incoming; _incoming = []; _mutex.unlock()
    return result

func _scope(value: Dictionary) -> Dictionary:
    for field in ["game_id","game_epoch","audience_id"]:
        if value.get(field) != _bootstrap.status[field]: return failure("protocol","Game/epoch/audience mismatch")
    return success()

func _status(value: Dictionary) -> Dictionary:
    var checked = _scope(value)
    if not checked.ok: return checked
    for field in ["published_cursor","final_cursor","catch_up_cursor","acknowledged_cursor"]:
        if value.get(field) != null:
            checked = _scope(value[field])
            if not checked.ok: return checked
    return success()

func _route(suffix: String) -> String:
    return "/api/v1/games/" + String(_bootstrap.status.game_id).uri_encode() + "/" + suffix

func _headers(has_body: bool = false) -> PackedStringArray:
    var result = PackedStringArray(["Authorization: Bearer "+_credential,"Accept-Encoding: identity"])
    if not _bootstrap.is_empty():
        result.append("X-Game-Epoch: "+_bootstrap.status.game_epoch)
        result.append("X-Audience-Id: "+_bootstrap.status.audience_id)
    if not _attachment.is_empty(): result.append("X-Attachment-Epoch: "+_attachment.attachment_epoch)
    if has_body: result.append("Content-Type: application/json")
    return result

func _new_job(method: int, path: String, root_name: String, body: Variant,
        purpose: String, command: Dictionary = {}) -> Dictionary:
    var client: HTTPClient = HTTPClient.new() if _idle_clients.is_empty() else _idle_clients.pop_back()
    var job = {"client":client,"method":method,"path":_origin.prefix+path,"root":root_name,
        "body":body,"purpose":purpose,"command":command,"raw":PackedByteArray(),
        "started":Time.get_ticks_msec(),"last_byte":Time.get_ticks_msec(),"phase":"connect",
        "headers":{},"code":0,"sent":false}
    client.blocking_mode_enabled = false
    client.read_chunk_size = 65536
    if client.get_status() != HTTPClient.STATUS_CONNECTED:
        client.close()
        var connected = client.connect_to_host(_origin.host,_origin.port,TLSOptions.client() if _origin.tls else null)
        if connected != OK: job.immediate = failure("transport","HTTP connection could not start",true)
    return job

func _request_job(job: Dictionary) -> Dictionary:
    var client: HTTPClient = job.client
    var encoded = PackedByteArray() if job.body == null else JSON.stringify(job.body,"",true,true).to_utf8_buffer()
    var result = client.request_raw(job.method,job.path,_headers(job.body != null),encoded)
    if result != OK: return failure("transport","HTTP request could not start",true)
    job.phase = "headers"; job.sent = true
    return success()

func _http_tick(job: Dictionary, streaming: bool = false) -> Dictionary:
    if job.has("immediate"): return job.immediate
    var now = Time.get_ticks_msec()
    if (not streaming or job.phase != "stream") and now-job.started > float(_options.request_timeout)*1000:
        return failure("transport","HTTP request timed out",true)
    var client: HTTPClient = job.client
    # Reading the final body chunk can already transition to DISCONNECTED
    # when the server sends Connection: close. Polling again then returns an
    # unconfigured-client error, even though the complete response is buffered.
    var state = client.get_status()
    var finished_body = job.phase == "body" and state in [HTTPClient.STATUS_CONNECTED,HTTPClient.STATUS_DISCONNECTED]
    var polled = OK if finished_body else client.poll()
    state = client.get_status()
    if polled != OK or state in [HTTPClient.STATUS_CANT_CONNECT,HTTPClient.STATUS_CANT_RESOLVE,
            HTTPClient.STATUS_CONNECTION_ERROR,HTTPClient.STATUS_TLS_HANDSHAKE_ERROR]:
        return failure("transport","HTTP connection failed",true)
    if job.phase == "connect":
        if state == HTTPClient.STATUS_CONNECTED:
            var sent = _request_job(job)
            if not sent.ok: return sent
        elif state == HTTPClient.STATUS_DISCONNECTED: return failure("transport","HTTP connection closed",true)
        return {"pending":true}
    if job.phase == "headers":
        if client.has_response():
            job.code = client.get_response_code()
            for header in client.get_response_headers():
                var colon = header.find(":")
                if colon >= 0: job.headers[header.substr(0,colon).strip_edges().to_lower()] = header.substr(colon+1).strip_edges()
            if job.code >= 300 and job.code < 400:
                return failure("protocol","Authenticated redirects are forbidden")
            if job.headers.get("content-encoding","identity") not in ["","identity"]:
                return failure("protocol","Unexpected compressed HTTP response")
            if client.get_response_body_length() > MAX_BYTES and not streaming:
                return failure("protocol","HTTP response exceeds 64 MiB")
            if streaming and job.code == 200:
                if String(job.headers.get("content-type","")).split(";")[0].strip_edges().to_lower() != "text/event-stream":
                    return failure("protocol","Expected event stream")
                job.phase = "stream"
            else: job.phase = "body"
        elif state == HTTPClient.STATUS_DISCONNECTED: return failure("transport","HTTP closed before response",true)
        else: return {"pending":true}
    if job.phase == "stream":
        if state == HTTPClient.STATUS_BODY:
            var chunk = client.read_response_body_chunk()
            if not chunk.is_empty():
                job.last_byte = now
                return {"chunk":chunk}
            if now-job.last_byte > float(_options.stream_idle_timeout)*1000:
                return failure("transport","Event stream read timed out",true)
            return {"pending":true}
        if state in [HTTPClient.STATUS_CONNECTED,HTTPClient.STATUS_DISCONNECTED]:
            return failure("transport","Stream ended before final cursor",true)
        return {"pending":true}
    if job.phase == "body":
        if state == HTTPClient.STATUS_BODY:
            var chunk = client.read_response_body_chunk()
            if not chunk.is_empty():
                var accumulated: PackedByteArray = job.raw
                accumulated.append_array(chunk); job.raw = accumulated; job.last_byte = now
                if job.raw.size() > MAX_BYTES: return failure("protocol","HTTP response exceeds 64 MiB")
                return {"pending":true}
            state = client.get_status()
        if state in [HTTPClient.STATUS_CONNECTED,HTTPClient.STATUS_DISCONNECTED]:
            if client.get_response_body_length() >= 0 and job.raw.size() != client.get_response_body_length():
                return failure("transport","Truncated HTTP response",true)
            if job.code < 200 or job.code >= 300: return _api_error(job)
            var admission_started = Time.get_ticks_usec()
            var admitted: Dictionary = _protocol.decode(job.root,job.raw)
            _timings.admission_ms += (Time.get_ticks_usec()-admission_started)/1000.0
            if admitted.ok: admitted.raw = job.raw
            return admitted
    return {"pending":true}

func _api_error(job: Dictionary) -> Dictionary:
    var decoded: Dictionary = _protocol.decode("ApiError",job.raw)
    if not decoded.ok: return decoded
    decoded.value = _protocol.normalize("ApiError",decoded.value)
    if int(decoded.value.http_status) != job.code: return failure("protocol","HTTP error status mismatch")
    var error = {"kind":"api","message":decoded.value.code,"retryable":decoded.value.retryable,
        "value":decoded.value,"retry_after_ms":mini(5000,int(decoded.value.get("retry_after_ms",0)))}
    var after: String = job.headers.get("retry-after","")
    error.retry_after_ms = maxi(error.retry_after_ms,retry_after_ms(after))
    return {"ok":false,"error":error}

static func retry_after_ms(value: String, now: float = -1.0) -> int:
    if value.is_empty(): return 0
    var pattern = RegEx.new()
    pattern.compile("^[0-9]+$")
    if pattern.search(value) != null: return int(minf(5.0,value.to_float())*1000)
    # HTTP-date's IMF-fixdate form; Date/Time parsing stays independent of locale.
    pattern.compile("^[A-Za-z]{3}, ([0-9]{2}) ([A-Za-z]{3}) ([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) GMT$")
    var found = pattern.search(value)
    if found == null: return 0
    var month = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"].find(found.get_string(2))+1
    var day = found.get_string(1).to_int()
    var year = found.get_string(3).to_int()
    var hour = found.get_string(4).to_int()
    var minute = found.get_string(5).to_int()
    var second = found.get_string(6).to_int()
    var leap = year%4 == 0 and (year%100 != 0 or year%400 == 0)
    var days = [31,29 if leap else 28,31,30,31,30,31,31,30,31,30,31]
    if month < 1 or day < 1 or day > days[month-1] or hour > 23 or minute > 59 or second > 59: return 0
    var date = Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":day,"hour":hour,"minute":minute,"second":second})
    if now < 0: now = Time.get_unix_time_from_system()
    return int(clampf((date-now)*1000,0,5000))

func _endpoint(command: Dictionary) -> Dictionary:
    var operation: String = command.operation
    var body: Dictionary = command.arguments
    var request_root = ""
    var response_root = ""
    var suffix = ""
    var method = HTTPClient.METHOD_GET
    match operation:
        "health": return success({"method":method,"path":"/health","root":"HealthResponse","body":null})
        "status": response_root = "StatusResponse"; suffix = "status"
        "attach": request_root = "AttachmentRequest"; response_root = "AttachmentResponse"; suffix = "attachment"
        "choices": request_root = "ChoicesRequest"; response_root = "ChoicesResponse"; suffix = "choices"
        "preview": request_root = "PreviewRequest"; response_root = "PreviewResponse"; suffix = "preview"
        "submit_command": request_root = "CommandRequest"; response_root = "ReceiptResponse"; suffix = "commands"
        "acknowledge": request_root = "AckRequest"; response_root = "AckResponse"; suffix = "ack"
        "receipt":
            var number: Variant = body.get("number")
            if not (number is int) or number < 1 or number > MAX_SAFE_INTEGER:
                return failure("protocol","Invalid command receipt number")
            response_root = "ReceiptResponse"; suffix = "commands/"+str(number)
        "content":
            if not (body.get("revision") is String) or String(body.revision).is_empty():
                return failure("protocol","Missing content revision")
            return success({"method":method,"path":"/api/v1/content/"+String(body.revision).uri_encode(),"root":"ContentResponse","body":null})
        _: return failure("protocol","Unknown SDK operation: "+operation)
    if _bootstrap.is_empty(): return failure("protocol","Bootstrap has not completed")
    var payload: Variant = null
    if not request_root.is_empty():
        var valid: Dictionary = _protocol.validate(request_root,body)
        if not valid.ok: return valid
        payload = _protocol.normalize(request_root,body)
        command.arguments = payload
        method = HTTPClient.METHOD_POST
    if operation in ["choices","preview","submit_command"] and _attachment.is_empty():
        return failure("protocol","Acquire an attachment first")
    if operation == "acknowledge":
        if _attachment.is_empty(): return failure("protocol","Acquire an attachment first")
        var scoped = _scope(payload.cursor)
        if not scoped.ok: return scoped
    return success({"method":method,"path":_route(suffix),"root":response_root,"body":payload})

func _check_reply(command: Dictionary, packet: Dictionary) -> Dictionary:
    var body: Dictionary = command.arguments
    var checked = success()
    match command.operation:
        "attach":
            checked = _status(packet.status)
            if checked.ok and packet.acquisition_id != body.acquisition_id: checked = failure("protocol","Attachment acquisition mismatch")
            if checked.ok: _attachment = packet
        "status": checked = _status(packet.status)
        "choices":
            checked = _scope(packet)
            if checked.ok and (packet.correlation_id != body.correlation_id or packet.state_revision != body.state_revision or packet.force_attack != body.force_attack or packet.choices.entity_uuid != body.actor_uuid):
                checked = failure("protocol","Choices correlation mismatch")
        "preview":
            checked = _scope(packet)
            if checked.ok:
                var echoed: Dictionary = _protocol.normalize("PreviewRequest",packet.request)
                for field in ["actor_uuid","state_revision","discovery_generation","correlation_id"]:
                    if echoed[field] != body[field]: checked = failure("protocol","Preview correlation mismatch")
                if packet.state_revision != body.state_revision or echoed.selection.action_index != body.selection.action_index or echoed.selection.target_indices != body.selection.target_indices or echoed.selection.get("extra_target_positions",[]) != body.selection.get("extra_target_positions",[]) or echoed.selection.get("prefer_safe",true) != body.selection.get("prefer_safe",true):
                    checked = failure("protocol","Preview selection mismatch")
        "submit_command", "receipt":
            # Defaults select the admitted receipt variant for control flow;
            # the returned packet and raw HTTP bytes stay exactly as received.
            var receipt: Dictionary = _protocol.normalize("ReceiptResponse",packet).receipt
            checked = _scope(packet.receipt)
            if checked.ok and receipt.kind == "committed": checked = _scope(packet.receipt.cursor)
            if checked.ok and packet.receipt.command_number != body.get("command_number",body.get("number")):
                checked = failure("protocol","Command receipt mismatch")
        "content":
            if packet.revision != body.revision: checked = failure("protocol","Content revision mismatch")
        "acknowledge":
            checked = _scope(packet.cursor)
            if checked.ok: checked = _scope(packet.catch_up_cursor)
            if checked.ok and packet.cursor.sequence != body.cursor.sequence: checked = failure("protocol","ACK mismatch")
    return success(packet) if checked.ok else checked

func _queue_ack(purpose: String) -> void:
    var body: Dictionary = _protocol.normalize("AckRequest",{"cursor":_follower.consumed})
    _jobs.append(_new_job(HTTPClient.METHOD_POST,_route("ack"),"AckResponse",body,purpose))
    _follower.phase = "ack"

func _consume(packet: Dictionary, raw: PackedByteArray) -> Dictionary:
    if _stopping(): return failure("cancelled","SDK cancelled")
    if not _consumer.is_valid(): return failure("protocol","A passive consumer is required before following")
    var started = Time.get_ticks_usec()
    var result: Variant = _consumer.call(packet,raw)
    _timings.consumer_ms += (Time.get_ticks_usec()-started)/1000.0
    if _stopping(): return failure("cancelled","SDK cancelled")
    if not (result is Dictionary) or not result.has("ok"):
        return failure("protocol","Consumer must return a result")
    if not result.ok: return result
    _follower.consumed = packet.cursor.duplicate(true)
    _emit({"kind":"consumed","value":{"cursor":packet.cursor,"state_revision":packet.get("state_revision"),"boundary":packet.get("boundary")}})
    return success()

func _close_stream() -> void:
    if not _stream.is_empty(): _stream.client.close()
    _stream = {}; _events.clear(); _parser = null; _framing_failure = {}

func _open_stream() -> void:
    _close_stream()
    _parser = SSE.new(_protocol)
    _stream = _new_job(HTTPClient.METHOD_GET,_route("events")+"?after="+str(int(_follower.consumed.sequence)),"",null,"stream")
    _follower.phase = "stream"

func _fail_follow(result: Dictionary) -> void:
    _close_stream()
    _follower.running = false; _follower.failure = result; _follower.phase = "failed"
    _emit({"kind":"failure","result":result})

func _interrupted(result: Dictionary, immediate: bool = false) -> void:
    _close_stream()
    if result.error.kind not in ["transport","api"] or not result.error.retryable:
        _fail_follow(result); return
    var now = Time.get_ticks_msec()
    if _follower.retry_since < 0: _follower.retry_since = now
    var remaining = float(_options.reconnect_timeout)*1000-(now-_follower.retry_since)
    if remaining <= 0:
        _fail_follow(failure("transport","Reconnect deadline exceeded")); return
    var delay = minf(5000,250*pow(2,mini(_follower.attempt,5))*randf_range(0.8,1.2))
    delay = maxf(delay,result.error.get("retry_after_ms",0))
    _follower.retry_at = now+(0 if immediate else mini(int(delay),int(remaining)))
    _follower.attempt += 1; _follower.phase = "retry"
    _emit({"kind":"reconnecting","value":{"cursor":_follower.consumed,"reason":result.error.message}})

func _maybe_complete() -> void:
    if not _follower.running or _follower.phase != "stream" or _follower.status == null: return
    var final_cursor: Variant = _follower.status.get("final_cursor")
    if final_cursor == null or int(_follower.consumed.sequence) < int(final_cursor.sequence): return
    var boundary: Dictionary = _follower.status.boundary
    if boundary.lifecycle != "terminal":
        var code = "game_failed" if boundary.lifecycle == "failed" else "game_closed"
        _fail_follow({"ok":false,"error":{"kind":"api","message":code,"retryable":false,
            "value":{"kind":"error","code":code,"http_status":503 if code=="game_failed" else 410,"retryable":false,"incident_id":boundary.get("incident_id")}}})
        return
    _close_stream(); _follower.running = false; _follower.completed = true; _follower.phase = "complete"
    _emit({"kind":"completed","value":{"cursor":_follower.consumed,"status":_follower.status}})

func _event(record: Dictionary) -> void:
    var roots = {"ready":"StreamReady","status":"StreamStatus","operation":"PlayerOperation","error":"ApiError"}
    if not roots.has(record.event): _fail_follow(failure("protocol","Unknown SSE event")); return
    var admission_started = Time.get_ticks_usec()
    var decoded: Dictionary = _protocol.decode(roots[record.event],record.raw)
    _timings.admission_ms += (Time.get_ticks_usec()-admission_started)/1000.0
    if not decoded.ok: _fail_follow(decoded); return
    var packet: Dictionary = decoded.value
    if record.event == "error":
        var admitted_error: Dictionary = _protocol.normalize("ApiError",packet)
        _fail_follow({"ok":false,"error":{"kind":"api","message":admitted_error.code,"retryable":admitted_error.retryable,"value":packet}}); return
    var checked = success()
    if record.event in ["ready","status"]:
        checked = _status(packet.status)
        if checked.ok and record.event == "ready":
            checked = _protocol.check_identity(packet.protocol)
            if checked.ok: checked = _scope(packet.after)
            if checked.ok: checked = _scope(packet.head)
            if checked.ok and packet.after.sequence != _follower.consumed.sequence: checked = failure("protocol","Resume cursor mismatch")
        if not checked.ok: _fail_follow(checked); return
        _follower.status = packet.status
        _emit({"kind":"status","value":packet.status})
    else:
        checked = _protocol.check_identity(packet.protocol)
        if checked.ok: checked = _scope(packet.cursor)
        if not checked.ok: _fail_follow(checked); return
        var sequence = int(packet.cursor.sequence)
        if record.id != str(sequence): _fail_follow(failure("protocol","SSE ID/body mismatch")); return
        if sequence <= int(_follower.consumed.sequence): return
        if sequence != int(_follower.consumed.sequence)+1:
            _fail_follow(failure("protocol","Non-contiguous operation")); return
        checked = _consume(packet,record.raw)
        if not checked.ok: _fail_follow(checked); return
        _queue_ack("operation_ack")
    _follower.retry_since = -1; _follower.attempt = 0
    _maybe_complete()

func _finish_job(job: Dictionary, result: Dictionary) -> void:
    var elapsed = Time.get_ticks_msec()-int(job.started)
    _timings.completed_requests += 1
    _timings.request_wall_ms += elapsed
    _timings.maximum_request_wall_ms = maxf(_timings.maximum_request_wall_ms,elapsed)
    if result.ok and String(job.headers.get("connection","")).to_lower() != "close" and job.client.get_status() == HTTPClient.STATUS_CONNECTED: _idle_clients.append(job.client)
    else: job.client.close()
    match job.purpose:
        "bootstrap":
            if result.ok:
                var identity: Dictionary = _protocol.check_identity(result.value.protocol)
                if not identity.ok: result = identity
                else:
                    _bootstrap = result.value
                    var scoped = _status(_bootstrap.status)
                    if not scoped.ok: result = scoped; _bootstrap = {}
            _emit({"kind":"connected" if result.ok else "failure","result":result})
        "endpoint":
            if result.ok: result = _check_reply(job.command,result.value)
            if result.ok and job.command.operation in ["choices","preview","submit_command","receipt"]:
                # Keep the exact admitted value available to SDK callers, with
                # a separate defaulted presentation copy prepared off-thread.
                var normalization_started = Time.get_ticks_usec()
                result.normalized = _protocol.normalize(job.root,result.value)
                _timings.response_normalization_ms += (Time.get_ticks_usec()-normalization_started)/1000.0
            _reply(job.command,result)
        "initialization":
            if result.ok:
                var checked: Dictionary = _protocol.check_identity(result.value.protocol)
                if checked.ok: checked = _scope(result.value.cursor)
                if checked.ok: checked = _consume(result.value,result.raw)
                if not checked.ok: result = checked
            if not result.ok: _fail_follow(result)
            else: _queue_ack("resume_ack")
        "resume_ack", "operation_ack":
            if result.ok:
                var checked = _scope(result.value.cursor)
                if checked.ok: checked = _scope(result.value.catch_up_cursor)
                if checked.ok and result.value.cursor.sequence != job.body.cursor.sequence: checked = failure("protocol","ACK mismatch")
                if not checked.ok: result = checked
            if not result.ok: _interrupted(result)
            elif job.purpose == "resume_ack": _open_stream()
            else:
                _follower.phase = "stream"
                if not _stream.is_empty(): _stream.last_byte = Time.get_ticks_msec()
                _maybe_complete()

func _accept(command: Dictionary) -> void:
    match command.operation:
        "follow":
            if _attachment.is_empty(): _reply(command,failure("protocol","Acquire an attachment first")); return
            if _follower.started: _reply(command,failure("protocol","Follower already started or completed")); return
            if not _consumer.is_valid(): _reply(command,failure("protocol","Follower requires a consumer")); return
            _follower.started = true; _follower.running = true; _follower.phase = "initialization"
            _jobs.append(_new_job(HTTPClient.METHOD_GET,_route("initialization"),"InitializationResponse",null,"initialization"))
            _reply(command,success({"following":true}))
        "reconnect":
            if not _follower.running or _follower.consumed == null:
                _reply(command,failure("protocol","No initialized follower to reconnect")); return
            for job in _jobs.duplicate():
                if job.purpose in ["resume_ack","operation_ack"]: job.client.close(); _jobs.erase(job)
            _interrupted(failure("transport","Requested stream reconnect",true),true)
            _reply(command,success())
        "wait_for_cursor":
            var checked: Dictionary = _protocol.validate("PlayerCursor",command.arguments.get("cursor"))
            if checked.ok and _bootstrap.is_empty(): checked = failure("protocol","Bootstrap has not completed")
            if checked.ok: checked = _scope(command.arguments.cursor)
            if not checked.ok: _reply(command,checked); return
            if _waiters.size() >= 64: _reply(command,failure("protocol","Too many cursor waits")); return
            command.deadline = Time.get_ticks_msec()+maxf(0,float(command.arguments.get("timeout",30)))*1000
            _waiters.append(command)
        _:
            if _jobs.size() >= int(_options.max_requests):
                _reply(command,failure("transport","SDK request capacity reached",true)); return
            var endpoint = _endpoint(command)
            if not endpoint.ok: _reply(command,endpoint); return
            var spec: Dictionary = endpoint.value
            _jobs.append(_new_job(spec.method,spec.path,spec.root,spec.body,"endpoint",command))

func _check_waiters() -> void:
    for waiter in _waiters.duplicate():
        var result: Dictionary = {}
        var target = int(waiter.arguments.cursor.sequence)
        if _follower.consumed != null and int(_follower.consumed.sequence) >= target: result = success(_follower.consumed)
        elif not _follower.failure.is_empty(): result = _follower.failure
        elif _follower.completed or (_follower.status != null and _follower.status.get("final_cursor") != null and target > int(_follower.status.final_cursor.sequence)):
            result = failure("protocol","Final cursor precedes requested cursor")
        elif Time.get_ticks_msec() >= waiter.deadline: result = failure("transport","Cursor wait timed out")
        if not result.is_empty(): _reply(waiter,result); _waiters.erase(waiter)

func _run() -> void:
    _protocol = Protocol.new()
    _jobs.append(_new_job(HTTPClient.METHOD_GET,"/api/v1/bootstrap","BootstrapResponse",null,"bootstrap"))
    while not _stopping():
        for command in _take_requests(): _accept(command)
        for job in _jobs.duplicate():
            if not job in _jobs: continue
            var result = _http_tick(job)
            if result.has("pending"): continue
            _jobs.erase(job)
            _finish_job(job,result)
        if _follower.running:
            if _follower.phase == "retry" and Time.get_ticks_msec() >= _follower.retry_at: _queue_ack("resume_ack")
            if _follower.phase == "stream":
                if _events.is_empty():
                    if not _framing_failure.is_empty(): _fail_follow(_framing_failure)
                    else:
                        var result = _http_tick(_stream,true)
                        if result.has("chunk"):
                            var framed: Dictionary = _parser.feed(result.chunk)
                            _events.append_array(framed.value if framed.ok else framed.get("records",[]))
                            if not framed.ok: _framing_failure = {"ok":false,"error":framed.error}
                        elif result.has("ok"):
                            # Non-200 streaming replies follow the ordinary typed
                            # HTTP error path; clean early EOF is reconnectable.
                            _interrupted(result if not result.ok else failure("transport","Event stream closed",true))
                if _follower.running and _follower.phase == "stream" and not _events.is_empty(): _event(_events.pop_front())
        _check_waiters()
        _publish_diagnostics()
        OS.delay_msec(1)
    _close_stream()
    var cancelled = failure("cancelled","SDK cancelled")
    for job in _jobs:
        job.client.close()
        if not job.command.is_empty(): _reply(job.command,cancelled)
    for client in _idle_clients: client.close()
    for waiter in _waiters: _reply(waiter,cancelled)
    for command in _take_requests(): _reply(command,cancelled)
    if _follower.running: _fail_follow(cancelled)
    _jobs.clear(); _waiters.clear(); _idle_clients.clear()
    _mutex.lock(); _running = false; _mutex.unlock()
