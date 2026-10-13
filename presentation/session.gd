extends RefCounted
# The SDK owns networking. This owner prepares recorded presentation on its
# consumer worker. A separate cancellable worker prepares only the next two
# operations; durable journal files retain every later operation without RAM backlog.
const Transport = preload("res://sdk/transport.gd")
const Journal = preload("res://sdk/journal.gd")
const Protocol = preload("res://sdk/protocol.gd")
const Reducer = preload("res://sdk/reducer.gd")
const Compiler = preload("res://presentation/compiler.gd")
var transport = Transport.new()
var journal = Journal.new()
var protocol = Protocol.new()
var authoring_cache: Dictionary = {}
var mutex = Mutex.new()
var prepared: Array = []
var prepared_sequence = -1
var preparation_state: Dictionary = {}
var latest_sequence = -1
var status: Dictionary = {}
var bootstrap: Dictionary = {}
var issue: Dictionary = {}
var status_issue: Dictionary = {}
var responses: Dictionary = {}
var connected = false
var following = false
var terminal = false
var attachment_request = -1
var status_request = -1
var following_request = -1
var status_due = 0
var start_ms = 0
var replay_thread: Thread
var replay_error: Dictionary = {}
var replay_finished = false
var recording_ready = false
var preparation_cursor: Dictionary = {}
var preparation_wait_ms = 0
var last_poll_ms = Time.get_ticks_msec()
const LOOKAHEAD_OPERATIONS = 2
var prepare_thread: Thread
var wake = Semaphore.new()
var cancelled = false
var displayed_sequence = -1
var available_sequence = -1
var admitted_pending: Dictionary = {}
var retired_staged: Array = []
var retired_ready: Array = []
var retired_records_staged: Array = []
var retired_records_ready: Array = []
var preparation_metrics = {"compiled_operations":0,"packet_prepare_ms":0.0,"compile_ms":0.0,"journal_ms":0.0,
    "disk_reloads":0,"handoff_hits":0,"recorded_handoff_hits":0,"active":false,"held_for_display":false,
    "retired_groups":0,"retirement_ms":0.0,"retirement_peak_groups":0,
    "retired_records":0,"record_retirement_ms":0.0,"retirement_peak_records":0}

func retire_group(group: Dictionary) -> void:
    # Passive compiler data only. Publish next poll, after the prior timeline
    # call and scene callback have released their temporary references.
    mutex.lock()
    if cancelled:
        mutex.unlock()
        return
    retired_staged.append(group)
    preparation_metrics.retirement_peak_groups = maxi(preparation_metrics.retirement_peak_groups,retired_staged.size()+retired_ready.size())
    mutex.unlock()

func retire_record(record: Dictionary) -> void:
    # Passive response/discovery references only. Never clear the caller's data
    # or start another worker; next poll publishes after scene/HUD locals expire.
    mutex.lock()
    if cancelled or prepare_thread == null or not prepare_thread.is_started():
        mutex.unlock()
        return
    retired_records_staged.append(record)
    preparation_metrics.retirement_peak_records = maxi(preparation_metrics.retirement_peak_records,retired_records_staged.size()+retired_records_ready.size())
    mutex.unlock()

func _publish_retired() -> void:
    mutex.lock()
    var changed = not retired_staged.is_empty() or not retired_records_staged.is_empty()
    retired_ready.append_array(retired_staged)
    retired_staged = []
    retired_records_ready.append_array(retired_records_staged)
    retired_records_staged = []
    mutex.unlock()
    if changed: wake.post()

func _release_retired() -> void:
    mutex.lock()
    var released = retired_ready
    retired_ready = []
    var records = retired_records_ready
    retired_records_ready = []
    mutex.unlock()
    var count = released.size()
    var record_count = records.size()
    if count==0 and record_count==0: return
    var started = Time.get_ticks_usec()
    released.clear()
    var elapsed = (Time.get_ticks_usec()-started)/1000.0
    started = Time.get_ticks_usec()
    records.clear()
    var record_elapsed = (Time.get_ticks_usec()-started)/1000.0
    mutex.lock()
    preparation_metrics.retired_groups += count
    preparation_metrics.retirement_ms += elapsed
    preparation_metrics.retired_records += record_count
    preparation_metrics.record_retirement_ms += record_elapsed
    mutex.unlock()

func _ensure_preparer() -> Dictionary:
    if prepare_thread != null: return {"ok":true,"value":null}
    prepare_thread = Thread.new()
    var code = prepare_thread.start(_prepare_loop)
    return {"ok":true,"value":null} if code == OK else {"ok":false,"error":{"kind":"recording","message":error_string(code)}}

func set_displayed_sequence(value: int) -> void:
    mutex.lock()
    var changed = value > displayed_sequence
    displayed_sequence = maxi(displayed_sequence,value)
    mutex.unlock()
    if changed: wake.post()

func diagnostics() -> Dictionary:
    mutex.lock()
    var result = preparation_metrics.duplicate()
    result.merge({"displayed_sequence":displayed_sequence,"available_sequence":available_sequence,
        "prepared_sequence":prepared_sequence,"prepared_messages":prepared.size(),"admitted_handoff":admitted_pending.size(),
        "retirement_pending_groups":retired_staged.size()+retired_ready.size(),
        "retirement_pending_records":retired_records_staged.size()+retired_records_ready.size(),
        "lookahead_operations":LOOKAHEAD_OPERATIONS,"backlog_operations":maxi(0,available_sequence-prepared_sequence),
        "waiting_for_preparation":available_sequence>prepared_sequence and prepared_sequence<=displayed_sequence,
        "preparation_wait_ms":preparation_wait_ms})
    mutex.unlock()
    result.network = transport.diagnostics()
    return result

func _stopping() -> bool:
    mutex.lock(); var value = cancelled; mutex.unlock()
    return value

static func uuid() -> String:
    var bytes = Crypto.new().generate_random_bytes(16)
    bytes[6] = (bytes[6] & 15) | 64
    bytes[8] = (bytes[8] & 63) | 128
    var value = bytes.hex_encode()
    return "%s-%s-%s-%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

func start(config: Dictionary) -> Dictionary:
    var opened = journal.open(config.get("journal", "user://sessions/" + uuid()),false,false)
    if not opened.ok: return opened
    start_ms = Time.get_ticks_msec()
    return transport.start(config.url, config.token, _consume)

func _consume(packet: Dictionary, raw: PackedByteArray) -> Dictionary:
    # Only Transport calls this internal hook after strict admission. Public
    # offline tools keep Journal.consume's independent byte/schema boundary.
    var started = Time.get_ticks_usec()
    var sequence = int(packet.cursor.sequence)
    mutex.lock()
    var record_transitions = sequence>0 and sequence>prepared_sequence and sequence<=displayed_sequence+LOOKAHEAD_OPERATIONS and admitted_pending.size()<LOOKAHEAD_OPERATIONS+1
    mutex.unlock()
    var accepted = journal._consume_admitted(packet,raw,record_transitions)
    if not accepted.ok: return accepted
    var normalized: Dictionary = accepted.get("normalized",{})
    mutex.lock()
    available_sequence = maxi(available_sequence,sequence)
    preparation_metrics.journal_ms += (Time.get_ticks_usec()-started)/1000.0
    # Keep a bounded shortcut only. Overflow is already durably on disk, so ACK
    # continues independently of display pause, missing media, or compilation.
    # Duplicates publish no new normalized value; never replace/retain another
    # handoff for a sequence the preparer may already be compiling.
    if not normalized.is_empty() and sequence > prepared_sequence and sequence <= displayed_sequence+LOOKAHEAD_OPERATIONS and admitted_pending.size()<LOOKAHEAD_OPERATIONS+1:
        admitted_pending[sequence] = {"packet":normalized if not normalized.is_empty() else packet,
            "normalized":not normalized.is_empty(),"final_state":journal.state if int(journal.cursor.sequence)==sequence else {},
            "transitions":accepted.get("transitions",{})}
    mutex.unlock()
    var worker = _ensure_preparer()
    if not worker.ok: return worker
    wake.post()
    return {"ok":true,"value":null}

func _prepare_loop() -> void:
    while not _stopping():
        _release_retired()
        mutex.lock()
        var next = prepared_sequence+1
        var allowed = replay_error.is_empty() and next <= available_sequence and next <= displayed_sequence+LOOKAHEAD_OPERATIONS
        preparation_metrics.held_for_display = next <= available_sequence and not allowed
        preparation_metrics.active = allowed
        var handoff: Dictionary = admitted_pending.get(next,{}) if allowed else {}
        if allowed: admitted_pending.erase(next)
        mutex.unlock()
        if not allowed:
            wake.wait()
            continue
        var root_name = "InitializationResponse" if next==0 else "PlayerOperation"
        var started = Time.get_ticks_usec()
        var packet_started = started
        var result = {"ok":true,"value":null}
        var packet: Dictionary = handoff.get("packet",{})
        if handoff.is_empty():
            var raw = FileAccess.get_file_as_bytes(journal._file(next))
            result = protocol.decode(root_name,raw)
            if result.ok and int(result.value.cursor.sequence)!=next:
                result = {"ok":false,"error":{"kind":"recording","message":"Journal filename/cursor mismatch"}}
            if result.ok:
                var identity = protocol.check_identity(result.value.protocol)
                if not identity.ok: result = identity
            if result.ok and not preparation_cursor.is_empty():
                for key in ["game_id","game_epoch","audience_id"]:
                    if result.value.cursor[key] != preparation_cursor[key]:
                        result = {"ok":false,"error":{"kind":"recording","message":"Recording audience/epoch mismatch"}}
                        break
            if result.ok and replay_thread != null:
                result = journal._consume_admitted(result.value,raw,true)
                if result.ok:
                    packet = result.normalized
                    handoff = {"packet":packet,"normalized":true,"final_state":journal.state,"transitions":result.get("transitions",{}),"from_disk":true}
            elif result.ok: packet = protocol.normalize(root_name,result.value)
        elif not handoff.normalized:
            packet = protocol.normalize(root_name,packet)
        var decode_ms = (Time.get_ticks_usec()-started)/1000.0
        if _stopping(): break
        var message: Dictionary = {}
        var used_records = false
        started = Time.get_ticks_usec()
        if result.ok and next==0:
            var initial_state: Dictionary = handoff.get("final_state",{})
            result = {"ok":true,"value":initial_state} if not initial_state.is_empty() else Reducer.reduce_initialization(packet.initialization,packet.content_additions)
            if result.ok:
                preparation_state = result.value
                message = {"kind":"initialization","state":preparation_state.duplicate(true),"sequence":0,
                    "cursor":packet.cursor.duplicate(true),"command_number":null,
                    "events":Compiler.EventTrace.initialization(packet.initialization)}
        elif result.ok:
            var final_state: Dictionary = handoff.get("final_state",{})
            var transitions: Dictionary = handoff.get("transitions",{})
            if not final_state.is_empty() and not transitions.is_empty():
                used_records = true
                result = Compiler.compile_recorded(preparation_state,packet,authoring_cache,final_state,transitions)
            else:
                result = Compiler.compile(preparation_state,packet,authoring_cache)
            if result.ok:
                preparation_state = result.value.final_state
                message = {"kind":"operation","groups":result.value.groups,"sequence":next,
                    "cursor":packet.cursor.duplicate(true),"command_number":packet.command_number,
                    "skipped":result.value.get("skipped",[])}
        if _stopping(): break
        transport.profile_preparation(next,packet_started,started,Time.get_ticks_usec(),result.ok,handoff.is_empty() or handoff.get("from_disk",false))
        mutex.lock()
        preparation_metrics.active = false
        preparation_metrics.packet_prepare_ms += decode_ms
        preparation_metrics.compile_ms += (Time.get_ticks_usec()-started)/1000.0
        preparation_metrics["disk_reloads" if handoff.is_empty() or handoff.get("from_disk",false) else "handoff_hits"] += 1
        if not result.ok:
            replay_error = result.error
            mutex.unlock()
            continue
        prepared.append(message)
        prepared_sequence = next
        preparation_cursor = packet.cursor.duplicate(true)
        preparation_metrics.compiled_operations += 1
        if used_records: preparation_metrics.recorded_handoff_hits += 1
        mutex.unlock()
    _release_retired()

func take_prepared() -> Array:
    mutex.lock()
    var result = prepared
    prepared = []
    mutex.unlock()
    return result

func open_recording(directory: String) -> Dictionary:
    replay_thread = Thread.new()
    var started = replay_thread.start(_replay.bind(directory))
    return {"ok":true,"value":null} if started == OK else {"ok":false,"error":{"kind":"recording","message":error_string(started)}}

func _replay(directory: String) -> void:
    var result = journal.open(directory,true,false)
    if result.ok:
        protocol = journal.protocol
        var files: Array[String] = []
        var pattern = RegEx.new(); pattern.compile("^[0-9]{16}\\.json$")
        for filename in DirAccess.get_files_at(directory):
            if _stopping(): return
            if pattern.search(filename) != null: files.append(filename)
        files.sort()
        for index in range(files.size()):
            if _stopping(): return
            if files[index].trim_suffix(".json").to_int()!=index:
                result = {"ok":false,"error":{"kind":"recording","message":"Journal filename sequence gap"}}
                break
        if result.ok and files.is_empty(): result = {"ok":false,"error":{"kind":"recording","message":"Empty recording"}}
        if result.ok:
            mutex.lock(); available_sequence = files.size()-1; mutex.unlock()
            result = _ensure_preparer()
            wake.post()
    mutex.lock()
    if not result.ok: replay_error = result.error
    replay_finished = true
    mutex.unlock()

func poll() -> void:
    _publish_retired()
    var now = Time.get_ticks_msec()
    mutex.lock()
    if available_sequence>prepared_sequence and prepared_sequence<=displayed_sequence: preparation_wait_ms += now-last_poll_ms
    last_poll_ms = now
    if not replay_error.is_empty(): issue = replay_error
    mutex.unlock()
    if replay_thread != null:
        mutex.lock()
        if not replay_error.is_empty(): issue = replay_error
        if replay_finished:
            recording_ready = prepared_sequence >= 0 or not replay_error.is_empty()
            terminal = prepared_sequence == available_sequence or not replay_error.is_empty()
            latest_sequence = available_sequence
        mutex.unlock()
        return
    for event in transport.drain():
        match event.kind:
            "connected":
                if not event.result.ok: issue = event.result.error; continue
                connected = true
                bootstrap = event.result.value
                status = bootstrap.status
            "failure": issue = event.result.error
            "consumed": latest_sequence = int(event.value.cursor.sequence)
            "status": status = event.value; status_issue = {}
            "completed": terminal = true; status = event.value.status
            "response":
                var id = int(event.request_id)
                if id == status_request:
                    status_request = -1
                    if event.result.ok: status = event.result.value.status; status_issue = {}
                    elif event.result.error.get("retryable",false):
                        status_issue = event.result.error
                        status_due = Time.get_ticks_msec()+1000
                    else: issue = event.result.error
                elif id == attachment_request:
                    attachment_request = -2
                    if event.result.ok:
                        status = event.result.value.status
                        following_request = transport.follow()
                    else: issue = event.result.error
                elif id == following_request:
                    following_request = -1
                    following = event.result.ok
                    if not event.result.ok: issue = event.result.error
                else: responses[id] = event.result
    if not issue.is_empty() or not connected: return
    if attachment_request == -1 and status.get("published_cursor") != null:
        attachment_request = transport.request("attach",{"acquisition_id":uuid(),"expected_attachment_epoch":status.attachment_epoch})
    # Control state can change without an SSE operation (including ACK status).
    if not terminal and status_request == -1 and Time.get_ticks_msec() >= status_due:
        status_request = transport.request("status")
        status_due = Time.get_ticks_msec() + 250

func request(operation: String, arguments: Dictionary = {}) -> int:
    return transport.request(operation, arguments)

func ready_for_input(displayed_sequence: int) -> bool:
    if not issue.is_empty() or not status_issue.is_empty() or status.is_empty() or not following: return false
    if status.boundary.lifecycle != "waiting_for_human": return false
    if status.boundary.input_actor_uuid == null: return false
    var ack: Variant = status.get("acknowledged_cursor")
    var catch_up: Variant = status.get("catch_up_cursor")
    return ack != null and catch_up != null and int(ack.sequence) >= int(catch_up.sequence) and displayed_sequence >= int(catch_up.sequence)

func close() -> void:
    # Wake a buffer-full preparer before joining, never under the shared mutex.
    mutex.lock()
    retired_ready.append_array(retired_staged)
    retired_staged = []
    retired_records_ready.append_array(retired_records_staged)
    retired_records_staged = []
    cancelled = true
    mutex.unlock()
    wake.post()
    transport.close()
    if replay_thread != null and replay_thread.is_started(): replay_thread.wait_to_finish()
    if prepare_thread != null and prepare_thread.is_started(): prepare_thread.wait_to_finish()
