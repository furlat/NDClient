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
        # Named malformed-body control, never a recorded gameplay positive.
        # Schema16 operations carry generation/observer and an optional HUD;
        # there is no operation-level audience object anymore.
        if mode == "trusted_body": value.hud = {"fixture_marker":"Producer-owned nested body"}
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
        var original:PackedByteArray=var_to_bytes(trusted.value)
        var normalized: Variant = protocol.normalize("PlayerOperation",strict.value)
        # Current producer packets intentionally stay sparse. The diagnostic
        # normalizer can materialize default fields, but cannot mutate the
        # admitted original or replace the live consumer's packet.
        check(var_to_bytes(trusted.value)==original and var_to_bytes(normalized)==var_to_bytes(protocol.normalize("PlayerOperation",trusted.value)),"Offline normalization preserves original sparse packet and semantic parity: "+name)
    check(operations > 0,"Explicit journal contains current-server operation records")

func value_checks(protocol: RefCounted) -> void:
    var source := Peer.new().operation(1)
    for field in protocol.schema["$defs"].PlayerOperation.required:
        var missing := source.duplicate(true); missing.erase(field)
        check(not protocol.decode("PlayerOperation",JSON.stringify(missing).to_utf8_buffer()).ok,"Public strict operation requires "+str(field))
    # Arbitrary/offline values keep recursive schema checks. The explicitly
    # selected current producer owns its typed bodies; its lightweight identity
    # and positive-sequence checks are exercised separately below. Scope, order,
    # SSE IDs and consumer admission remain real transport tests, not a second
    # schema validator added to the live fast path.
    for mode in ["wrong_kind","bad_cursor","zero_sequence","float_sequence","unsafe_sequence","bad_boundary","bad_revision","bad_command","bad_generation","bad_observer","lineages_shape","hud_shape","logs_shape","content_shape","extra"]:
        var bad := source.duplicate(true)
        match mode:
            "wrong_kind": bad.kind = "initialization"
            "bad_cursor": bad.cursor.game_epoch = "invalid"
            "zero_sequence": bad.cursor.sequence = 0
            "float_sequence": bad.cursor.sequence = 0.5
            "unsafe_sequence": bad.cursor.sequence = Protocol.SAFE_INTEGER+1
            "bad_boundary": bad.boundary.lifecycle = "invalid"
            "bad_revision": bad.state_revision = null
            "bad_command": bad.command_number = 0
            "bad_generation": bad.generation = "invalid"
            "bad_observer": bad.observer_uuid = "invalid"
            "lineages_shape": bad.lineages = {}
            "hud_shape": bad.hud = false
            "logs_shape": bad.combat_log_appends = {}
            "content_shape": bad.content_additions = null
            "extra": bad.extra = true
        check(not protocol.decode("PlayerOperation",JSON.stringify(bad).to_utf8_buffer()).ok,"Public strict operation rejects "+mode)
    for mode in ["identity","missing_identity","missing_cursor","zero_sequence","negative_sequence"]:
        var bad := source.duplicate(true)
        match mode:
            "identity": bad.protocol.schema_digest = "f".repeat(64)
            "missing_identity": bad.erase("protocol")
            "missing_cursor": bad.erase("cursor")
            "zero_sequence": bad.cursor.sequence = 0
            "negative_sequence": bad.cursor.sequence = -1
        check(not decode(protocol,JSON.stringify(bad).to_utf8_buffer()).ok,"Current-producer identity/sequence boundary rejects "+mode)
    for malformed in ["{", "null", "[]", JSON.stringify(source)+",", JSON.stringify(source).trim_suffix("}")+",}"]:
        check(not protocol.decode("PlayerOperation",malformed.to_utf8_buffer()).ok,"Public arbitrary input retains strict JSON syntax")
    var invalid := JSON.stringify(source).to_utf8_buffer(); invalid.append(255)
    check(not decode(protocol,invalid).ok,"SSE rejects invalid UTF-8 before trusted admission")
    invalid = JSON.stringify(source).to_utf8_buffer(); invalid.append(0)
    check(not decode(protocol,invalid).ok,"Trusted operation rejects unrepresentable NUL")
    var body := source.duplicate(true); body.hud = {"fixture_marker":true}
    var body_raw := JSON.stringify(body).to_utf8_buffer()
    var exact_body:Dictionary=Protocol.parse_json(body_raw)
    var admitted_body:Dictionary=decode(protocol,body_raw)
    check(not protocol.decode("PlayerOperation",body_raw).ok and admitted_body.ok,"Only explicit current-producer path trusts nested typed bodies")
    # JSON.stringify sorts object keys; compare the same actual serialized
    # packet rather than an in-memory dictionary's pre-serialization order.
    check(exact_body.ok and admitted_body.ok and var_to_bytes(admitted_body.value)==var_to_bytes(exact_body.value),"Trusted nested body preserves exact serialized values/types without normalizing or inventing fields")
    var omitted := source.duplicate(true); omitted.erase("kind")
    check(protocol.decode("PlayerOperation",JSON.stringify(omitted).to_utf8_buffer()).ok,"Public arbitrary-input decoder retains sparse discriminator default")
    var sparse:Dictionary=decode(protocol,JSON.stringify(omitted).to_utf8_buffer())
    check(sparse.ok and not sparse.value.has("kind"),"Current producer admission does not materialize an omitted default discriminator")
    var archived := Protocol.new("res://sdk/recordings/pre-compact-choices/player-api-v1.schema.json","res://sdk/recordings/pre-compact-choices/protocol-identity.json")
    var old := source.duplicate(true); old.protocol = archived.identity
    var old_raw:=JSON.stringify(old).to_utf8_buffer()
    check(archived.setup_error.is_empty() and not archived.decode("PlayerOperation",old_raw).ok and not decode(archived,old_raw).ok,"Archived decoder cannot opt into current-producer trust or accept current wire under an old identity")
    # Legal server-body numeric values are opaque to shallow admission, but are
    # still parsed exactly. Integer tokens remain int64 and decimals Float64.
    for token in [str(-Protocol.SAFE_INTEGER),str(Protocol.SAFE_INTEGER),"-0.0","0.10000000000000001","2.2250738585072014e-308","5e-324"]:
        var raw := JSON.stringify(source).replace('"hud":null','"hud":{"numeric_fixture":'+token+'}').to_utf8_buffer()
        var exact := Protocol.parse_json(raw)
        var trusted := decode(protocol,raw)
        check(exact.ok and trusted.ok and var_to_bytes(exact.value) == var_to_bytes(trusted.value),"Exact token and binary64 parity: "+token)
        check(exact.ok and exact.value.hud.has("numeric_fixture"),"Numeric parity control actually inserts its scalar: "+token)
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
    # Arbitrary streams retain strict UTF-8 framing. The explicitly selected
    # current producer contract owns valid UTF-8 and skips that second scan;
    # malformed arbitrary bytes are not a trusted-producer gameplay fixture.
    await transport_check("bad_utf8",false,[0])
    for mode in ["bad_bootstrap","gap","bad_id","bad_scope","operation_identity","no_ready","consumer_failure"]:
        await transport_check(mode,true,[] if mode=="bad_bootstrap" else [0])
    finish()

func finish() -> void:
    var report := {"checks":checks,"failures":failures,"recording":recording,"operations":operations,
        "command":"Godot --headless --path <NDClientGodot> --script res://tests/trusted_operations_checks.gd -- --recording="+recording,
        "scope":"Unchanged current Gallery operations equal strict decoded and normalized values, including types/decimal bits. Public/offline negative schema controls remain strict; current-producer checks cover actual identity and positive sequence without recursive body validation. Real HTTP/SSE verifies opt-in, identity, scope, ID/order, duplicate handling, consumer rejection and operation-only trust. Named malformed producer-body controls are not gameplay recordings. No live timing claim."}
    FileAccess.open("res://generated/trusted_operations_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TRUSTED_OPERATIONS_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
