extends SceneTree
## Explicit current-producer trust: exact values, bounded admission, real SSE.
const Protocol = preload("res://sdk/protocol.gd")
const Transport = preload("res://sdk/transport.gd")
const SSE = preload("res://sdk/sse.gd")
const BasePeer = preload("res://tests/sdk_transport_peer.gd")
var checks := 0
var failures: Array = []
var recording := ""
var operations := 0
var peer: RefCounted
var transport: RefCounted
var consumer: RefCounted
var connected: Variant = null
var terminal: Variant = null
var responses: Dictionary = {}

class Peer extends "res://tests/sdk_transport_peer.gd":
    func operation(sequence: int) -> Dictionary:
        var value: Dictionary = Protocol.new().normalize("PlayerOperation",super.operation(sequence))
        if mode == "trusted_body": value.audience.fixture_marker = "Producer-owned nested body"
        if mode == "operation_identity": value.protocol = protocol.duplicate(true); value.protocol.schema_digest = "f".repeat(64)
        return value
    func ready(final: int, after: int) -> String:
        return "" if mode == "no_ready" else super.ready(final,after)

class Consumer extends RefCounted:
    var seen: Array = []
    var trusted: Array = []
    var reject := false
    func consume(packet: Dictionary, raw: PackedByteArray, canonical_server_operation: bool = false) -> Dictionary:
        if var_to_bytes(Protocol.parse_json(raw).value) != var_to_bytes(packet):
            return Transport.failure("protocol","Consumer values differ from exact raw bytes")
        if reject and packet.cursor.sequence == 1: return Transport.failure("protocol","Semantic operation rejected")
        seen.append(packet.cursor.sequence); trusted.append(canonical_server_operation)
        return Transport.success()

func check(value: bool, label: String) -> bool:
    checks += 1
    if not value: failures.append(label); print("TRUSTED_OPERATIONS_FAIL ",label)
    return value

func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
    if peer != null: peer.tick()
    if transport != null:
        for notice in transport.drain():
            if notice.kind == "connected": connected = notice.result
            if notice.kind in ["failure","completed"]: terminal = notice
            if notice.kind == "response": responses[notice.request_id] = notice.result
    return false

func decode(protocol: RefCounted, raw: PackedByteArray) -> Dictionary:
    # This is the real framing-to-admission seam; UTF-8 remains framed once.
    var bytes := "event: operation\nid: 1\ndata: ".to_utf8_buffer()
    bytes.append_array(raw); bytes.append_array("\n\n".to_utf8_buffer())
    var framed: Dictionary = SSE.new(protocol).feed(bytes)
    if not framed.ok: return framed
    if framed.value.size() != 1: return Protocol.failure("Expected one complete SSE record")
    return protocol._decode_framed_event("PlayerOperation",framed.value[0].raw,false,true)

func recorded_checks(protocol: RefCounted) -> void:
    var names := DirAccess.get_files_at(recording)
    names.sort()
    for name in names:
        if not name.ends_with(".json"): continue
        var raw := FileAccess.get_file_as_bytes(recording.path_join(name))
        var parsed := Protocol.parse_json(raw)
        if not parsed.ok or not parsed.value is Dictionary or parsed.value.get("kind") != "operation": continue
        operations += 1
        var strict: Dictionary = protocol.decode("PlayerOperation",raw)
        var trusted: Dictionary = decode(protocol,raw)
        if not check(strict.ok and trusted.ok,"Actual operation "+name+" admitted by both paths"): continue
        check(var_to_bytes(strict.value) == var_to_bytes(trusted.value),"Actual operation "+name+" preserves every value type and decimal bit")
        var normalized: Variant = protocol.normalize("PlayerOperation",strict.value)
        check(var_to_bytes(normalized) == var_to_bytes(trusted.value),"Actual canonical operation "+name+" already equals strict normalization")
    check(operations > 0,"Explicit journal contains current-server operation records")

func value_checks(protocol: RefCounted) -> void:
    var source := Peer.new().operation(1)
    for field in source:
        var missing := source.duplicate(true); missing.erase(field)
        check(not decode(protocol,JSON.stringify(missing).to_utf8_buffer()).ok,"Canonical envelope requires "+str(field))
    for mode in ["wrong_kind","bad_identity","bad_cursor","zero_sequence","float_sequence","unsafe_sequence","bad_boundary","bad_revision","bad_command","audience_shape","lineages_shape","hud_shape","logs_shape","content_shape","extra"]:
        var bad := source.duplicate(true)
        match mode:
            "wrong_kind": bad.kind = "initialization"
            "bad_identity": bad.protocol.schema_digest = "f".repeat(64)
            "bad_cursor": bad.cursor.game_epoch = "invalid"
            "zero_sequence": bad.cursor.sequence = 0
            "float_sequence": bad.cursor.sequence = 0.5
            "unsafe_sequence": bad.cursor.sequence = Protocol.SAFE_INTEGER+1
            "bad_boundary": bad.boundary.lifecycle = "invalid"
            "bad_revision": bad.state_revision = null
            "bad_command": bad.command_number = 0
            "audience_shape": bad.audience = []
            "lineages_shape": bad.lineages = {}
            "hud_shape": bad.hud = false
            "logs_shape": bad.combat_log_appends = {}
            "content_shape": bad.content_additions = null
            "extra": bad.extra = true
        check(not decode(protocol,JSON.stringify(bad).to_utf8_buffer()).ok,"Bounded operation admission rejects "+mode)
    for malformed in ["{", "null", "[]", JSON.stringify(source)+",", JSON.stringify(source).trim_suffix("}")+",}"]:
        check(not decode(protocol,malformed.to_utf8_buffer()).ok,"Trusted operation retains strict JSON syntax")
    var invalid := JSON.stringify(source).to_utf8_buffer(); invalid.append(255)
    check(not decode(protocol,invalid).ok,"SSE rejects invalid UTF-8 before trusted admission")
    invalid = JSON.stringify(source).to_utf8_buffer(); invalid.append(0)
    check(not decode(protocol,invalid).ok,"Trusted operation rejects unrepresentable NUL")
    var body := source.duplicate(true); body.audience.fixture_marker = true
    var body_raw := JSON.stringify(body).to_utf8_buffer()
    check(not protocol.decode("PlayerOperation",body_raw).ok and decode(protocol,body_raw).ok,"Only explicit current-producer path trusts nested typed bodies")
    var omitted := source.duplicate(true); omitted.erase("kind")
    check(protocol.decode("PlayerOperation",JSON.stringify(omitted).to_utf8_buffer()).ok,"Public arbitrary-input decoder retains sparse discriminator default")
    var archived := Protocol.new("res://sdk/recordings/pre-compact-choices/player-api-v1.schema.json","res://sdk/recordings/pre-compact-choices/protocol-identity.json")
    var old := source.duplicate(true); old.protocol = archived.identity
    check(archived.decode("PlayerOperation",JSON.stringify(old).to_utf8_buffer()).ok and not decode(archived,JSON.stringify(old).to_utf8_buffer()).ok,"Archived schema admission stays strict even with explicit trusted request")
    # Legal server-body numeric values are opaque to shallow admission, but are
    # still parsed exactly. Integer tokens remain int64 and decimals Float64.
    for token in [str(-Protocol.SAFE_INTEGER),str(Protocol.SAFE_INTEGER),"-0.0","0.10000000000000001","2.2250738585072014e-308","5e-324"]:
        var raw := JSON.stringify(source).replace('"audience":{','"audience":{"numeric_fixture":'+token+',').to_utf8_buffer()
        var exact := Protocol.parse_json(raw)
        var trusted := decode(protocol,raw)
        check(exact.ok and trusted.ok and var_to_bytes(exact.value) == var_to_bytes(trusted.value),"Exact token and binary64 parity: "+token)
    for value in [0,1,"true",null]:
        var client := Transport.new()
        check(not client.start("http://127.0.0.1:1","test",Callable(),{"trusted_operations":value}).ok,"Operation trust requires a real boolean")
        client.close()
    var remote := Transport.new()
    check(not remote.start("https://example.invalid","test",Callable(),{"trusted_operations":true}).ok,"Operation trust is not silently extended to remote SDK hosts")
    remote.close()

func until(which: String, id: int = -1) -> bool:
    var deadline := Time.get_ticks_msec()+5000
    while Time.get_ticks_msec() < deadline:
        if which == "connected" and (connected != null or terminal != null): return true
        if which == "response" and responses.has(id): return true
        if which == "terminal" and terminal != null: return true
        await process_frame
    check(false,"Timed out waiting for "+which); return false

func request(operation: String, args: Dictionary = {}) -> Dictionary:
    var id: int = transport.request(operation,args)
    if not await until("response",id): return Transport.failure("transport","Test timeout")
    var result: Dictionary = responses[id]; responses.erase(id); return result

func transport_check(mode: String, trusted: bool, expected: Array) -> void:
    connected = null; terminal = null; responses = {}
    peer = Peer.new(); check(peer.start(mode),"Loopback server starts: "+mode)
    consumer = Consumer.new(); consumer.reject = mode == "consumer_failure"
    transport = Transport.new()
    var options := {"request_timeout":2.0,"stream_idle_timeout":2.0,"reconnect_timeout":2.0}
    if trusted: options.trusted_operations = true
    check(transport.start("http://127.0.0.1:"+str(peer.port),"test",consumer.consume,options).ok,"Real transport starts: "+mode)
    await until("connected")
    if connected != null and connected.ok:
        check((await request("attach",{"acquisition_id":BasePeer.UUID,"expected_attachment_epoch":BasePeer.UUID})).ok,"Real scoped attachment succeeds")
        check((await request("follow")).ok,"Real SSE following scheduled")
        await until("terminal")
    transport.close()
    check(consumer.seen == expected,"Only admitted/accepted operations reach committed consumer: "+mode+" trusted="+str(trusted))
    check(peer.acks == expected,"No rejected or duplicate operation is ACKed: "+mode)
    for i in consumer.seen.size():
        check(consumer.trusted[i] == (trusted and consumer.seen[i]>0),"Canonical producer flag is operation-only: "+mode)
    check(not transport.is_running(),"Transport worker joined")
    peer.close(); peer = null; transport = null; consumer = null

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="): recording = arg.trim_prefix("--recording=")
    if recording.is_empty(): check(false,"Usage: --recording=<current server journal directory>"); finish(); return
    var protocol := Protocol.new()
    if not check(protocol.setup_error.is_empty(),"Current protocol loads"): finish(); return
    recorded_checks(protocol)
    value_checks(protocol)
    await transport_check("normal",false,[0,1,2])
    await transport_check("normal",true,[0,1,2])
    await transport_check("trusted_body",false,[0])
    await transport_check("trusted_body",true,[0,1])
    for mode in ["bad_bootstrap","gap","bad_id","bad_scope","bad_utf8","operation_identity","no_ready","consumer_failure"]:
        await transport_check(mode,true,[] if mode=="bad_bootstrap" else [0])
    finish()

func finish() -> void:
    var report := {"checks":checks,"failures":failures,"recording":recording,"operations":operations,
        "command":"Godot --headless --path <NDClientGodot> --script res://tests/trusted_operations_checks.gd -- --recording="+recording,
        "scope":"Current raw server operations equal strict decoded and normalized values, including types/decimal bits. Exact JSON plus bounded canonical envelope; strict public/offline input unchanged. Real HTTP/SSE verifies opt-in, current identity, scope, ID/order, duplicate handling, consumer rejection and operation-only trust. Nested malformed producer bodies deliberately outside trusted-body validation. No live timing claim."}
    FileAccess.open("res://generated/trusted_operations_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TRUSTED_OPERATIONS_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
