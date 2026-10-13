extends SceneTree
const Protocol=preload("res://sdk/protocol.gd")
const Transport=preload("res://sdk/transport.gd")
const Peer=preload("res://tests/trusted_choices_peer.gd")
const SAFE=9007199254740991
var checks=0
var failures: Array=[]
var path=""
var payload_bytes=0
var peer: RefCounted
var transport: RefCounted
var connected: Variant=null
var terminal: Variant=null
var responses={}

func check(ok: bool,label: String) -> bool:
    checks+=1
    if not ok: failures.append(label); print("TRUSTED_CHOICES_FAIL ",label)
    return ok

func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
    if peer!=null: peer.tick()
    if transport!=null:
        for notice in transport.drain():
            if notice.kind=="connected": connected=notice.result
            if notice.kind in ["failure","completed"]: terminal=notice
            if notice.kind=="response": responses[notice.request_id]=notice.result
    return false

func equal_normalized(protocol: RefCounted,raw: PackedByteArray,label: String) -> Dictionary:
    var strict=protocol.decode("ChoicesResponse",raw)
    var trusted=protocol.decode_server_choices(raw)
    check(strict.ok and trusted.ok,label+" accepted by strict and opted-in decoders")
    if not strict.ok or not trusted.ok: return {}
    var before=trusted.value.duplicate(true)
    var expected=protocol._normalize_admitted("ChoicesResponse",strict.value)
    var actual=protocol._normalize_admitted("ChoicesResponse",trusted.value)
    check(expected==actual,label+" normalized values exactly match strict admission")
    check(trusted.value==before,label+" normalization preserves original decoded payload")
    return actual

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--choices="): path=arg.trim_prefix("--choices=")
    if path.is_empty():
        check(false,"Usage: --choices=<actual unnormalized ChoicesResponse JSON> is required")
        finish(); return
    var raw=FileAccess.get_file_as_bytes(path)
    payload_bytes=raw.size()
    var protocol=Protocol.new()
    if not check(protocol.setup_error.is_empty(),"Current schema loads"): finish(); return
    var actual=equal_normalized(protocol,raw,"Actual recorded choices")
    if actual.is_empty(): finish(); return
    var original=Protocol.parse_json(raw).value
    check(payload_bytes>0 and not original.choices.entity_actions.is_empty(),"Actual fixture contains choices action rows")
    var small: Dictionary=original.duplicate(true)
    for family in ["entity_actions","position_actions","self_actions","object_actions","world_interactions","handler_details"]:
        small.choices[family]=[]
    small.choices.entity_actions=[original.choices.entity_actions[0].duplicate(true)]
    var target={}
    for action in original.choices.position_actions:
        if not action.valid_targets.is_empty(): target=action.valid_targets[0].duplicate(true); break
    if not check(not target.is_empty(),"Actual fixture supplies a real nested target row"): finish(); return
    var minimal: Dictionary=small.duplicate(true)
    minimal.erase("kind")
    minimal.choices={"entity_uuid":small.choices.entity_uuid.to_upper()}
    var defaults=equal_normalized(protocol,JSON.stringify(minimal).to_utf8_buffer(),"Declared defaults and UUID case")
    if not defaults.is_empty():
        check(defaults.kind=="choices" and defaults.choices.entity_uuid==small.choices.entity_uuid.to_lower(),"Default discriminator and UUID normalization retained")
        check(defaults.choices.discovery_generation==0 and defaults.choices.world_interactions==[],"Schema defaults stay schema-owned")
    for value in [-SAFE,-2,0,2,SAFE]:
        var typed=small.duplicate(true)
        typed.game_epoch=typed.game_epoch.to_upper()
        typed.audience_id=typed.audience_id.to_upper()
        typed.correlation_id=typed.correlation_id.to_upper()
        typed.choices.discovery_generation=value
        typed.choices.remaining_movement=value
        var row: Dictionary=typed.choices.entity_actions[0]
        row.discovery_generation=value; row.discovery_index=value
        row.can_afford=false; row.allow_same_target=true; row.source_item_uuid=null
        row.discovery_runtime=row.discovery_runtime.to_upper()
        row.valid_targets=[target.duplicate(true)]
        row.valid_targets[0].index=value
        row.valid_targets[0].position=[value,-value]
        row.valid_targets[0].target_uuid=small.choices.entity_uuid.to_upper()
        var normalized=equal_normalized(protocol,JSON.stringify(typed).to_utf8_buffer(),"Safe integer "+str(value))
        if normalized.is_empty(): continue
        var got: Dictionary=normalized.choices.entity_actions[0]
        check(typeof(got.discovery_index)==TYPE_INT and got.discovery_index==value and got.valid_targets[0].index==value,"Nested discovery/target indices retain exact integer value")
        check(got.valid_targets[0].position==[value,-value],"Signed safe-coordinate boundaries retain exact values")
        check(typeof(got.can_afford)==TYPE_BOOL and not got.can_afford and got.allow_same_target==true and got.source_item_uuid==null,"Booleans and nullable values retain their types")
        check(got.discovery_runtime==row.discovery_runtime.to_lower() and got.valid_targets[0].target_uuid==small.choices.entity_uuid.to_lower(),"Nested UUID case normalizes from native JSON")
    var numeric=small.duplicate(true)
    numeric.choices.discovery_generation=2.0
    numeric.choices.entity_actions[0].discovery_index=2.0
    var floating=equal_normalized(protocol,JSON.stringify(numeric).to_utf8_buffer(),"Integral JSON float2.0")
    if not floating.is_empty(): check(typeof(floating.choices.entity_actions[0].discovery_index)==TYPE_INT,"Integral native JSON float normalized to integer")
    for field in ["game_id","game_epoch","audience_id","state_revision","correlation_id","force_attack","choices"]:
        var omitted=small.duplicate(true); omitted.erase(field)
        check(not protocol.decode_server_choices(JSON.stringify(omitted).to_utf8_buffer()).ok,"Missing required envelope "+field+" rejected")
    for mutation in ["wrong_kind","invalid_actor","null_actor","family_shape","choice_extra","top_extra","fractional_generation","unsafe_generation","force_number"]:
        var bad=small.duplicate(true)
        match mutation:
            "wrong_kind": bad.kind="operation"
            "invalid_actor": bad.choices.entity_uuid="invalid"
            "null_actor": bad.choices.entity_uuid=null
            "family_shape": bad.choices.entity_actions={}
            "choice_extra": bad.choices.extra=true
            "top_extra": bad.extra=true
            "fractional_generation": bad.choices.discovery_generation=0.5
            "unsafe_generation": bad.choices.discovery_generation=SAFE+1
            "force_number": bad.force_attack=1
        check(not protocol.decode_server_choices(JSON.stringify(bad).to_utf8_buffer()).ok,"Envelope/shallow shape rejects "+mutation)
    for malformed in ["{",'{"choices":',"not json","[]","null"]:
        check(not protocol.decode_server_choices(malformed.to_utf8_buffer()).ok,"Malformed JSON or non-object envelope rejected: "+malformed)
    for invalid_utf8 in [[255],[0xc0,0x80],[0xed,0xa0,0x80],[0xf4,0x90,0x80,0x80]]:
        check(not protocol.decode_server_choices(PackedByteArray(invalid_utf8)).ok,"Invalid UTF8 rejected before native JSON")
    var nested=small.duplicate(true)
    nested.choices.entity_actions[0].trusted_fixture_marker="nested server data"
    var nested_bytes=JSON.stringify(nested).to_utf8_buffer()
    check(not protocol.decode("ChoicesResponse",nested_bytes).ok,"Generic decoder still rejects undeclared nested action fields")
    check(protocol.decode_server_choices(nested_bytes).ok,"Opted path explicitly trusts nested rows; no deep-validation claim")
    for invalid in [0,1,"true",null]:
        var client=Transport.new()
        check(not client.start("http://127.0.0.1:1","test",Callable(),{"trusted_choices":invalid}).ok,"Trust option requires a real boolean")
        client.close()
    await start_peer(small,false)
    if connected!=null and connected.ok:
        peer.reply_case="trusted_body"
        var strict_reply=await request("choices",arguments())
        check(not strict_reply.ok and strict_reply.error.kind=="protocol","Real HTTP default transport still deeply validates choices")
    stop_peer()
    await start_peer(small,true)
    if connected!=null and connected.ok:
        var offered=await request("choices",arguments())
        check(offered.ok,"Opted real HTTP choices succeeds after verified bootstrap/attachment")
        if offered.ok:
            check(offered.normalized.choices.entity_uuid==Peer.UUID and typeof(offered.normalized.choices.discovery_generation)==TYPE_INT,"Worker provides ordinary schema-normalized choices")
            offered.normalized.choices.entity_uuid="caller mutation"
            check(offered.value.choices.entity_uuid==Peer.UUID,"Normalized consumer value stays detached from raw response")
        peer.reply_case="trusted_body"
        var trusted_reply=await request("choices",arguments())
        check(trusted_reply.ok and trusted_reply.value.choices.entity_actions[0].has("trusted_fixture_marker"),"Explicit transport opt-in reaches native trusted-row path")
        for mode in ["foreign_game","foreign_epoch","foreign_audience","wrong_actor","wrong_revision","wrong_correlation","wrong_force","invalid_actor","invalid_family"]:
            peer.reply_case=mode
            var rejected=await request("choices",arguments())
            check(not rejected.ok and rejected.error.kind=="protocol","Opted HTTP still rejects "+mode)
        for received in peer.requests:
            check(received.headers.get("authorization")=="Bearer test","Loopback requests retain authentication header")
    stop_peer()
    await start_peer(small,true,"bad_bootstrap")
    check(connected==null and terminal!=null and terminal.kind=="failure","Opt-in cannot bypass bootstrap protocol identity")
    stop_peer()
    finish()

func arguments() -> Dictionary:
    return {"actor_uuid":Peer.UUID,"state_revision":"r","force_attack":false,"correlation_id":Peer.UUID}
func until(which: String,id: int=-1) -> bool:
    var deadline=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        if which=="connected" and (connected!=null or terminal!=null): return true
        if which=="response" and responses.has(id): return true
        await process_frame
    check(false,"Timed out waiting for "+which); return false
func request(operation: String,args: Dictionary) -> Dictionary:
    var id: int=transport.request(operation,args)
    if not await until("response",id): return Transport.failure("transport","Test timeout")
    var value: Dictionary=responses[id]; responses.erase(id); return value
func start_peer(body: Dictionary,trusted: bool,mode: String="normal") -> void:
    connected=null; terminal=null; responses={}
    peer=Peer.new(); peer.choices_body=body
    if not check(peer.start(mode),"Independent loopback TCP server starts"): return
    transport=Transport.new()
    var options={"request_timeout":5.0,"reconnect_timeout":5.0,"stream_idle_timeout":5.0}
    if trusted: options.trusted_choices=true
    if not check(transport.start("http://127.0.0.1:"+str(peer.port),"test",Callable(),options).ok,"Real transport worker starts"): return
    await until("connected")
    if connected!=null and connected.ok:
        var attached=await request("attach",{"acquisition_id":Peer.UUID,"expected_attachment_epoch":Peer.UUID})
        check(attached.ok,"Real attachment establishes request scope")
func stop_peer() -> void:
    if transport!=null:
        transport.close(); check(not transport.is_running(),"Worker closes cleanly"); transport=null
    if peer!=null: peer.close(); peer=null
func finish() -> void:
    var report={"checks":checks,"failures":failures,"choices":path,"payload_bytes":payload_bytes,
        "command":"Godot --headless --path \"%s\" --script res://tests/trusted_choices_checks.gd -- --choices=\"%s\"" % [ProjectSettings.globalize_path("res://"),path],
        "scope":"Actual payload strict-versus-native normalized equality, schema-derived envelope/shallow-family rejection, safe integer/type/default semantics and opted real loopback HTTP scope/correlation. Nested rows are explicitly trusted; no general JSON strictness, deep-body validation or performance claim."}
    FileAccess.open("res://generated/trusted_choices_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("TRUSTED_CHOICES_CHECKS ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
